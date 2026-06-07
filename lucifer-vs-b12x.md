# Lucifer vs B12X: DSV4 Flash on RTX Pro 6000

Two competing vLLM kernel stacks for running DeepSeek-V4-Flash on SM120 (Blackwell) GPUs over PCIe.

## Origins

**Lucifer** — [vllm-project/vllm#43477](https://github.com/vllm-project/vllm/pull/43477) by [lucifer1004](https://github.com/lucifer1004) (Zihua Wu). Upstream PR titled "Enable DeepSeek V4 and GLM-5.1 on SM120." Still open/draft — blocked on two upstream dependency PRs:

- FlashInfer SM120 sparse MLA kernels: [flashinfer-ai/flashinfer#3395](https://github.com/flashinfer-ai/flashinfer/pull/3395)
- DeepGEMM SM120/MXFP4: [deepseek-ai/DeepGEMM#324](https://github.com/deepseek-ai/DeepGEMM/pull/324)

**B12X** — [lukealonso/b12x](https://github.com/lukealonso/b12x), Luke's custom kernel library for SM120. The `b12x` branch in `local-inference-lab/vllm` (currently `abyssal-abjuration`) integrates these kernels into vLLM via env-var opt-in flags. Not an upstream PR — a parallel fork.

## Architecture comparison

| Component | Lucifer | B12X |
|---|---|---|
| Attention backend | `SPARSE_MLA_SM120` (FlashInfer) | `B12X_MLA_SPARSE` |
| MoE backend | DeepGEMM MXFP4 or `flashinfer_cutlass` | `b12x` fused CuteDSL kernel |
| Linear layers | FP8 block-scaled (upstream) | `b12x` FP8 block-scaled (`VLLM_USE_B12X_FP8_GEMM=1`) |
| AllReduce | Upstream custom allreduce | `b12x` PCIe allreduce (`VLLM_PCIE_ALLREDUCE_BACKEND=b12x`) |
| WO projection | Upstream | `b12x` (`VLLM_USE_B12X_WO_PROJECTION=1`) |
| CUDAGraph | Standard | Full + piecewise with AOT compile (`VLLM_USE_AOT_COMPILE=1`) |

## MoE precision — why b12x prefill is 2–3× slower

The MoE GEMMs dominate both prefill and decode compute. The two stacks use different precisions and, critically, different tensor core instructions.

### What the code actually does

DSV4 Flash ships with native **MXFP4** (E2M1 + E8M0 block scales) MoE weights. This is important because it determines the b12x code path:

```python
# b12x_moe.py: B12xExperts._quant_mode()
def _quant_mode(self) -> str:
    # B12X_MOE_FORCE_A16 only applies to NVFP4 checkpoints (GLM-5.1, Qwen3.5)
    if self.quant_config.quant_dtype == "nvfp4" and _env_flag("B12X_MOE_FORCE_A16"):
        return "w4a16"
    return "nvfp4" if self.quant_config.quant_dtype == "nvfp4" else "w4a16"
    #                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    #                   DSV4 Flash is MXFP4, not NVFP4 → always returns "w4a16"
```

For DSV4 Flash, b12x **always** runs in `quant_mode="w4a16"` — there is no opt-in flag involved. The `B12X_MOE_FORCE_A16` env var only matters for NVFP4 models.

### The hardware constraint

From the discord (May 11):

> **SM120 has no native W4A16 PTX** — b12x W4A16 dequantizes to BF16 MMA; hardware only supports W4A4

SM120 tensor cores natively support:
- **FP4 × FP4** (W4A4) — full throughput
- **MXFP4 × MXFP8** — full throughput (native microscaling format)
- **BF16 × BF16** — ~0.25–0.5× throughput relative to FP4

There is **no native FP4 × BF16 tensor core instruction**. So b12x's "W4A16" mode:
1. Dequantizes FP4 weights to BF16 at weight-prep time (`prepare_w4a16` in `_get_or_prepare_fp4_moe_weights`)
2. Runs **BF16 × BF16 MMA** on the tensor cores

Lucifer's CUTLASS path uses the **native MXFP4 × MXFP8** TC instruction — activations are quantized to MXFP8, and the GEMM runs at full FP4-class throughput.

### Precision vs throughput matrix

| | B12X (W4A16) | Lucifer CUTLASS (W4A8) | Lucifer DeepGEMM |
|---|---|---|---|
| Weight format | MXFP4 → **dequant to BF16** | MXFP4 (native) | MXFP4 (native) |
| Activation format | **BF16** (no quantization) | **MXFP8** (quantized from BF16) | MXFP4 or MXFP8 |
| TC instruction | **BF16 × BF16** | **MXFP4 × MXFP8** (native) | MXFP4 × MXFP4/8 (native) |
| Relative TC throughput | ~0.25–0.5× | **1×** | **1×** |
| Activation precision | Highest (no quant loss) | Medium (8-bit quant) | Lower (4 or 8-bit) |
| Kernel style | Fused (dispatch + 2× GEMM + SwiGLU + topk) | Separate GEMM calls | Separate GEMM calls |

The 2–3× prefill gap is a **direct consequence of the TC instruction choice**: BF16 MMA runs at a fraction of the throughput of native FP4 MMA on SM120. This is not a bug — it is an architectural decision to preserve activation precision.

### Why b12x still wins on decode

Decode is memory-bandwidth-bound (single token per sequence, tiny batch). TC throughput is irrelevant — the GPU spends most of its time waiting for data, not computing. B12X's fused kernel wins here by:
- Avoiding intermediate materializations between the two MoE GEMMs
- Using the `B12X_W4A16_TC_DECODE=1` path optimized for single-token batches
- Custom PCIe allreduce (`VLLM_PCIE_ALLREDUCE_BACKEND=b12x`) reducing NCCL overhead

### Luke's planned fix (May 20)

> **B12X_MOE_FORCE_A16=1 fix incoming**: Luke confirms two changes: general prefill speedup (from 1/2 → ~2/3 of normal) and a **new A4-prefill / A16-decode mode**

The ideal hybrid: use **W4A4 (native FP4 TCs)** for prefill where TC throughput matters, and **W4A16 (BF16 MMA)** for decode where precision matters and TC throughput doesn't. This would close the prefill gap while preserving decode quality. Status unknown — not yet visible in the `abyssal-abjuration` branch checked out in `vllm/`.

### Does A16 actually help quality?

It depends on the model.

**GLM-5.1 NVFP4 (post-training quantization):** A16 matters enormously. Estonia benchmark (May 27):

| GLM-5.1 quant | Estonia score |
|---|---|
| NVFP4 (W4A4) | 25/30 |
| AWQ (W4A16) | 27/30 |
| NVFP4 + b12x A16 | **30/30** (perfect) |

The discord reported "20× less NVFP4 precision loss" with `B12X_MOE_FORCE_A16=1`. KLD measurements confirmed: mixed FP8 on sensitive layers + NVFP4 W4A16 elsewhere achieved 28% lower KLD vs pure NVFP4.

Decode speed penalty is minimal — from GLM-5.1 v5 benchmarks (8× RTX Pro 6000):

| DCP | Mode | cc=1 tok/s | cc=16 tok/s |
|---:|---|---:|---:|
| 1 | A4 | 87.8 | 561.3 |
| 1 | A16 | 85.8 | 558.1 |
| 4 | A4 | 69.6 | 383.8 |
| 4 | A16 | 65.0 | 389.5 |

~2% decode cost at DCP=1, essentially free at DCP=4. Decode is memory-bound so the BF16 MMA throughput penalty doesn't matter.

**DSV4 Flash MXFP4 (native model weights):** No measured benefit. Both Lucifer DeepGEMM (A4/A8) and b12x (A16) score identically: **EXACT 28 / NEAR 2 / FAIL 0** on Estonia. DSV4 Flash was trained with native MXFP4 weights — DeepSeek designed it to tolerate low-precision activations. GLM-5.1 NVFP4 is a post-training quantization, making it more sensitive to further precision loss.

**Summary:**

| Model | A16 quality benefit | A16 prefill cost | A16 decode cost |
|---|---|---|---|
| GLM-5.1 NVFP4 | **Huge** (25→30/30 Estonia, 20× less KLD) | ~2–4× slower | ~2% slower |
| DSV4 Flash MXFP4 | **None measured** | ~2–3× slower | Negligible |

For DSV4 Flash, b12x's A16 path is **all cost, no measured benefit**. It runs W4A16 because `B12xExperts._quant_mode()` returns `"w4a16"` for any non-NVFP4 checkpoint — MXFP4 falls into the `else` branch. This isn't an intentional precision choice for DSV4 Flash; it's a code path that was designed for NVFP4 models where A16 genuinely helps.

## Benchmark results (TP=2, 2× RTX Pro 6000 @ 450W)

### Prefill (tok/s, c=1)

| Context | Lucifer (voipmonitor1) | Lucifer @ 600W | B12X voipmonitor2 | B12X lavd1 | Lucifer cstechdev1 |
|---:|---:|---:|---:|---:|---:|
| 8k | 12,492 | 13,390 | 5,590 | 5,415 | 12,463 |
| 32k | 11,526 | 13,051 | 3,063 | 4,734 | 11,552 |
| 64k | 11,284 | 12,587 | 4,221 | 4,115 | 11,125 |
| 128k | 10,006 | 11,472 | 3,265 | 3,247 | 9,885 |

Lucifer is **2–3× faster on prefill** across all context lengths. This is a direct TC instruction effect: Lucifer uses native MXFP4×MXFP8 tensor core ops at full SM120 throughput, while b12x dequantizes MXFP4 weights to BF16 and runs BF16×BF16 MMA at ~0.25–0.5× the throughput (see [MoE precision](#moe-precision--why-b12x-prefill-is-23-slower) above).

### Decode (aggregate tok/s)

| Context \ Concurrency | Lucifer voipmonitor1 c=1 | B12X voipmonitor2 c=1 | B12X lavd1 c=1 | Lucifer voipmonitor1 c=4 | B12X voipmonitor2 c=4 | B12X lavd1 c=4 |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 187.4 | 185.5 | 185.3 | 376.8 | 428.2 | 438.9 |
| 32k | 196.0 | 188.2 | 187.8 | 370.9 | 405.4 | 431.8 |
| 128k | 195.8 | 192.1 | 183.2 | 361.8 | 391.3 | 402.2 |

At c=1 they're **roughly equal** (~185–196 tok/s). At c=4+, **B12X pulls ahead** thanks to the fused kernel and b12x PCIe allreduce. The discord reports even larger gaps at higher concurrency on later b12x branches (apotheosis: 250 tok/s c=1, 960 tok/s c=8 vs Lucifer's ~187/650).

### Summary

| Metric | Winner | Margin |
|---|---|---|
| Prefill throughput | **Lucifer** | 2–3× |
| Decode c=1 | Tie | ±5% |
| Decode c=4+ | **B12X** | 10–20% |
| Decode c=8+ (discord) | **B12X** | ~50% |

## Accuracy

From community testing (Estonia benchmark, ~500-test runs):

| Image | Result |
|---|---|
| Lucifer DeepGEMM (`cstechdev/dsv4-flash`) | Never FAILs. EXACT 28+ / NEAR 2 / FAIL 0 |
| B12X (`lavd/vllm:b12x-*`) | EXACT 28 / NEAR 2 / FAIL 0 |
| Lucifer CUTLASS (`voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-*`) | Consistent FAILs after ~500 tests (Jun 4 report) |

The CUTLASS MoE overlay has a suspected bug — despite using higher activation precision (MXFP8 vs FP4), it produces worse outputs than both the base Lucifer DeepGEMM path and b12x. Community recommendation (Jun 5): avoid `flashinfer_cutlass` until confirmed.

## Docker images tested

| Name | Image | Stack | MoE backend |
|---|---|---|---|
| voipmonitor1 | `voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603` | Lucifer + CUTLASS overlay | `flashinfer_cutlass` |
| cstechdev1 | `cstechdev/dsv4-flash@sha256:27b8…` | Lucifer (DeepGEMM) | DeepGEMM MXFP4 |
| voipmonitor2 | `voipmonitor/vllm:abyssal-abjuration-611a842-a16-dcp-wsfix` | B12X | `b12x` fused CuteDSL |
| lavd1 | `lavd/vllm:b12x-abyssal-abjuration-6-5-13.2-2` | B12X | `b12x` fused CuteDSL |

### cstechdev image provenance

The `cstechdev/dsv4-flash:latest` image is a black-box build from the Lucifer branch. Known facts:

- vLLM `0.21.1rc1.dev339+g1967a5627bc3` (commit `1967a5627bc3710b680bbec24ecb99aaddedf22b`)
- PyTorch 2.11.0+cu130, FlashInfer 0.6.12, NCCL 2.28.9
- No Dockerfile or build script published; no `.git` checkout in image
- Discord describes it as "lucifer kernels + tool parser/prefix cache patches"

### B12X image provenance

Both voipmonitor2 and lavd1 are built from Luke's `b12x` branch (`abyssal-abjuration` tag) of `local-inference-lab/vllm`. The voipmonitor2 image includes a workspace-reserve patch (`-wsfix`). lavd1 additionally supports `--load-format instanttensor` for faster model loading.

## Key env vars (B12X)

The b12x stack is activated via env vars, all opt-in:

```
VLLM_USE_B12X_MHC=1              # Multi-head cache
VLLM_USE_B12X_FP8_GEMM=1         # FP8 block-scaled linear
VLLM_USE_B12X_MOE=1              # Fused NVFP4 MoE
VLLM_USE_B12X_WO_PROJECTION=1    # Output projection
VLLM_USE_B12X_SPARSE_INDEXER=1   # Sparse attention indexing
VLLM_PCIE_ALLREDUCE_BACKEND=b12x # PCIe allreduce
VLLM_ENABLE_PCIE_ALLREDUCE=1
VLLM_USE_AOT_COMPILE=1           # Ahead-of-time CUDA compilation
B12X_W4A16_TC_DECODE=1           # W4A16 tensor-core decode path
B12X_DENSE_SPLITK_TURBO=1        # Split-K decode optimization
B12X_MLA_SM120_UNIFIED=1         # Unified MLA path
```

## Timeline

| Date | Event |
|---|---|
| May 23 | Lucifer PR #43477 opened; pre-built image at `lucifer1004/dsv4-flash-sm120:latest` |
| May 25 | Community testing begins — 120 tok/s TP=4 no MTP; MTP broken, garbage at high concurrency |
| May 27 | Lucifer breakthrough: 102.9 tok/s c=1 vs jasl 69.4 vs b12x 84; accuracy confirmed |
| May 28 | Luke merges b12x + lucifer FlashInfer → **"unholy-fusion"** branch, 245 tok/s decode |
| May 29 | Prefill fix cherry-picked from jasl → 13,413 tok/s prefill |
| May 30 | `cstechdev/dsv4-flash:latest` ships (lucifer kernels + patches); Luke previews `apostolic-purification` |
| Jun 1 | Luke's `apotheosis` branch: 250 tok/s c=1, 960 tok/s c=8; prefill regression acknowledged (1–3k first run) |
| Jun 2 | `voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603` released (CUTLASS MoE overlay) |
| Jun 4 | CUTLASS MoE quality failures reported; Lucifer DeepGEMM path still clean |
| Jun 5 | `lavd/vllm:b12x-abyssal-abjuration-6-5-13.2-2` released; b12x accuracy confirmed solid |

## Open questions

- **B12X prefill gap**: Luke acknowledged leaving "something serial that should be parallel" in the prefill path. Will future b12x branches close the 2–3× gap?
- **CUTLASS MoE accuracy**: Is the quality regression a bug or a fundamental precision issue with the `flashinfer_cutlass` backend?
- **Upstream merge**: Lucifer PR is blocked on FlashInfer #3395 and DeepGEMM #324. No ETA.
- **Hybrid approach**: The "unholy-fusion" branch combined b12x decode + lucifer prefill. Could a production config switch MoE backends between prefill and decode phases?
