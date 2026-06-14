#!/usr/bin/env python3
"""Replay a captured chat-completions request many times and classify how the
model behaves around the <think>/</think> reasoning boundary.

The captured request (default: bench/replay-request.json) is an OpenAI
/v1/chat/completions body with stream=True. For each sample we accumulate the
streamed `reasoning` and `content` deltas plus any tool calls, then bucket the
result into one of several categories so we can see how often each failure mode
reproduces.

Usage:
    python3 bench/replay_classify.py [-n N] [-c CONCURRENCY] [options]

    -n / --num         number of samples (default 50)
    -c / --concurrency parallel in-flight requests (default 4)
    --url              endpoint (default http://localhost:8000/v1/chat/completions)
    --model            override model name in the body
    --temperature      override temperature in the body
    --request          path to request JSON (default bench/replay-request.json)
    --dump-dir         if set, write each raw sample's reasoning/content there
"""

import argparse
import collections
import concurrent.futures
import json
import os
import sys
import threading
import time
import urllib.request

DEFAULT_REQUEST = os.path.join(os.path.dirname(__file__), "replay-request.json")
# The vLLM container (see bench/start.sh) listens on the docker network IP, not
# localhost. Override with --url if you have a port-forward to localhost:8000.
DEFAULT_URL = "http://172.23.0.10:8000/v1/chat/completions"


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("-n", "--num", type=int, default=50)
    p.add_argument("-c", "--concurrency", type=int, default=4)
    p.add_argument("--url", default=DEFAULT_URL)
    p.add_argument("--model", default=None)
    p.add_argument("--temperature", type=float, default=None)
    p.add_argument("--request", default=DEFAULT_REQUEST)
    p.add_argument("--api-key", default=os.environ.get("OPENROUTER_API_KEY", "test"))
    p.add_argument("--provider", default=None,
                   help="Pin an OpenRouter provider slug (e.g. 'deepseek'); "
                        "sets provider.only + allow_fallbacks=false.")
    p.add_argument("--dump-dir", default=None)
    p.add_argument("--timeout", type=float, default=600.0)
    return p.parse_args()


def load_body(args):
    with open(args.request) as f:
        body = json.load(f)
    body["stream"] = True
    body.setdefault("stream_options", {})["include_usage"] = True
    if args.model is not None:
        body["model"] = args.model
    if args.temperature is not None:
        body["temperature"] = args.temperature
    if args.provider is not None:
        # Pin OpenRouter routing to a single upstream provider so we test that
        # provider's actual serving stack (e.g. DeepSeek's own API), not a
        # random reseller. allow_fallbacks=false makes it error rather than
        # silently route elsewhere.
        body["provider"] = {"only": [args.provider], "allow_fallbacks": False}
        # OpenRouter surfaces reasoning under delta.reasoning only when asked.
        body.setdefault("reasoning", {})
        if isinstance(body.get("reasoning_effort"), str):
            body["reasoning"].setdefault("effort", body["reasoning_effort"])
        body["reasoning"].setdefault("enabled", True)
    return body


def stream_one(args, body, timeout):
    """POST the body and accumulate streamed deltas. Returns a dict."""
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        args.url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {args.api_key}",
            "Accept": "text/event-stream",
            "Accept-Encoding": "identity",
        },
        method="POST",
    )

    reasoning = []
    content = []
    tool_calls = {}  # index -> {name, args}
    finish_reason = None
    chatcmpl_id = None
    usage = None
    error = None

    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            for raw in resp:
                line = raw.decode("utf-8", "replace").strip()
                if not line.startswith("data:"):
                    continue
                payload = line[len("data:"):].strip()
                if payload == "[DONE]":
                    break
                try:
                    chunk = json.loads(payload)
                except json.JSONDecodeError:
                    continue
                if chunk.get("id"):
                    chatcmpl_id = chunk["id"]
                if chunk.get("usage"):
                    usage = chunk["usage"]
                for choice in chunk.get("choices", []):
                    delta = choice.get("delta", {})
                    if delta.get("reasoning"):
                        reasoning.append(delta["reasoning"])
                    if delta.get("content"):
                        content.append(delta["content"])
                    for tc in delta.get("tool_calls", []) or []:
                        idx = tc.get("index", 0)
                        slot = tool_calls.setdefault(idx, {"name": None, "args": ""})
                        fn = tc.get("function") or {}
                        if fn.get("name"):
                            slot["name"] = fn["name"]
                        if fn.get("arguments"):
                            slot["args"] += fn["arguments"]
                    if choice.get("finish_reason"):
                        finish_reason = choice["finish_reason"]
    except Exception as e:  # noqa: BLE001 - surface any transport/HTTP error
        error = f"{type(e).__name__}: {e}"

    return {
        "id": chatcmpl_id,
        "reasoning": "".join(reasoning),
        "content": "".join(content),
        "tool_calls": tool_calls,
        "finish_reason": finish_reason,
        "usage": usage,
        "error": error,
        "elapsed": time.time() - t0,
    }


