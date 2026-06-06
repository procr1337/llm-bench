

──────────────────────────────────────── NVIDIA P2P Override ────────────────────────────────────────╮
│ Effective: no                                                                                       │
│ Configured file: no (/etc/modprobe.d/nvidia-p2p-override.conf)                                      │
│ Runtime: ForceP2P=; RMForceP2PType=; RMPcieP2PType=; GrdmaPciTopoCheckOverride=;                    │
│ EnableResizableBar=0; DmaRemapPeerMmio=1                                                            │
│ Suggested modprobe line:                                                                            │
│ options nvidia                                                                                      │
│ NVreg_RegistryDwords="ForceP2P=0x11;RMForceP2PType=1;RMPcieP2PType=2;GrdmaPciTopoCheckOverride=1;En │
│ ableResizableBar=1"                                                                                 │
│ Apply requires NVIDIA module reload or reboot after stopping GPU workloads.                         │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─────────────────────────────────────────── Configuration ───────────────────────────────────────────╮
│ LLM Inference Benchmark                                                                             │
│ Model: Qwen3.5 @ 172.23.0.10:8000                                                                   │
│ Decode concurrency: [1, 4, 16]                                                                      │
│ Decode contexts: ['0', '32k', '128k']                                                               │
│ Duration: 30.0s per decode test | Max tokens: 2048                                                  │
│ Pre-decode warmup: C=1 max-runnable context for 3s                                                  │
│ Prefill: integrated decode scouts | Sustained decode: 9 cells                                       │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────╯
Engine: vLLM 0.21.1rc1.dev339+g1967a5627bc3  Models: ['deepseek-v4-flash']
KV cache budget (vLLM metrics): 2,863,616 tokens (11186 blocks × 256)
Model context length: 393,216 tokens
Prefill tests: integrated from decode scout requests ['32k', '128k']; scout-only extras ['8k', '64k']
Calibrating padding text (run=snatezbsvsvz, up to 128k)...
  Token targeting: single-point estimate from 8k (use --token-targeting exact for /tokenize binary
search)
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
  8k         ~8,192       0.68         12,131              —                —   1
  32k        32,342       2.84         11,369              —                —   1
  64k        64,559       5.84         11,047              —                —   1
  128k      128,992      13.22          9,758              —                —   1

Client tok/s = prompt_tokens / TTFT. Integrated scout rows come from the prefix-cache scout request
that decode needs anyway. Server tok/s is optional Prometheus validation when the engine exports
prefill counters and the exact counter delta is uncontaminated.

╭────────────────────────────────────────────── Phase 2 ──────────────────────────────────────────────╮
│ Sustained Decode                                                                                    │
│ Steady-state decode throughput after the engine has admitted the requested concurrency and passed   │
│ warmup. Use this as the main tuning/regression signal for kernels, NCCL, DCP, MTP, and scheduler    │
│ changes.                                                                                            │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────╯
Aggregate tok/s  + TTFT/ITL
╭────────────┬─────────────┬────────────────────┬───────────────╮
│ ctx \ conc │           1 │                  4 │            16 │
├────────────┼─────────────┼────────────────────┼───────────────┤
│ 0          │  188.8 42/5 │        372.8 72/11 │ 1119.0 127/14 │
│ 32k        │ 191.4 127/5 │       375.8 201/10 │   913.1 1k/19 │
│ 128k       │ 188.8 352/5 │ 361.2 (4/4) 895/11 │   822.5 6k/19 │
╰────────────┴─────────────┴────────────────────┴───────────────╯
Sustained Decode: aggregate tok/s uses OpenAI stream usage by default (continuous completion_tokens
when the server supports it). Prometheus is kept as validation/scheduler data.
Aggregate source(s): openai_continuous_usage
(X/Y) = avg running / requested concurrency from Prometheus; * = capacity-limited or warmup timed out
Per-Request tok/s
╭────────────┬───────┬────────────┬──────╮
│ ctx \ conc │     1 │          4 │   16 │
├────────────┼───────┼────────────┼──────┤
│ 0          │ 188.8 │       93.2 │ 69.9 │
│ 32k        │ 191.4 │       93.9 │ 57.1 │
│ 128k       │ 188.8 │ 90.3 (4/4) │ 51.4 │
╰────────────┴───────┴────────────┴──────╯
Client request latency: p50 / p90 ms
╭────────────┬─────────────┬─────────────┬─────────────╮
│ ctx \ conc │           1 │           4 │          16 │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 0          │ 10.9k/10.9k │ 21.7k/22.3k │ 34.3k/34.9k │
│ 32k        │ 10.6k/11.1k │ 21.5k/23.0k │ 34.3k/35.7k │
│ 128k       │ 11.1k/11.5k │ 25.2k/25.3k │ 33.5k/33.5k │
╰────────────┴─────────────┴─────────────┴─────────────╯
Aggregate cells show dim detail as TTFT ms / ITL ms for the same ctx/conc coordinate. ITL is computed
from observed generated tokens, including streams stopped at the measurement boundary; a missing ITL
means no stream produced at least two measured output tokens. Per-request tok/s and request latency are
shown in separate per-cell matrices. Completion/sample counts and full request-level distributions
remain in JSON under request_samples.
Sustained mode: client latency metrics explain request UX variance; aggregate tok/s remains the primary
throughput signal. ITL=(last_token_time-first_token_time)/(output_tokens-1), user tok/s=1/ITL.

╭────────────────────────────────────────────── Phase 3 ──────────────────────────────────────────────╮
│ Burst / E2E Decode                                                                                  │
│ Not run. Re-run with --run-burst to append a finite client-facing request burst after Sustained     │
│ Decode. This is intentionally disabled by default because it adds another full decode matrix.       │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────╯

╭────────────────────────────────────────── Primary Summary ──────────────────────────────────────────╮
│ Primary matrices repeated last so the important numbers are visible without scrolling back through  │
│ diagnostics.                                                                                        │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────╯
Prefill tok/s                           Aggregate decode tok/s
╭──────┬─────────┬────────┬────────┬───╮╭────────────┬───────┬─────────────┬────────╮
│ ctx  │  tokens │ TTFT s │  tok/s │ N ││ ctx \ conc │     1 │           4 │     16 │
├──────┼─────────┼────────┼────────┼───┤├────────────┼───────┼─────────────┼────────┤
│ 8k   │   8,192 │   0.68 │ 12,131 │ 1 ││ 0          │ 188.8 │       372.8 │ 1119.0 │
│ 32k  │  32,342 │   2.84 │ 11,369 │ 1 ││ 32k        │ 191.4 │       375.8 │  913.1 │
│ 64k  │  64,559 │   5.84 │ 11,047 │ 1 ││ 128k       │ 188.8 │ 361.2 (4/4) │  822.5 │
│ 128k │ 128,992 │  13.22 │  9,758 │ 1 │╰────────────┴───────┴─────────────┴────────╯
╰──────┴─────────┴────────┴────────┴───╯

Results saved to benchmark_results.json
