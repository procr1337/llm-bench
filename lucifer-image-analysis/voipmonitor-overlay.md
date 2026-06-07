# voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603 — Overlay Analysis

Image: `voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603`
SHA256: `sha256:71341a1a3fe8cba8283b2289d49c03023008b90426af51d86cba958e0684d385`

Base: `cstechdev/dsv4-flash@sha256:27b80536a36212cef21664699aee35acbc14b37f147d41cd9b12361154f3c4db`
(confirmed via OCI label `org.opencontainers.image.base.name`)

---

## What the overlay is

Exactly **two files** replaced on top of the full cstechdev image, applied 4 days ago
(1 day after the cstechdev T−5 days parser patch):

| Layer | File | Size |
|---|---|---|
| `COPY` | `vllm/model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py` | 61.4 kB |
| `COPY` | `vllm/model_executor/layers/fused_moe/oracle/mxfp4.py` | 115 kB |

Three OCI labels:
- `org.opencontainers.image.title`: `DeepSeek V4 Flash Lucifer MXFP4 CUTLASS overlay`
- `org.opencontainers.image.description`: `Adds FlashInfer CUTLASS MXFP4/MXFP8 MoE enablement over cstechdev/dsv4-flash`
- `org.opencontainers.image.base.name`: `cstechdev/dsv4-flash@sha256:27b80536...`

No wheel installs, no env changes, no entrypoint changes. Pure Python file replacement.

---

## Upstream provenance

Both files exist in the fork at `1967a5627bc3` and in upstream `vllm-project/vllm`.

