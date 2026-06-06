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
Engine: vLLM 0.11.2.dev278+abyssal.cu132.20260605  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (29,116 tokens), but DCP/CP multiplier is not exported by this server. Pass
--dcp-size N or --kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming
DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=viigpuxeramt, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary search)
  Calibrated: 6.25 chars/token (from 8k probe)
  8k: 51,192 chars (~8,191 tokens)
  32k: 204,768 chars (~32,767 tokens)
  64k: 409,537 chars (~65,535 tokens)
  128k: 819,075 chars (~131,071 tokens)
Done.


Interrupted by user. Saving partial results...


llm-decode-bench v0.4.24
Prefill Speed (scout requests, client ISL / TTFT)

  Context   Tokens   TTFT (s)   Client tok/s   Server tok/s   PCIe rx/tx avg   N
 ────────────────────────────────────────────────────────────────────────────────
  8k        ~8,192       1.45          5,634              —                —   1
  32k       32,342       6.74          4,797              —                —   1
  64k       64,559      15.25          4,234              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway.
Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the   │
│ main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                           │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬────────────┬───┬────╮
│ ctx \ conc │          1 │ 4 │ 16 │
├────────────┼────────────┼───┼────┤
│ 0          │ 88.6 89/11 │ - │  - │
│ 32k        │          - │ - │  - │
│ 128k       │          - │ - │  - │
╰────────────┴────────────┴───┴────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports
it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
Per-Request tok/s
╭────────────┬──────┬───┬────╮
│ ctx \ conc │    1 │ 4 │ 16 │
├────────────┼──────┼───┼────┤
│ 0          │ 88.6 │ - │  - │
│ 32k        │    - │ - │  - │
│ 128k       │    - │ - │  - │
╰────────────┴──────┴───┴────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬───┬────╮
│ ctx \ conc │           1 │ 4 │ 16 │
├────────────┼─────────────┼───┼────┤
│ 0          │ 23.2k/23.2k │ - │  - │
│ 32k        │           - │ - │  - │
│ 128k       │           - │ - │  - │
╰────────────┴─────────────┴───┴────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed generated
tokens, including streams stopped at the measurement boundary; a missing ITL means no stream produced at least two measured
output tokens. Per-request tok/s and request latency are shown in separate per-cell matrices. Completion/sample counts and full
request-level distributions remain in JSON under request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput signal.
ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭────────────────────────────────────────────────────────── Phase 3 ──────────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                                          │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is             │
│ intentionally disabled by default because it adds another full decode matrix.                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭────────────────────────────────────────────────────── Primary Summary ──────────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.             │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                        Aggregate decode tok/s
╭─────┬────────┬────────┬───────┬───╮╭────────────┬──────┬───┬────╮
│ ctx │ tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │    1 │ 4 │ 16 │
├─────┼────────┼────────┼───────┼───┤├────────────┼──────┼───┼────┤
│ 8k  │  8,192 │   1.45 │ 5,634 │ 1 ││ 0          │ 88.6 │ - │  - │
│ 32k │ 32,342 │   6.74 │ 4,797 │ 1 ││ 32k        │    - │ - │  - │
│ 64k │ 64,559 │  15.25 │ 4,234 │ 1 ││ 128k       │    - │ - │  - │
╰─────┴────────┴────────┴───────┴───╯╰────────────┴──────┴───┴────╯

Results saved to /out/benchmark_results.json
[llm3] ~/llm3 ❯ ./bench.sh lavd1
[llm3] ~/llm3 ❯ rm -rf bench_results/voipmonitor2
[llm3] ~/llm3 ❯ ./bench.sh voi
[llm3] ~/llm3 ❯ ./bench.sh lavd1
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
Engine: vLLM 0.1.dev1+g611a842dc.d20260605  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (28,808 tokens), but DCP/CP multiplier is not exported by this server. Pass
--dcp-size N or --kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming
DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=deaykcdxfqza, up to 128k)...
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
  8k         ~8,192       1.46          5,616              —                —   1
  32k        32,342      10.39          3,111              —                —   1
  64k        64,559      15.25          4,233              —                —   1
  128k      128,992      39.41          3,273              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway.
Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the   │
│ main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                           │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬──────────────┬──────────────╮
│ ctx \ conc │           1 │            4 │           16 │
├────────────┼─────────────┼──────────────┼──────────────┤
│ 0          │  188.3 89/5 │  426.0 152/9 │ 814.5 702/19 │
│ 32k        │ 182.8 141/5 │  428.6 234/9 │  743.8 1k/23 │
│ 128k       │ 186.8 423/5 │ 403.0 924/10 │  673.3 5k/24 │
╰────────────┴─────────────┴──────────────┴──────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports
it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
Per-Request tok/s
╭────────────┬───────┬───────┬──────╮
│ ctx \ conc │     1 │     4 │   16 │
├────────────┼───────┼───────┼──────┤
│ 0          │ 188.3 │ 106.5 │ 50.9 │
│ 32k        │ 182.8 │ 107.2 │ 46.5 │
│ 128k       │ 186.8 │ 100.8 │ 42.1 │
╰────────────┴───────┴───────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────╮
│ ctx \ conc │           1 │           4 │  16 │
├────────────┼─────────────┼─────────────┼─────┤
│ 0          │ 11.2k/11.2k │ 19.4k/20.0k │ —/— │
│ 32k        │ 11.0k/11.1k │ 19.6k/19.8k │ —/— │
│ 128k       │ 11.1k/11.3k │ 21.4k/22.1k │ —/— │
╰────────────┴─────────────┴─────────────┴─────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed generated
tokens, including streams stopped at the measurement boundary; a missing ITL means no stream produced at least two measured
output tokens. Per-request tok/s and request latency are shown in separate per-cell matrices. Completion/sample counts and full
request-level distributions remain in JSON under request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput signal.
ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭────────────────────────────────────────────────────────── Phase 3 ──────────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                                          │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is             │
│ intentionally disabled by default because it adds another full decode matrix.                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭────────────────────────────────────────────────────── Primary Summary ──────────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.             │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                          Aggregate decode tok/s
╭──────┬─────────┬────────┬───────┬───╮╭────────────┬───────┬───────┬───────╮
│ ctx  │  tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │     1 │     4 │    16 │
├──────┼─────────┼────────┼───────┼───┤├────────────┼───────┼───────┼───────┤
│ 8k   │   8,192 │   1.46 │ 5,616 │ 1 ││ 0          │ 188.3 │ 426.0 │ 814.5 │
│ 32k  │  32,342 │  10.39 │ 3,111 │ 1 ││ 32k        │ 182.8 │ 428.6 │ 743.8 │
│ 64k  │  64,559 │  15.25 │ 4,233 │ 1 ││ 128k       │ 186.8 │ 403.0 │ 673.3 │
│ 128k │ 128,992 │  39.41 │ 3,273 │ 1 │╰────────────┴───────┴───────┴───────╯
╰──────┴─────────┴────────┴───────┴───╯

