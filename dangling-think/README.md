# Dangling `</think>` / Malformed Tool-Call Investigation — DeepSeek-V4-Flash on vLLM

Status: **root cause identified, confirmed intrinsic to the model (reproduces on
the upstream DeepSeek API), fix not yet implemented.** This doc captures
everything learned so work can continue without re-deriving it.

All tooling and captured requests for this investigation live in this directory
(`bench/dangling-think/`). The user's original raw field notes are in
`notes.md`.

## Original symptom

Tool calls from DeepSeek-V4-Flash were "wrongly parsed" — sometimes a tool call
the model clearly emitted never showed up as a tool call in the API response;
the request came back as a plain text/stop turn instead.

## TL;DR conclusion

The model **occasionally (~7-8% of turns) fails to emit `</think>` before its
tool call or final answer.** When that happens, the entire `<｜DSML｜tool_calls>`
block stays inside the reasoning stream, the (spec-compliant) tool parser never
sees it, and the tool call is lost. This is **malformed model output**, not a
vLLM parser/template/serving bug. DeepSeek's own encoding README acknowledges
the model occasionally emits malformed output and says production needs
"additional error handling."

The defect rate is **invariant** to every serving-side knob we tested:
- MTP speculation on/off → no change
- flashinfer_cutlass vs b12x backends → no change
- concurrency c=1 vs c=6 → no change (if anything c=1 was marginally worse)
- strengthening the system-prompt tool instructions (template edit) → no change

And, decisively, it **reproduces on the upstream DeepSeek API** (via OpenRouter,
provider pinned to DeepSeek) for **both V4-Flash and V4-Pro** — so it is a
property of the model, not of our vLLM build. See "Upstream DeepSeek API"
below.

The one lever that *does* move the needle is an in-context
`<system-reminder>` re-stating the close-`</think>`-before-tool-calls rule: it
removes the invisible "trapped in reasoning" mode but (a) does not reduce the
total malformed rate much, and (b) heavily changes behavior (much more
thinking, ~3x fewer tool calls). See "Mitigation: in-context system-reminder".

## How to reproduce / measure

Tooling built during this investigation (all in this directory,
`bench/dangling-think/`):

- `replay-request.json` — a captured real Zed request (Anthropic
  `/v1/messages` converted by the proxy to OpenAI `/v1/chat/completions`).
  867 messages, ~686K prompt tokens, 18 tools, streaming. This is the original
  failing request (proxy/dump id `8c3f908dd1d1bc35`). The final user turn asks
  it to "make a release note for second PR".
- `replay-request-short.json` — a minimal (~40KB, 2 message) request that
  still reproduces the boundary nondeterminism. Generated from the big one.
- `replay-request-reminder.json` — the big request with a strengthened
  `<system-reminder>` appended as a second text part of the final user turn
  (see "Mitigation" below). Used to A/B the in-context reminder.
