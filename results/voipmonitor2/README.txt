╭────────────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────────────╮
│ Effective: yes                                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1; DmaRemapPeerMmio=1 │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Configuration ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                                                                                                                                                                     │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                                                                                                                                                           │
│ Decode concurrency: [1, 4, 16]                                                                                                                                                                                                                              │
│ Decode contexts: ['0', '32k', '128k']                                                                                                                                                                                                                       │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                                                                                                                                                                          │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                                                                                                                                                                          │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                                                                                                                                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.11.2.dev278+abyssal.cu132.20260605  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (29,116 tokens), but DCP/CP multiplier is not exported by this server. Pass --dcp-size N or --kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=yqnhyclbahwa, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,201 chars (~8,191 tokens)
  32k: 204,805 chars (~32,767 tokens)
  64k: 409,610 chars (~65,535 tokens)
  128k: 819,220 chars (~131,071 tokens)
Done.


Interrupted by user. Saving partial results...
No results collected.
[llm3] ~/llm3/bench ❯ ./bench.sh voipmonitor2
╭────────────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────────────╮
│ Effective: yes                                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1; DmaRemapPeerMmio=1 │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Configuration ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                                                                                                                                                                     │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                                                                                                                                                           │
│ Decode concurrency: [1, 4, 16]                                                                                                                                                                                                                              │
│ Decode contexts: ['0', '32k', '128k']                                                                                                                                                                                                                       │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                                                                                                                                                                          │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                                                                                                                                                                          │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                                                                                                                                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.11.2.dev278+abyssal.cu132.20260605  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (29,116 tokens), but DCP/CP multiplier is not exported by this server. Pass --dcp-size N or --kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=pwizccdobdzi, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,201 chars (~8,191 tokens)
  32k: 204,805 chars (~32,767 tokens)
  64k: 409,610 chars (~65,535 tokens)
  128k: 819,220 chars (~131,071 tokens)
Done.



llm-decode-bench v0.4.24
Prefill Speed (scout requests, client ISL / TTFT)

  Context    Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ─────────────────────────────────────────────────────────────────────────────────
  8k          8,190       1.47          5,590              —                —   1
  32k        32,347      10.56          3,063              —                —   1
  64k        64,571      15.30          4,221              —                —   1
  128k      129,012      39.52          3,265              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway. Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                                                                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                                 │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬────────────────────┬──────────────╮
│ ctx \ conc │           1 │                  4 │           16 │
├────────────┼─────────────┼────────────────────┼──────────────┤
│ 0          │  185.5 90/5 │        428.2 153/9 │ 817.8 507/21 │
│ 32k        │ 188.2 148/5 │ 405.4 (4/4) 230/10 │  764.6 1k/21 │
│ 128k       │ 192.1 462/5 │        391.3 1k/10 │  692.1 6k/23 │
╰────────────┴─────────────┴────────────────────┴──────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out
Per-Request tok/s
╭────────────┬───────┬─────────────┬──────╮
│ ctx \ conc │     1 │           4 │   16 │
├────────────┼───────┼─────────────┼──────┤
│ 0          │ 185.5 │       107.0 │ 51.1 │
│ 32k        │ 188.2 │ 101.4 (4/4) │ 47.8 │
│ 128k       │ 192.1 │        97.8 │ 43.3 │
╰────────────┴───────┴─────────────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────╮
│ ctx \ conc │           1 │           4 │  16 │
├────────────┼─────────────┼─────────────┼─────┤
│ 0          │ 11.1k/11.1k │ 19.6k/19.8k │ —/— │
│ 32k        │ 11.1k/11.3k │ 20.0k/22.0k │ —/— │
│ 128k       │ 10.8k/10.9k │ 21.3k/21.9k │ —/— │
╰────────────┴─────────────┴─────────────┴─────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed generated tokens, including streams stopped at the measurement boundary; a missing ITL means no stream produced at least two measured
output tokens. Per-request tok/s and request latency are shown in separate per-cell matrices. Completion/sample counts and full request-level distributions remain in JSON under request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput signal. ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Phase 3 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                                                                                                                                                                          │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is intentionally disabled by default because it adds another full decode matrix.                                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Primary Summary ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.                                                                                                                                             │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                          Aggregate decode tok/s
╭──────┬─────────┬────────┬───────┬───╮╭────────────┬───────┬─────────────┬───────╮
│ ctx  │  tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │     1 │           4 │    16 │
├──────┼─────────┼────────┼───────┼───┤├────────────┼───────┼─────────────┼───────┤
│ 8k   │   8,190 │   1.47 │ 5,590 │ 1 ││ 0          │ 185.5 │       428.2 │ 817.8 │
│ 32k  │  32,347 │  10.56 │ 3,063 │ 1 ││ 32k        │ 188.2 │ 405.4 (4/4) │ 764.6 │
│ 64k  │  64,571 │  15.30 │ 4,221 │ 1 ││ 128k       │ 192.1 │       391.3 │ 692.1 │
│ 128k │ 129,012 │  39.52 │ 3,265 │ 1 │╰────────────┴───────┴─────────────┴───────╯
╰──────┴─────────┴────────┴───────┴───╯

Results saved to /out/benchmark_results.json
