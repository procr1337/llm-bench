TP: 2
Waiting for startup
Running benchmark
╭────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────╮
│ Effective: yes                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1;    │
│ DmaRemapPeerMmio=1                                                                                               │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭───────────────────────────────────────────────── Configuration ──────────────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                                          │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                │
│ Decode concurrency: [1, 4, 8]                                                                                    │
│ Decode contexts: ['0', '32k', '128k']                                                                            │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                               │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                               │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                                    │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.11.2.dev279+chthonic.consecration.2cdc3d9.b12xd311dba.latest.cu132.20260615  Models:
['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (25,032 tokens), but DCP/CP multiplier is not exported by this server.
Pass --dcp-size N or --kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead
of assuming DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue
detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=ucbiojdlphmt, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,192 chars (~8,191 tokens)
  32k: 204,768 chars (~32,767 tokens)
  64k: 409,537 chars (~65,535 tokens)
  128k: 819,075 chars (~131,071 tokens)
Done.



llm-decode-bench v0.4.24
Prefill Speed (scout requests, client ISL / TTFT)

  Context    Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ─────────────────────────────────────────────────────────────────────────────────
  8k         ~8,192       1.10          7,469              —                —   1
  32k        32,342       4.66          6,947              —                —   1
  64k        64,559       9.63          6,701              —                —   1
  128k      128,992      21.54          5,990              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode
needs anyway. Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact
counter delta is uncontaminated.

╭──────────────────────────────────────────────────── Phase 2 ─────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                 │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use    │
│ this as the main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                    │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬───────────────────┬──────────────╮
│ ctx \ conc │           1 │                 4 │            8 │
├────────────┼─────────────┼───────────────────┼──────────────┤
│ 0          │ 199.1 103/5 │       458.6 178/9 │ 634.0 281/13 │
│ 32k        │ 202.4 156/5 │ 452.1 (4/4) 235/9 │ 590.2 381/13 │
│ 128k       │ 199.7 497/5 │      402.4 835/10 │  514.7 2k/15 │
╰────────────┴─────────────┴───────────────────┴──────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server
supports it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out
Per-Request tok/s
╭────────────┬───────┬─────────────┬──────╮
│ ctx \ conc │     1 │           4 │    8 │
├────────────┼───────┼─────────────┼──────┤
│ 0          │ 199.1 │       114.6 │ 79.2 │
│ 32k        │ 202.4 │ 113.0 (4/4) │ 73.8 │
│ 128k       │ 199.7 │       100.6 │ 64.3 │
╰────────────┴───────┴─────────────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx \ conc │           1 │           4 │           8 │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 0          │ 10.1k/10.4k │ 18.2k/18.6k │ 27.9k/29.0k │
│ 32k        │ 10.1k/10.5k │ 18.3k/19.0k │ 28.6k/30.0k │
│ 128k       │ 10.7k/10.8k │ 21.2k/22.5k │ 36.8k/39.3k │
╰────────────┴─────────────┴─────────────┴─────────────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed
generated tokens, including streams stopped at the measurement boundary; a missing ITL means no stream produced at
least two measured output tokens. Per-request tok/s and request latency are shown in separate per-cell matrices.
Completion/sample counts and full request-level distributions remain in JSON under request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput
signal. ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭──────────────────────────────────────────────────── Phase 3 ─────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                               │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is  │
│ intentionally disabled by default because it adds another full decode matrix.                                    │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭──────────────────────────────────────────────── Primary Summary ─────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.  │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                          Aggregate decode tok/s
╭──────┬─────────┬────────┬───────┬───╮╭────────────┬───────┬─────────────┬───────╮
│ ctx  │  tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │     1 │           4 │     8 │
├──────┼─────────┼────────┼───────┼───┤├────────────┼───────┼─────────────┼───────┤
│ 8k   │   8,192 │   1.10 │ 7,469 │ 1 ││ 0          │ 199.1 │       458.6 │ 634.0 │
│ 32k  │  32,342 │   4.66 │ 6,947 │ 1 ││ 32k        │ 202.4 │ 452.1 (4/4) │ 590.2 │
│ 64k  │  64,559 │   9.63 │ 6,701 │ 1 ││ 128k       │ 199.7 │       402.4 │ 514.7 │
│ 128k │ 128,992 │  21.54 │ 5,990 │ 1 │╰────────────┴───────┴─────────────┴───────╯
╰──────┴─────────┴────────┴───────┴───╯

Results saved to /out/benchmark_results.json
Running estonia test
╭────────────────────────────────────────────── NVIDIA P2P Override ───────────────────────────────────────────────╮
│ Effective: yes                                                                                                   │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                                   │
│ Runtime: ForceP2P=0x11; RMForceP2PType=1; RMPcieP2PType=2; GrdmaPciTopoCheckOverride=1; EnableResizableBar=1;    │
│ DmaRemapPeerMmio=1                                                                                               │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭───────────────────────────────────────────────── Configuration ──────────────────────────────────────────────────╮
│ Completion Token Statistics Benchmark                                                                            │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                                │
│ Prompt: profile:estonia                                                                                          │
│ Concurrency: 30                                                                                                  │
│ Measured runs: 50 | Max tokens: 40000                                                                            │
│ Scoring: \bestonia\b                                                                                             │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭──────────────────────────────────────────────── Completion Stats ────────────────────────────────────────────────╮
│ Completion Token Statistics                                                                                      │
│ One optional prefix-cache scout request is used to populate prefill first. Built-in profile run at fixed         │
│ concurrency C=30.                                                                                                │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Profile
╭────────────────┬───────────────────────────────────────────╮
│ field          │ value                                     │
├────────────────┼───────────────────────────────────────────┤
│ profile        │ estonia                                   │
│ prompt         │ profile:estonia                           │
│ prompt chars   │ 707,372                                   │
│ requested runs │ 50                                        │
│ concurrency    │ 30                                        │
│ max tokens     │ 40000                                     │
│ scoring        │ regex                                     │
│ prefill scout  │ 134,138 prompt tok / 23.09s = 5,808 tok/s │
│ correct regex  │ \bestonia\b                               │
╰────────────────┴───────────────────────────────────────────╯
Concurrency Results
╭────────┬────────────┬───────────────┬──────────┬─────────────┬──────────────┬──────────────┬─────────────┬───────╮
│ paral… │ done/star… │         score │  stars   │ output tok… │ output tok … │ aggregate t… │ avg reques… │ sele… │
├────────┼────────────┼───────────────┼──────────┼─────────────┼──────────────┼──────────────┼─────────────┼───────┤
│     30 │      50/50 │ PASS 50 / FA… │ ★★★★★★★… │       1,790 │        4,051 │         36.9 │        66.4 │  yes  │
╰────────┴────────────┴───────────────┴──────────┴─────────────┴──────────────┴──────────────┴─────────────┴───────╯
Selected C=30
╭────────────────────────────┬──────────────────╮
│ metric                     │            value │
├────────────────────────────┼──────────────────┤
│ completed                  │            50/50 │
│ score                      │ PASS 50 / FAIL 0 │
│ stars                      │    ★★★★★★★★★★ 👍 │
│ hit max_tokens             │                0 │
│ completion tokens avg      │            2,204 │
│ completion tokens p50      │            1,790 │
│ completion tokens p90      │            4,051 │
│ completion tokens p99      │            7,257 │
│ elapsed avg                │            66.4s │
│ TTFT avg                   │            6.62s │
│ aggregate gen tok/s        │             36.9 │
│ mean per-request gen tok/s │             34.9 │
╰────────────────────────────┴──────────────────╯
Interpretation: completion-token p50/p90/p99 tells how many decode tokens the model needed to reach its final answer
under this engine/config. Correctness is scored from the final non-empty answer line by default, matching the GLM
dense-MLA vs NSA benchmark methodology. The prefill scout is not a scored answer; it is the max_tokens=1
prefix-cache warmup and its prompt_tokens/TTFT value is reported as scout prefill speed. Concurrency Results groups
completed requests by parallelism; Completed Requests shows the latest individual finished answers.

Results saved to /out/benchmark_results_estonia.json