- `replay_classify.py` — replays a request N times (streaming),
  accumulates `reasoning`/`content`/`tool_calls` deltas, and classifies each
  response. Buckets:
  - `clean` — reasoning then content (correct)
  - `content_no_reasoning` — emitted `</think>` immediately, zero reasoning
    (VALID, not a defect — model just chose not to think)
  - `tool_call` — produced tool calls (VALID)
  - `missing_close_no_content` — **DEFECT**: never emitted `</think>`, all output
    trapped in reasoning, empty content. (The primary failure mode; when the
    trapped reasoning contains a DSML tool block, that's the lost-tool-call bug.)
  - `extra_close_in_content` — **DEFECT**: stray `</think>` leaked into content,
    so reasoning prose appears as visible content.
  - `error`, `empty`, `other`

  Usage:
  ```sh
  # local vLLM (default url is the docker-network IP, see below)
  python3 replay_classify.py -n 100 -c 4 --dump-dir /data/dumps
  python3 replay_classify.py -n 5 -c 1 --temperature 0   # greedy probe

  # in-context reminder A/B (local)
  python3 replay_classify.py -n 100 -c 4 --request replay-request-reminder.json

  # upstream DeepSeek API via OpenRouter, provider pinned to DeepSeek
  export OPENROUTER_API_KEY=...    # or source ../../.env
  python3 replay_classify.py -n 50 -c 4 \
      --url https://openrouter.ai/api/v1/chat/completions \
      --model deepseek/deepseek-v4-flash --provider deepseek
  ```
  Flags: `-n/--num`, `-c/--concurrency`, `--url`, `--model`, `--temperature`,
  `--request`, `--dump-dir`, `--api-key` (defaults to `$OPENROUTER_API_KEY`),
  `--provider` (pin an OpenRouter provider slug; sets
  `provider.only=[slug]` + `allow_fallbacks=false` and maps `reasoning_effort`
  into OpenRouter's `reasoning` param), `--timeout`.

  IMPORTANT: the vLLM container listens on the docker-network IP
  `http://172.23.0.10:8000` (default in the script), NOT `localhost:8000`.
  `localhost:8000` is connection-refused. nginx (`/etc/nginx/sites-available/llm3`)
  fronts it at `https://llm3.lab` and needed `client_max_body_size 100m` added
  (default 1MB → 413 on the 2.7MB body).

  Long requests cold-prefill in ~175s (686K tokens). After one warm-up the
  prefix cache makes subsequent samples ~1.6s (c=4/6) or ~2s (c=1). Always warm
  with `-n 1 -c 1` before a timed run.

## Raw model-output dump instrumentation

To see the raw model output BEFORE any reasoning/tool parsing, we hooked the
top of the parser pipeline (NOT the individual tool/reasoning parsers — those
are too far downstream):

- File: `vllm/vllm/parser/abstract_parser.py`, class `DelegatingParser`.
  - `parse()` (non-streaming) and `parse_delta()` (streaming) are the true
    pipeline entry points. Order from there is: `extract_reasoning()` (strips
    `<think>...</think>`) → `_extract_tool_calls()` (parses DSML from the
    remainder).
  - Added `_dump_raw_output(request_id, kind, text)` which writes to
    `$VLLM_RAW_OUTPUT_DUMP_DIR/<request_id>/{streaming,non_streaming}.txt`.
    Streaming appends each `delta_text`; non-streaming writes once. No-ops if
    the env var is unset (safe to ship).
  - `request_id` comes from `ChatCompletionRequest.request_id` (a real body
    field, L349-357 of `entrypoints/openai/chat_completion/protocol.py`). It is
    NOT the same as the response `id` (`chatcmpl-...`), which is a separate UUID
    generated by the response object. The proxy can set `request_id` in the JSON
    body for correlation; otherwise vLLM assigns a random uuid.

- Enable with docker run opts:
  ```
  -e VLLM_RAW_OUTPUT_DUMP_DIR=/dump  -v /data/dump:/dump
  ```

## The decisive experiments

1. **Backend/MTP/concurrency sweep** (`replay_classify.py -n 100`):
   `missing_close` stayed at 7-8% across lucifer2_cutlass(MTP),
   cutlass-no-MTP, lucifer2(no cutlass), c=1, c=6. → rules out decode path.

2. **temp=0 greedy probe** — the key finding. Greedy decoding is supposed to be
   deterministic, but 5 runs of the identical long prompt gave 4 different
   buckets, and 15 greedy runs of the SHORT prompt gave **8 distinct outputs**
   (reasoning text varied word-for-word; one run even picked a different tool,
   `grep` vs `list_directory`). So there is real **kernel-level FP
   nondeterminism** (batch-invariance / nondeterministic reduction order in MoE
   grouped-GEMM, attention, all-reduce — pronounced for MoE + fp8 KV). The
   `<think>`/`</think>` boundary and tool-call decisions are high-entropy pivot
   points where that noise flips the emitted token.

   NOTE: "make it deterministic" is NOT the goal — production runs temp>0 and a
   deterministic-but-wrong boundary is no better. Determinism was only a
   diagnostic to prove the defect is structural, not sampling-specific.

## Upstream DeepSeek API (OpenRouter) — confirms it's intrinsic to the model

We replayed the big request against the **real DeepSeek first-party API** through
OpenRouter, pinning the provider so we hit DeepSeek's own serving stack and not a
reseller:

```sh
--url https://openrouter.ai/api/v1/chat/completions
--model deepseek/deepseek-v4-flash   (or deepseek/deepseek-v4-pro)
--provider deepseek
```

The `--provider deepseek` flag sets `provider.only=["deepseek"]` +
`allow_fallbacks=false`. Pinning DeepSeek initially 404s with "No endpoints
matching your data policy" — DeepSeek's first-party endpoint may log/train on
data, so the OpenRouter account's privacy setting at
`https://openrouter.ai/settings/privacy` must allow it (or pass
`provider.data_collection="allow"`). Confirmed served by `"provider":"DeepSeek"`,
model `deepseek-v4-flash-20260423`, fingerprint `..._fp8_kvcache_...`.

**Result: the defect reproduces upstream on BOTH V4-Flash and V4-Pro.** Same
user-visible symptom — the answer/tool call is lost: empty `content`,
`finish_reason=stop`, the whole generation trapped in the reasoning channel.
This rules out our vLLM build/encoder/parser as the cause; the model itself is
the source.

Measured rates (long request, n=50, c=4, temp=1.0, OpenRouter buckets):

| bucket | V4-Flash (upstream) | V4-Pro (upstream) |
|---|---|---|
| `clean` | ~69% | 58% |
| trapped-in-reasoning (defect) | ~23% | **30%** |
| reasoning-leaked-into-content (defect) | small | 8% |
| tool_call | small | 4% |

**Caveat — the classifier is calibrated for our LOCAL semantics and mislabels
the upstream stream.** Upstream, OpenRouter/DeepSeek does its own (different)
reasoning/content split, and the model's defect token is *different* from ours:

- Locally the model **omits** `</think>` (it was prefilled with `<think>`, only
  needs to close).
- Upstream the dominant defect is a **misspelled close tag `</thinking>`**
  (instead of `</think>`), plus a **redundant literal `<think>`** opener, or
  garbage openers like `<system-reminder>`/`<user`. The upstream parser then
  fails to split and dumps everything into `reasoning_content` (→ empty content)
  or into `content` (→ reasoning prose visible to the user). One "missing close"
  sample even contained a perfectly valid `</think>` yet still landed entirely
  in reasoning.

So it's the same family (think-boundary fragility, answer trapped/leaked) but a
different failing token. For an apples-to-apples rate, the classifier should be
recomputed from the raw concatenated text and detect all variants (`</think>`
omitted, `</thinking>` wrong tag, duplicated literal `<think>`,
stray-close-in-content) — not trust the upstream reasoning/content split. This
matches the user's field note that the API "often uses `response`/`Response` as
a separator instead of `</think>`" and that V4-Flash and V4-Pro both exhibit it.

## Mitigation: in-context `<system-reminder>` (partial; behavior-altering)

We A/B-tested appending a strengthened reminder as a second text part of the
final user turn (file: `replay-request-reminder.json`). The reminder restates
the template rule with the literal tokens resolved
(`<think>`/`</think>`/`<｜DSML｜tool_calls>`):

> If thinking_mode is enabled (triggered by `<think>`), you MUST output your
> complete reasoning inside `<think>...</think>` BEFORE any tool calls or final
> response. You MUST emit the closing `</think>` token before writing any
> `"<｜DSML｜tool_calls>"` block. Never place a `"<｜DSML｜tool_calls>"` block
> inside the reasoning section; always close reasoning with `</think>` first.

Local long request, n=100 each, c=4, temp=1.0:

| metric | baseline | + reminder |
|---|---|---|
| `clean` | 32% | 81% |
| `content_no_reasoning` (valid) | 46% | 10% |
| `tool_call` (valid) | **17%** | **6%** |
| trapped-in-reasoning (defect, invisible loss) | **4%** | **0%** |
| `</think>` leaked into content (defect, visible) | 3% | 3% |
| **total boundary defects** | **7%** | **3%** |

Reading:
- The reminder **eliminates the invisible "trapped in reasoning" mode** (4 → 0
  of 100) — the failure that silently loses output/tool calls. Good.
- It does **nothing** for the visible stray-`</think>`-leak mode (3 → 3).
- **Big behavioral side effect**: it pushes the model to think-then-answer far
  more (clean 32% → 81%) and **suppresses tool calls ~3x (17% → 6%)**. For an
  agent that is a real risk — you'd be trading a few % of silent-loss for the
  model calling tools much less often. This is exactly the user's worry that the
  reminder "messes with the model training sufficiently to reduce its
  instruction-following capability."
- No trapped DSML *tool block* (the literal lost-tool-call) appeared in either
  100-run, so 200 samples is too few to measure that specific rate; we only have
  the anecdotal earlier hit (sample `ab07db3fdf39d03b`).

Net: the in-context reminder is a real but partial mitigation with a meaningful
downside, not a clean fix. A softer phrasing (drop the strong "before any tool
calls / final response" framing) and a tool-required prompt should be tested
before relying on it.

## Why it is NOT a parser/template bug (spec grounding)

DeepSeek-V4 does **not** use a Jinja chat template. It uses a hand-written
encoder, `vllm/tokenizers/deepseek_v4_encoding.py` (mirrors `encoding_dsv4.py`
in the model repo), selected by `--tokenizer-mode deepseek_v4` (auto-default for
`DeepseekV4ForCausalLM`, see `config/model.py` ~L625).

Spec source of truth:
https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro/raw/main/encoding/README.md

Key rules from the spec / encoder:
- Thinking mode prefills the prompt with `<｜Assistant｜><think>`, so the model
  ALWAYS starts generation already inside reasoning. Triggered by our
  `--default-chat-template-kwargs '{"thinking": true, ...}'`.
- When tools are present, the encoder injects a `## Tools` block
  (`TOOLS_TEMPLATE`, ~L76-101) that instructs: "you MUST output your complete
  reasoning inside `<think>...</think>` BEFORE any tool calls or final response."
- Canonical tool call is `</think>...<｜DSML｜tool_calls>...`. So `</think>` is
  MANDATORY before a tool call by design. The tool-call start token is NOT a
  reasoning terminator (unlike KimiK2's `<|tool_calls_section_begin|>`, which
  IS — do not copy that pattern here).
- README explicitly: `parse_message_from_completion_text` "is designed to handle
  well-formatted model output only. It does not attempt to correct or recover
  from malformed output ... For production use, additional error handling is
  recommended."

So vLLM swallowing a `<｜DSML｜tool_calls>` block into reasoning when there is no
preceding `</think>` is CORRECT, spec-compliant behavior on malformed input.

Reasoning parser registration: `deepseek_v4` → `deepseek_v3_reasoning_parser`
(`vllm/reasoning/__init__.py`). Tool parser: `deepseek_v4` →
`DeepSeekV4ToolParser` (subclass of `DeepSeekV32ToolParser`,
`vllm/tool_parsers/deepseekv4_tool_parser.py`), wraps calls in
`<｜DSML｜tool_calls>` (vs v3.2's `<｜DSML｜function_calls>`). There is also a Rust
implementation under `rust/src/tool-parser/src/deepseek_dsml/`.

### A note on history contamination (investigated, then DISMISSED)
The captured conversation history had 288 `</think>` vs 256 `<think>` — i.e.
prior assistant turns contained stray/extra `</think>` baked into their `text`
content. These are NOT proxy corruption; they are faithful reflections of the
model's own prior malformed outputs being round-tripped by Zed as assistant
text (the assistant encode template is `{reasoning}{content}{tool_calls}` so
content with a stray `</think>` re-enters the prompt verbatim).
We hypothesized in-context contamination was the cause, but the user reported
others hit the same issue WITHOUT this reflection, and the short-prompt repro
(clean 2-message history) reproduces it too. So contamination is a symptom/
amplifier, not the root cause.

## What was tried and ruled out

- Disable MTP (`--speculative-config.*` removed) — no change.
- cutlass vs non-cutlass image — no change.
- c=1 vs c=6 — no change.
- Strengthen `TOOLS_TEMPLATE` instruction (added emphatic "MUST emit `</think>`
  before any `<｜DSML｜tool_calls>` block; never place tool_calls inside
  reasoning") — no change, still 7%. Edit is in
  `vllm/tokenizers/deepseek_v4_encoding.py` ~L92. NOTE: this moves off the
  trained distribution; consider reverting if not pursuing, since it gave no
  benefit. It is currently still applied in the source + shipped in the image.
  (Distinct from the in-context `<system-reminder>` below, which DID move the
  rate — the difference is the reminder sits in the final user turn, right
  before generation, not buried in the system/tools preamble.)

## What was confirmed to reproduce / partially help

- **Upstream DeepSeek API (V4-Flash and V4-Pro), via OpenRouter** — reproduces.
  Proves the defect is intrinsic to the model, not our serving stack. The
  upstream failing token differs (`</thinking>` wrong tag / literal `<think>`
  rather than an omitted `</think>`). See "Upstream DeepSeek API".
- **In-context `<system-reminder>` in the final user turn** — removes the
  invisible trapped-in-reasoning mode (4% → 0% at n=100) but does not help the
  visible leak mode and suppresses tool-calling ~3x. Partial, behavior-altering.
  See "Mitigation: in-context system-reminder".

## Recommended next step (NOT yet done): guarded recovery path

The most robust server-side lever that fixes the user-visible symptom (lost tool
calls) without violating the spec is a **recovery-from-malformed** path, exactly
as the README suggests. (The in-context `<system-reminder>` above is a
complementary client-side mitigation, but it's partial and changes behavior, so
it shouldn't be the only line of defense.) Scope the recovery narrowly so it
never fires on well-formed output:

- Trigger ONLY when a finished turn parsed zero tool calls AND empty/whitespace
  content, AND the reasoning tail contains a complete, balanced
  `<｜DSML｜tool_calls> ... </｜DSML｜tool_calls>` block.
- Then re-run the existing DSML tool extraction over that reasoning tail and
  promote the result to real tool calls (set finish_reason=tool_calls).
- Frame it explicitly as malformed-output recovery, NOT as making the tool-call
  token end reasoning.
- Likely homes: `DelegatingParser.parse()` (non-streaming, easy) and the
  streaming path (`parse_delta` / `chat_completion_stream_generator`, harder
  because reasoning has already been streamed to the client as `reasoning`
  deltas by the time EOS arrives — may only be feasible for non-streaming, or
  requires buffering).
- Before building: quantify how much real traffic hits it (the dumps + the 7%
  rate suggest it's worth it, but confirm on production-shaped requests).
- Make the recovery + the classifier robust to the **upstream-style** variants
  too (`</thinking>` wrong tag, duplicated literal `<think>`), since a balanced
  DSML block can be trapped behind any of them, not just an omitted `</think>`.
  Hardening `replay_classify.py` to score from the raw concatenated text would
  also make the local vs upstream numbers directly comparable.

Open question worth a look: `reasoning_effort`. Our config passes
`reasoning_effort: high` and the replay used `medium`, but the README only
documents `max` (which prepends a special max-effort prefix). Verify how
`high`/`medium` are handled by `deepseek_v4_encoding.py` — a no-op/unknown value
could matter.

## Environment / infra notes

- Start scripts: `bench/start.sh`. Relevant container is `lucifer2` /
  `lucifer2_cutlass` (image `hg436/vllm-public:lucifer-8aed3cd`).
- Test image with dump + strengthened prompt: `Dockerfile.lucifer-fix` →
  built/tagged `lucifer-dump:latest`. vLLM lives at `/opt/vllm/vllm/...` inside
  the image.
- Server reachable at `http://172.23.0.10:8000`; nginx at `https://llm3.lab`
  (now `client_max_body_size 100m`).
- Dumps collected: `/data/replay-dumps*` (per-experiment), `/data/dump/<id>/`
  (raw model output via VLLM_RAW_OUTPUT_DUMP_DIR).
- Notable failing sample dumped raw: `ab07db3fdf39d03b` — reasoning ended with a
  complete, well-formed DSML `terminal` tool call but NO `</think>`, content
  empty, finish_reason `stop`. The canonical example of the lost-tool-call bug.
