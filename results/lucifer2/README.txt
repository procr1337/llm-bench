╭────────────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────────────╮
│ Effective: yes                                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1; DmaRemapPeerMmio=1 │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭──────────────────────────────────────────────────────────────── Configuration ─────────────────────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                                                        │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                                              │
│ Decode concurrency: [1, 4, 8]                                                                                                                  │
│ Decode contexts: ['0', '32k', '128k']                                                                                                          │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                                                             │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                                                             │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                                                  │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.22.1rc1.dev267+g2423fbe70.d20260608  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (45,532 tokens), but DCP/CP multiplier is not exported by this server. Pass --dcp-size N or
--kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=mrswpvcwxytp, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,188 chars (~8,191 tokens)
  32k: 204,753 chars (~32,767 tokens)
  64k: 409,507 chars (~65,535 tokens)
  128k: 819,014 chars (~131,071 tokens)
Done.



llm-decode-bench v0.4.25
Prefill Speed (scout requests, client ISL / TTFT)

  Context    Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ─────────────────────────────────────────────────────────────────────────────────
  8k          8,191       0.67         12,307              —                —   1
  32k        32,340       2.83         11,418              —                —   1
  64k        64,555       5.84         11,052              —                —   1
  128k      128,980      13.23          9,752              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway. Server tok/s is
optional Prometheus validation when the engine exports prefill counters and the exact counter delta is uncontaminated.

╭─────────────────────────────────────────────────────────────────── Phase 2 ────────────────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                                               │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the main                 │
│ tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                                                   │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬───────────────────┬────────────────────┬───────────────────╮
│ ctx \ conc │                 1 │                  4 │                 8 │
├────────────┼───────────────────┼────────────────────┼───────────────────┤
│ 0          │        169.0 75/6 │       256.7 107/16 │       425.8 6k/19 │
│ 32k        │ 168.1 c100% 125/6 │ 268.7 c100% 202/15 │ 444.4 c100% 6k/17 │
│ 128k       │ 175.1 c100% 324/6 │ 257.9 c100% 866/15 │       434.7 5k/20 │
╰────────────┴───────────────────┴────────────────────┴───────────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports it). Prometheus is
kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage

Server prefix-cache hit % (engine
prefix-cache counter delta, per
cell)
╭────────────┬──────┬──────┬──────╮
│ ctx \ conc │    1 │    4 │    8 │
├────────────┼──────┼──────┼──────┤
│ 0          │   0% │   0% │   0% │
│ 32k        │ 100% │ 100% │ 100% │
│ 128k       │ 100% │ 100% │ 100% │
╰────────────┴──────┴──────┴──────╯
Prefix-cache hit % = hits/queries over the decode phase (after the one-time scout warm-up), from the engine's own prefix-cache counters. High when
each lane re-hits its own warmed prefix; drops when many distinct lanes exceed KV capacity and force eviction.
Per-Request tok/s
╭────────────┬───────┬──────┬──────╮
│ ctx \ conc │     1 │    4 │    8 │
├────────────┼───────┼──────┼──────┤
│ 0          │ 169.0 │ 64.2 │ 53.2 │
│ 32k        │ 168.1 │ 67.2 │ 55.6 │
│ 128k       │ 175.1 │ 64.5 │ 54.3 │
╰────────────┴───────┴──────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx \ conc │           1 │           4 │           8 │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 0          │ 12.3k/12.5k │ 32.1k/32.9k │         —/— │
│ 32k        │ 12.7k/13.0k │ 36.4k/37.8k │ 38.9k/39.2k │
│ 128k       │ 12.0k/12.1k │ 32.1k/33.0k │         —/— │
╰────────────┴─────────────┴─────────────┴─────────────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed generated tokens, including
streams stopped at the measurement boundary; a missing ITL means no stream produced at least two measured output tokens. Per-request tok/s and
request latency are shown in separate per-cell matrices. Completion/sample counts and full request-level distributions remain in JSON under
request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput signal.
ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭─────────────────────────────────────────────────────────────────── Phase 3 ────────────────────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                                                             │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is intentionally disabled by      │
│ default because it adds another full decode matrix.                                                                                            │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭─────────────────────────────────────────────────────────────── Primary Summary ────────────────────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.                                │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │           1 │           4 │           8 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼─────────────┼─────────────┼─────────────┤
│ 8k   │   8,191 │   0.67 │ 12,307 │ 1 ││ 0          │       169.0 │       256.7 │       425.8 │
│ 32k  │  32,340 │   2.83 │ 11,418 │ 1 ││ 32k        │ 168.1 c100% │ 268.7 c100% │ 444.4 c100% │
│ 64k  │  64,555 │   5.84 │ 11,052 │ 1 ││ 128k       │ 175.1 c100% │ 257.9 c100% │       434.7 │
│ 128k │ 128,980 │  13.23 │  9,752 │ 1 │╰────────────┴─────────────┴─────────────┴─────────────╯
╰──────┴─────────┴────────┴────────┴───╯
