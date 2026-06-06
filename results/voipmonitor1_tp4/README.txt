╭──────────────────────────────────────────────────── NVIDIA P2P Override ────────────────────────────────────────────────────╮
│ Effective: yes                                                                                                              │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                              │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1;               │
│ DmaRemapPeerMmio=1                                                                                                          │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─────────────────────────────────────────────────────── Configuration ───────────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                                     │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                           │
│ Decode concurrency: [1, 4, 16]                                                                                              │
│ Decode contexts: ['0', '32k', '128k']                                                                                       │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                                          │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                                          │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.21.1rc1.dev339+g1967a5627bc3  Models: ['deepseek-v4-flash']
KV cache budget (vLLM metrics): 12,520,704 tokens (48909 blocks × 256)
Model context length: 393,216 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=soqvrcpjodwe, up to 128k)...
llm-decode-bench v0.4.24e-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
Prefill Speed (scout requests, client ISL / TTFT)

  Context    Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ─────────────────────────────────────────────────────────────────────────────────
  8k         ~8,192       0.54         15,250              —                —   1
  32k        32,342       2.19         14,772              —                —   1
  64k        64,559       4.59         14,077              —                —   1
  128k      128,992      10.28         12,544              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway. Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                                                                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                                 │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬───────────────────┬─────────────────────╮
│ ctx \ conc │           1 │                 4 │                  16 │
├────────────┼─────────────┼───────────────────┼─────────────────────┤
│ 0          │  222.4 36/5 │        508.9 63/8 │        1506.0 85/11 │
│ 32k        │ 246.6 133/4 │       506.6 177/8 │       1397.0 489/12 │
│ 128k       │ 227.8 333/4 │ 499.4 (4/4) 520/8 │ 945.3 (15/16) 5k/16 │
╰────────────┴─────────────┴───────────────────┴─────────────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out
Per-Request tok/s
╭────────────┬───────┬─────────────┬──────────────╮
│ ctx \ conc │     1 │           4 │           16 │
├────────────┼───────┼─────────────┼──────────────┤
│ 0          │ 222.4 │       127.2 │         94.1 │
│ 32k        │ 246.6 │       126.7 │         87.3 │
│ 128k       │ 227.8 │ 124.9 (4/4) │ 59.1 (15/16) │
╰────────────┴───────┴─────────────┴──────────────╯
Client request latency: p50 / p90 ms
╭────────────┬───────────┬─────────────┬─────────────╮
│ ctx \ conc │         1 │           4 │          16 │
├────────────┼───────────┼─────────────┼─────────────┤
│ 0          │ 9.3k/9.3k │ 16.5k/16.9k │ 29.1k/29.5k │
│ 32k        │ 8.4k/8.6k │ 15.9k/17.2k │ 36.9k/39.3k │
│ 128k       │ 8.4k/9.1k │ 17.0k/17.7k │ 38.0k/39.0k │
╰────────────┴───────────┴─────────────┴─────────────╯
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
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬─────────────┬───────────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │           4 │            16 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼─────────────┼───────────────┤
│ 8k   │   8,192 │   0.54 │ 15,250 │ 1 ││ 0          │ 222.4 │       508.9 │        1506.0 │
│ 32k  │  32,342 │   2.19 │ 14,772 │ 1 ││ 32k        │ 246.6 │       506.6 │        1397.0 │
│ 64k  │  64,559 │   4.59 │ 14,077 │ 1 ││ 128k       │ 227.8 │ 499.4 (4/4) │ 945.3 (15/16) │
│ 128k │ 128,992 │  10.28 │ 12,544 │ 1 │╰────────────┴───────┴─────────────┴───────────────╯
╰──────┴─────────┴────────┴────────┴───╯

Results saved to /out/benchmark_results.json
