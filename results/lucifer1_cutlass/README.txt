╭────────────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────────────╮
│ Effective: yes                                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1; DmaRemapPeerMmio=1 │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Configuration ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                                                                                                                                                                     │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                                                                                                                                                           │
│ Decode concurrency: [1, 4, 8]                                                                                                                                                                                                                               │
│ Decode contexts: ['0', '32k', '128k']                                                                                                                                                                                                                       │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                                                                                                                                                                          │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                                                                                                                                                                          │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                                                                                                                                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.21.1rc1.dev339+g1967a5627.d20260607  Models: ['deepseek-v4-flash']
KV cache budget (vLLM metrics): 2,911,744 tokens (11374 blocks × 256)
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=eykgbmlbxmvi, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,188 chars (~8,191 tokens)
  32k: 204,753 chars (~32,767 tokens)
  64k: 409,507 chars (~65,535 tokens)
  128k: 819,014 chars (~131,071 tokens)
Done.



llm-decode-bench v0.4.24
Prefill Speed (scout requests, client ISL / TTFT)

  Context    Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ─────────────────────────────────────────────────────────────────────────────────
  8k          8,191       0.65         12,522              —                —   1
  32k        32,340       2.76         11,719              —                —   1
  64k        64,555       5.73         11,275              —                —   1
  128k      128,980      12.90         10,002              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway. Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                                                                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                                 │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬──────────────┬──────────────╮
│ ctx \ conc │           1 │            4 │            8 │
├────────────┼─────────────┼──────────────┼──────────────┤
│ 0          │  189.0 40/5 │  372.2 71/11 │ 743.8 188/11 │
│ 32k        │ 192.2 130/5 │ 394.1 203/11 │ 705.2 287/12 │
│ 128k       │ 190.9 347/5 │ 339.3 730/11 │  655.1 1k/12 │
╰────────────┴─────────────┴──────────────┴──────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
Per-Request tok/s
╭────────────┬───────┬──────┬──────╮
│ ctx \ conc │     1 │    4 │    8 │
├────────────┼───────┼──────┼──────┤
│ 0          │ 189.0 │ 93.0 │ 93.0 │
│ 32k        │ 192.2 │ 98.5 │ 88.1 │
│ 128k       │ 190.9 │ 84.8 │ 81.9 │
╰────────────┴───────┴──────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx \ conc │           1 │           4 │           8 │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 0          │ 10.7k/11.1k │ 28.2k/28.6k │ 22.4k/22.6k │
│ 32k        │ 10.5k/15.7k │ 27.1k/28.6k │ 27.8k/30.1k │
│ 128k       │ 11.1k/11.1k │ 26.2k/27.5k │ 32.9k/34.5k │
╰────────────┴─────────────┴─────────────┴─────────────╯
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
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬───────┬───────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │     4 │     8 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼───────┼───────┤
│ 8k   │   8,191 │   0.65 │ 12,522 │ 1 ││ 0          │ 189.0 │ 372.2 │ 743.8 │
│ 32k  │  32,340 │   2.76 │ 11,719 │ 1 ││ 32k        │ 192.2 │ 394.1 │ 705.2 │
│ 64k  │  64,555 │   5.73 │ 11,275 │ 1 ││ 128k       │ 190.9 │ 339.3 │ 655.1 │
│ 128k │ 128,980 │  12.90 │ 10,002 │ 1 │╰────────────┴───────┴───────┴───────╯
╰──────┴─────────┴────────┴────────┴───╯

Results saved to /out/benchmark_results.json