# Any of these substrings in a channel means a DSML tool-call block is present
# there. The fullwidth bar `｜` (U+FF5C) is part of the literal DeepSeek tokens.
DSML_MARKERS = ("<｜DSML｜tool_calls>", "<｜DSML｜invoke", "<｜DSML｜function_calls>")


def has_dsml(text):
    return bool(text) and any(m in text for m in DSML_MARKERS)


def classify(r):
    """Bucket one sample into a behavior category."""
    if r["error"]:
        return "error"

    reasoning = r["reasoning"]
    content = r["content"]
    has_tool = bool(r["tool_calls"])

    # The model is supposed to: reason (routed to `reasoning`), emit </think>,
    # then produce `content` and/or tool calls.

    if has_tool:
        # Stray </think> leaking into the content alongside a tool call still
        # counts as a boundary defect; flag it but prioritize tool bucket.
        return "tool_call"

    # THE TARGET BUG: a DSML tool-call block trapped in a channel because the
    # model never emitted </think>, so the tool parser never saw it and the
    # call was silently lost. This is the case the recovery path fixes.
    if has_dsml(reasoning):
        return "trapped_tool_call"  # block stayed entirely in reasoning
    if has_dsml(content):
        return "trapped_tool_call_in_content"  # leaked into content past a stray close

    # No content at all: everything stayed in the reasoning channel because the
    # model never emitted </think> before EOS. This is the primary failure mode.
    if reasoning and not content.strip():
        return "missing_close_no_content"

    # Content present but it starts with one or more stray </think> markers that
    # the reasoning parser passed through as content.
    if content.lstrip().startswith("</think>") or content.count("</think>") > 0:
        return "extra_close_in_content"

    if content and not reasoning:
        return "content_no_reasoning"

    if content and reasoning:
        return "clean"

    if not content and not reasoning:
        return "empty"

    return "other"


def main():
    args = parse_args()
    body = load_body(args)

    if args.dump_dir:
        os.makedirs(args.dump_dir, exist_ok=True)

    print(f"Replaying {args.num} samples to {args.url} "
          f"(model={body['model']}, temp={body['temperature']}, "
          f"concurrency={args.concurrency})", file=sys.stderr)

    counts = collections.Counter()
    samples = []
    lock = threading.Lock()
    done = [0]

    def worker(i):
        r = stream_one(args, body, args.timeout)
        cat = classify(r)
        with lock:
            counts[cat] += 1
            done[0] += 1
            samples.append((i, cat, r))
            n = done[0]
            tail = ""
            if r["error"]:
                tail = f"  {r['error']}"
            elif cat == "tool_call":
                names = [tc.get("name") or "?"
                         for _, tc in sorted(r["tool_calls"].items())]
                tail = f"  tools={names}"
            elif cat in ("missing_close_no_content", "extra_close_in_content",
                         "trapped_tool_call", "trapped_tool_call_in_content"):
                preview = (r["content"] or r["reasoning"])[:60].replace("\n", " ")
                tail = f"  {preview!r}"
            print(f"[{n}/{args.num}] {cat}  "
                  f"(reason={len(r['reasoning'])}B content={len(r['content'])}B "
                  f"finish={r['finish_reason']} {r['elapsed']:.1f}s){tail}",
                  file=sys.stderr)
        if args.dump_dir:
            sid = r["id"] or f"sample_{i:04d}"
            with open(os.path.join(args.dump_dir, f"{sid}.json"), "w") as f:
                json.dump({"category": cat, **r}, f, ensure_ascii=False, indent=2)
        return r

    t0 = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as ex:
        list(ex.map(worker, range(args.num)))
    elapsed = time.time() - t0

    print("\n=== Classification summary ===")
    total = sum(counts.values())
    for cat, n in counts.most_common():
        print(f"  {cat:28s} {n:5d}  ({100.0 * n / total:5.1f}%)")
    print(f"  {'TOTAL':28s} {total:5d}")
    print(f"\nWall time: {elapsed:.1f}s  "
          f"({elapsed / max(total, 1):.1f}s/sample avg, concurrency={args.concurrency})")


if __name__ == "__main__":
    main()