**`flashinfer_cutlass_moe.py`** originates from upstream PR **#38251**
(`e8ebbdde8`, 2026-04-06, "Add FlashInfer CuteDSL batched experts backend for NVFP4
MoE"), with subsequent fixes in #39825 (SM121 disable), #40808 (SM110 disable), #41979
(moved to `experts/` subdir), #42855 (DSv4 swiglu bugfix), #44613 (max_capture_size).

**`mxfp4.py`** CUTLASS backend enum values and oracle routing came from upstream PR
**#37128** (`87bd91892f`, 2026-03-20, "MoE Refactor: Mxfp4 oracle rebased").

Both were already fully present in the fork at `1967a5627bc3` — the CUTLASS enum
values, `map_mxfp4_backend` routing, `backend_to_kernel_cls`, auto-selection priority,
and `_supports_current_device` with `capability_family(120)` were all there. What the
overlay adds is the two small patches described below.

---

## Patch 1 — `flashinfer_cutlass_moe.py`: optional SwiGLU alpha/beta for DSv4

**Diff vs fork at `1967a5627bc3`** (34 lines):

```diff
--- a/vllm/model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py
+++ b/vllm/model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py
@@ -106,20 +106,25 @@
         if quant_config.weight_quant_dtype == "mxfp4":
-            # This value is used specifically for gpt-oss,
-            # Need to revisit this for other models
-            self.gemm1_alpha = torch.tensor(
-                [1.702] * self.num_experts, dtype=torch.float32, device=self.device
-            )
-            self.gemm1_beta = torch.tensor(
-                [1.0] * self.num_experts, dtype=torch.float32, device=self.device
-            )
-            if self.gemm1_clamp_limit is None:
-                self.gemm1_clamp_limit = torch.tensor(
-                    [7.0] * self.num_experts,
+            # GPT-OSS supplies SwiGLU alpha/beta; DeepSeek-V4 does not.
+            self.gemm1_alpha = (
+                torch.tensor(
+                    [quant_config.gemm1_alpha] * self.num_experts,
                     dtype=torch.float32,
                     device=self.device,
                 )
+                if quant_config.gemm1_alpha is not None
+                else None
+            )
+            self.gemm1_beta = (
+                torch.tensor(
+                    [quant_config.gemm1_beta] * self.num_experts,
+                    dtype=torch.float32,
+                    device=self.device,
+                )
+                if quant_config.gemm1_beta is not None
+                else None
+            )

@@ -329,9 +334,6 @@
         elif self.weight_quant_dtype == "mxfp4":
             assert self.w1_scale is not None and self.w2_scale is not None
             assert w1.is_contiguous() and w2.is_contiguous()
-            assert self.gemm1_alpha is not None
-            assert self.gemm1_beta is not None
-            assert self.gemm1_clamp_limit is not None
             assert topk_ids.is_contiguous()
```

**What it does**: The fork hardcodes GPT-OSS SwiGLU constants (`alpha=1.702`,
`beta=1.0`, `clamp_limit=7.0`) with assertions that they are never None.
DeepSeek-V4's MXFP4 quant config does not supply these values, so without this patch
the constructor would set them to the hardcoded GPT-OSS values (wrong for DSv4) and
the `apply()` path would assert-crash. The overlay makes them `None`-able, driven
from `quant_config`, so DSv4 gets `None` (no scaling) and GPT-OSS models still get
their values if the quant config provides them.

This change is **not in upstream** at any point — upstream #42855 fixed a related DSv4
swiglu issue differently.

---

## Patch 2 — `mxfp4.py`: weight loading branch for CUTLASS backends

**Diff vs fork at `1967a5627bc3`** (77 lines, single hunk):

```diff
--- a/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py
+++ b/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py
@@ -1474,6 +1474,82 @@
             w2_bias,
         )

+    elif mxfp4_backend in (
+        Mxfp4MoeBackend.FLASHINFER_CUTLASS_MXFP4_BF16,
+        Mxfp4MoeBackend.FLASHINFER_CUTLASS_MXFP4_MXFP8,
+    ):
+        w13_weight = w13_weight.data
+        w2_weight = w2_weight.data
+        w13_weight_scale = w13_weight_scale.data
+        w2_weight_scale = w2_weight_scale.data
+        if w13_bias is not None:
+            w13_bias = w13_bias.data.to(torch.float32)
+        if w2_bias is not None:
+            w2_bias = w2_bias.data.to(torch.float32)
+
+        # Standard DeepSeek-V4 loading gives contiguous [w1/gate, w3/up].
+        # FlashInfer CUTLASS uses the opposite SwiGLU convention.
+        w1_weight = w13_weight[:, :intermediate_size, :]
+        w3_weight = w13_weight[:, intermediate_size:, :]
+        w13_weight = torch.cat([w3_weight, w1_weight], dim=1).contiguous()
+
+        w1_scale = w13_weight_scale[:, :intermediate_size, :]
+        w3_scale = w13_weight_scale[:, intermediate_size:, :]
+        w13_weight_scale = torch.cat([w3_scale, w1_scale], dim=1).contiguous()
+
+        if w13_bias is not None:
+            b1 = w13_bias[:, :intermediate_size]
+            b3 = w13_bias[:, intermediate_size:]
+            w13_bias = torch.cat([b3, b1], dim=1).contiguous()
+
+        if mxfp4_backend == Mxfp4MoeBackend.FLASHINFER_CUTLASS_MXFP4_MXFP8:
+            from flashinfer import block_scale_interleave
+
+            w13_shape = w13_weight_scale.shape
+            w13_weight_scale = (
+                block_scale_interleave(w13_weight_scale.view(torch.uint8))
+                .reshape(w13_shape)
+                .view(torch.float8_e4m3fn)
+            )
+
+            w2_shape = w2_weight_scale.shape
+            w2_weight_scale = (
+                block_scale_interleave(w2_weight_scale.view(torch.uint8))
+                .reshape(w2_shape)
+                .view(torch.float8_e4m3fn)
+            )
+
+            return (
+                w13_weight, w2_weight,
+                w13_weight_scale, w2_weight_scale,
+                w13_bias, w2_bias,
+            )
+
+        from flashinfer.fused_moe import (
+            interleave_moe_scales_for_sm90_mixed_gemm,
+            interleave_moe_weights_for_sm90_mixed_gemm,
+        )
+
+        return (
+            interleave_moe_weights_for_sm90_mixed_gemm(w13_weight.contiguous(), "fp4"),
+            interleave_moe_weights_for_sm90_mixed_gemm(w2_weight.contiguous(), "fp4"),
+            interleave_moe_scales_for_sm90_mixed_gemm(w13_weight_scale.to(torch.uint8)),
+            interleave_moe_scales_for_sm90_mixed_gemm(w2_weight_scale.to(torch.uint8)),
+            w13_bias,
+            w2_bias,
+        )
+
     elif mxfp4_backend == Mxfp4MoeBackend.AITER_MXFP4_BF16:
```

**What it does**: this is the weight preparation handler called at model-load time when
`moe_backend=flashinfer_cutlass`. Without it, the weight loading function falls through
to the AITER branch or raises. Two sub-paths:

**CUTLASS BF16 path** (`FLASHINFER_CUTLASS_MXFP4_BF16`):
- Swaps w1/w3 gate halves in both weights and scales (DSv4 loads `[gate, up]`;
  FlashInfer CUTLASS expects `[up, gate]` — opposite SwiGLU convention)
- Calls `interleave_moe_weights_for_sm90_mixed_gemm(w, "fp4")` and
  `interleave_moe_scales_for_sm90_mixed_gemm(s)` from `flashinfer.fused_moe` to
  reorder into the SM90 mixed-GEMM memory layout the CUTLASS kernel requires

**CUTLASS MXFP8 activation path** (`FLASHINFER_CUTLASS_MXFP4_MXFP8`):
- Same w1/w3 gate swap
- Then calls `flashinfer.block_scale_interleave` on both weight scales (viewed as
  uint8, re-cast to fp8_e4m3fn) to produce the interleaved MXFP8 scale layout the
  CUTLASS MXFP4×MXFP8 kernel expects

This is **not in upstream** as of the build date. Upstream main's `mxfp4.py` has a
completely different and more complex CUTLASS weight-loading path added later.

---

## Why `--kernel-config.moe_backend flashinfer_cutlass` needed this

The fork at `1967a5627bc3` already had all the CUTLASS enum values, routing, and
`FlashInferExperts` class — the infrastructure was there. What was missing was:

1. The weight loading branch in `mxfp4.py`: without it, model weights would load in
   the wrong memory layout and the CUTLASS kernel would produce incorrect results or
   crash.
2. The `gemm1_alpha`/`gemm1_beta` fix: without it, DSv4's MXFP4 path would use
   GPT-OSS's hardcoded SwiGLU scaling constants (1.702/1.0) instead of None, producing
   wrong activations.

---

## Reproduction

Extract the two files and use as patches on the cstechdev base or on any build from
`1967a5627bc3`:

```bash
id=$(docker create voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603)
SP=/opt/env/lib/python3.12/site-packages
docker cp $id:${SP}/vllm/model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py ./flashinfer_cutlass_moe.py
docker cp $id:${SP}/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py ./mxfp4.py
docker rm $id
```

```dockerfile
FROM cstechdev/dsv4-flash@sha256:27b80536a36212cef21664699aee35acbc14b37f147d41cd9b12361154f3c4db
ARG SP=/opt/env/lib/python3.12/site-packages
COPY flashinfer_cutlass_moe.py ${SP}/vllm/model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py
COPY mxfp4.py                  ${SP}/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py
```
