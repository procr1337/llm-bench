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
Engine: vLLM 0.21.1rc1.dev339+g1967a5627bc3  Models: ['deepseek-v4-flash']
KV cache budget (vLLM metrics): 1,734,144 tokens (6774 blocks × 256)
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=agvuhfvcuxef, up to 128k)...
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
  8k          8,191       0.66         12,463              —                —   1
  32k        32,340       2.80         11,552              —                —   1
  64k        64,555       5.80         11,125              —                —   1
  128k      128,980      13.05          9,885              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway. Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                                                                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                                 │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬──────────────┬──────────────────╮
│ ctx \ conc │           1 │            4 │               16 │
├────────────┼─────────────┼──────────────┼──────────────────┤
│ 0          │  172.0 80/6 │ 264.2 134/15 │ ∅ (8/16)* 39k/19 │
│ 32k        │ 169.3 145/6 │ 262.6 673/15 │ ∅ (8/16)* 35k/18 │
│ 128k       │ 168.8 375/6 │ 263.1 954/15 │                ∅ │
╰────────────┴─────────────┴──────────────┴──────────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
∅ = skipped/hidden because the cell does not fit in KV cache; exact deficit is kept in JSON timeout_reason
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out
Per-Request tok/s
╭────────────┬───────┬──────┬───────────╮
│ ctx \ conc │     1 │    4 │        16 │
├────────────┼───────┼──────┼───────────┤
│ 0          │ 172.0 │ 66.0 │ ∅ (8/16)* │
│ 32k        │ 169.3 │ 65.7 │ ∅ (8/16)* │
│ 128k       │ 168.8 │ 65.8 │         ∅ │
╰────────────┴───────┴──────┴───────────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx \ conc │           1 │           4 │          16 │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 0          │ 12.3k/12.6k │ 38.3k/38.5k │ 69.3k/89.3k │
│ 32k        │ 15.2k/17.3k │ 37.5k/38.4k │ 54.4k/78.3k │
│ 128k       │ 12.1k/12.5k │ 30.8k/32.0k │           ∅ │
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
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬───────┬───────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │     4 │        16 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼───────┼───────────┤
│ 8k   │   8,191 │   0.66 │ 12,463 │ 1 ││ 0          │ 172.0 │ 264.2 │ ∅ (8/16)* │
│ 32k  │  32,340 │   2.80 │ 11,552 │ 1 ││ 32k        │ 169.3 │ 262.6 │ ∅ (8/16)* │
│ 64k  │  64,555 │   5.80 │ 11,125 │ 1 ││ 128k       │ 168.8 │ 263.1 │         ∅ │
│ 128k │ 128,980 │  13.05 │  9,885 │ 1 │╰────────────┴───────┴───────┴───────────╯
╰──────┴─────────┴────────┴────────┴───╯