Results saved to /out/benchmark_results.json
[llm3] ~/llm3 ❯ rm -rf bench_results/lavd1
[llm3] ~/llm3 ❯ ./bench.sh lavd1
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
Engine: vLLM 0.1.dev1+g611a842dc.d20260605  Models: ['deepseek-v4-flash']
vLLM Prometheus reports only local KV cache (28,808 tokens), but DCP/CP multiplier is not exported by this server. Pass
--dcp-size N or --kv-budget to enable exact KV capacity skips for remote vLLM. Leaving KV budget unset instead of assuming
DCP=1.
vLLM: KV cache budget not available from metrics. Use --kv-budget to skip over-capacity cells, or rely on queue detection.
Model context length: 262,144 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=lukgpixxbxzm, up to 128k)...
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
  8k         ~8,192       1.51          5,415              —                —   1
  32k        32,342       6.83          4,734              —                —   1
  64k        64,559      15.69          4,115              —                —   1
  128k      128,992      39.73          3,247              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request that decode needs anyway.
Server tok/s is optional Prometheus validation when the engine exports prefill counters and the exact counter delta is
uncontaminated.

╭────────────────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────────────────╮
│ Sustained Decode                                                                                                            │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed warmup. Use this as the   │
│ main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler changes.                                           │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬────────────────────┬──────────────╮
│ ctx \ conc │           1 │                  4 │           16 │
├────────────┼─────────────┼────────────────────┼──────────────┤
│ 0          │  185.3 90/5 │        438.9 135/9 │ 824.6 557/19 │
│ 32k        │ 187.8 149/5 │        431.8 216/9 │  782.7 1k/20 │
│ 128k       │ 183.2 423/5 │ 402.2 (4/4) 724/10 │  679.4 5k/23 │
╰────────────┴─────────────┴────────────────────┴──────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens when the server supports
it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out
Per-Request tok/s
╭────────────┬───────┬─────────────┬──────╮
│ ctx \ conc │     1 │           4 │   16 │
├────────────┼───────┼─────────────┼──────┤
│ 0          │ 185.3 │       109.7 │ 51.5 │
│ 32k        │ 187.8 │       108.0 │ 48.9 │
│ 128k       │ 183.2 │ 100.6 (4/4) │ 42.5 │
╰────────────┴───────┴─────────────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────╮
│ ctx \ conc │           1 │           4 │  16 │
├────────────┼─────────────┼─────────────┼─────┤
│ 0          │ 11.1k/11.1k │ 19.0k/19.4k │ —/— │
│ 32k        │ 10.7k/11.3k │ 19.7k/20.3k │ —/— │
│ 128k       │ 11.2k/11.5k │ 21.8k/22.5k │ —/— │
╰────────────┴─────────────┴─────────────┴─────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed from observed generated
tokens, including streams stopped at the measurement boundary; a missing ITL means no stream produced at least two measured
output tokens. Per-request tok/s and request latency are shown in separate per-cell matrices. Completion/sample counts and full
request-level distributions remain in JSON under request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary throughput signal.
ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭────────────────────────────────────────────────────────── Phase 3 ──────────────────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                                          │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained Decode. This is             │
│ intentionally disabled by default because it adds another full decode matrix.                                               │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭────────────────────────────────────────────────────── Primary Summary ──────────────────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through diagnostics.             │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                          Aggregate decode tok/s
╭──────┬─────────┬────────┬───────┬───╮╭────────────┬───────┬─────────────┬───────╮
│ ctx  │  tokens │ TTFT s │ tok/s │ N ││ ctx \ conc │     1 │           4 │    16 │
├──────┼─────────┼────────┼───────┼───┤├────────────┼───────┼─────────────┼───────┤
│ 8k   │   8,192 │   1.51 │ 5,415 │ 1 ││ 0          │ 185.3 │       438.9 │ 824.6 │
│ 32k  │  32,342 │   6.83 │ 4,734 │ 1 ││ 32k        │ 187.8 │       431.8 │ 782.7 │
│ 64k  │  64,559 │  15.69 │ 4,115 │ 1 ││ 128k       │ 183.2 │ 402.2 (4/4) │ 679.4 │
│ 128k │ 128,992 │  39.73 │ 3,247 │ 1 │╰────────────┴───────┴─────────────┴───────╯
╰──────┴─────────┴────────┴───────┴───╯

Results saved to /out/benchmark_results.json
