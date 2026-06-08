╭────────────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────────────╮
│ Effective: yes                                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1; DmaRemapPeerMmio=1 │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭──────────────────────────────────────────────────────────────── Configuration ────────────────────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                                                       │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                                             │
│ Decode concurrency: [1, 4, 8]                                                                                                                 │
│ Decode contexts: ['0', '32k', '128k']                                                                                                         │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                                                            │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                                                            │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                                                 │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.22.1rc1.dev267+g2423fbe70.d20260608  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (44,904 tokens), but DCP/CP multiplier is not exported by this server. Pass --dcp-size N or
--kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=kstlmnbfgexp, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,192 chars (~8,191 tokens)
  32k: 204,768 chars (~32,767 tokens)
  64k: 409,537 chars (~65,535 tokens)
  128k: 819,075 chars (~131,071 tokens)
Done.



llm-decode-bench v0.4.25
Prefill Speed (scout requests, client ISL / TTFT)

  Context    Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ─────────────────────────────────────────────────────────────────────────────────
  8k         ~8,192       0.66         12,356              —                —   1
  32k        32,342       2.80         11,561              —                —   1
  64k        64,559       5.80         11,134              —                —   1
  128k      128,992      13.08          9,858              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway. Server tok/s is
optional Prometheus validation when the engine exports prefill counters and the exact counter delta is uncontaminated.

╭─────────────────────────────────────────────────────────────────── Phase 2 ───────────────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                                              │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the main                │
│ tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                                                  │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬───────────────────┬──────────────────────────┬────────────────────╮
│ ctx \ conc │                 1 │                        4 │                  8 │
├────────────┼───────────────────┼──────────────────────────┼────────────────────┤
│ 0          │        183.0 37/5 │              371.8 73/11 │        724.5 3k/11 │
│ 32k        │  187.0 c100% 98/5 │       405.7 c100% 202/10 │ 689.3 c100% 298/12 │
│ 128k       │ 196.6 c100% 314/5 │ 357.8 (4/4) c100% 673/11 │  649.7 c100% 1k/12 │
╰────────────┴───────────────────┴──────────────────────────┴────────────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports it). Prometheus is
kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out

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
Prefix-cache hit % = hits/queries over the decode phase (after the one-time scout warm-up), from the engine's own prefix-cache counters. High
when each lane re-hits its own warmed prefix; drops when many distinct lanes exceed KV capacity and force eviction.
Per-Request tok/s
╭────────────┬───────┬────────────┬──────╮
│ ctx \ conc │     1 │          4 │    8 │
├────────────┼───────┼────────────┼──────┤
│ 0          │ 183.0 │       93.0 │ 90.6 │
│ 32k        │ 187.0 │      101.4 │ 86.2 │
│ 128k       │ 196.6 │ 89.4 (4/4) │ 81.2 │
╰────────────┴───────┴────────────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx \ conc │           1 │           4 │           8 │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 0          │ 11.1k/11.3k │ 23.3k/23.4k │ 28.1k/28.5k │
│ 32k        │ 10.5k/11.7k │ 20.2k/21.5k │ 28.5k/30.4k │
│ 128k       │ 10.7k/10.9k │ 23.0k/25.0k │ 31.3k/34.5k │
╰────────────┴─────────────┴─────────────┴─────────────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed generated tokens, including
streams stopped at the measurement boundary; a missing ITL means no stream produced at least two measured output tokens. Per-request tok/s and
request latency are shown in separate per-cell matrices. Completion/sample counts and full request-level distributions remain in JSON under
request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput signal.
ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭─────────────────────────────────────────────────────────────────── Phase 3 ───────────────────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                                                            │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is intentionally disabled by     │
│ default because it adds another full decode matrix.                                                                                           │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭─────────────────────────────────────────────────────────────── Primary Summary ───────────────────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.                               │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬─────────────┬───────────────────┬─────────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │           1 │                 4 │           8 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼─────────────┼───────────────────┼─────────────┤
│ 8k   │   8,192 │   0.66 │ 12,356 │ 1 ││ 0          │       183.0 │             371.8 │       724.5 │
│ 32k  │  32,342 │   2.80 │ 11,561 │ 1 ││ 32k        │ 187.0 c100% │       405.7 c100% │ 689.3 c100% │
│ 64k  │  64,559 │   5.80 │ 11,134 │ 1 ││ 128k       │ 196.6 c100% │ 357.8 (4/4) c100% │ 649.7 c100% │
│ 128k │ 128,992 │  13.08 │  9,858 │ 1 │╰────────────┴─────────────┴───────────────────┴─────────────╯
╰──────┴─────────┴────────┴────────┴───╯
