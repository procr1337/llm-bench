# cstechdev/dsv4-flash — Image Analysis v2

Image: `cstechdev/dsv4-flash@sha256:27b80536a36212cef21664699aee35acbc14b37f147d41cd9b12361154f3c4db`

Sources: `/opt/dsv4/provenance.json` (schema v1, 92 kB), `docker history --no-trunc`,
and live container inspection.

---

## Build System

The image is **not** built by compiling sources inside Docker. The pipeline is:

1. A private **build harness** (git commit `e78700e9b1c1fad665613147cbd97882234a1e00`,
   dirty) runs on the host. It builds all wheels outside Docker using
   `python -m pip wheel --no-deps --no-build-isolation` and records every artifact
   SHA-256 into `provenance.json`.
2. Wheels are staged in a local `wheelhouse/` directory (182 resolved PyPI wheels +
   2 trusted-host local builds: `flashinfer-python` and `vllm`).
3. The Dockerfile (`COPY wheelhouse/ /wheelhouse/`) installs them offline:
   `pip --no-index --no-deps --require-hashes -r /tmp/wheel-requirements.txt`,
   then force-reinstalls `nvidia-cutlass-dsl-libs-cu13` last to resolve the CUTLASS
   base/cu13 overlay conflict.
4. After the main wheel layer, two patch layers are applied as file copies directly
   into `site-packages` (see §6 — Patches).

**Base image**: `mambaorg/micromamba:2.3.3` (Debian 13 trixie).

**Conda environment**: created with `micromamba create -y -p /opt/env -f /tmp/conda-explicit.txt`.
211 conda-forge packages; pixi lock SHA-256 `66cf856985a5f40cd64adfa1db4c281898012d5bed21bf3db0246f0f40fd6a46`.
Python and the full CUDA toolkit come from conda — not apt.

**Build timeline** (from `docker history`):
- T−10 days — main wheelhouse install + entrypoint (base image layer, ~9.3 GB)
- T−8 days  — SWA/Eagle KV-cache patch (PR #42784)
- T−5 days  — DSv4 parser patch (updated `deepseekv32_tool_parser.py` + `reasoning/__init__.py` cleanup + `deepseekv4_tool_parser.py` copied verbatim from fork, plus NCCL env vars)

---

## Environment

| Property | Value |
|---|---|
| OS | Debian GNU/Linux 13 (trixie), `DEBIAN_VERSION_FULL=13.1` |
| Base image | `mambaorg/micromamba:2.3.3` |
| Python | `3.12.13` — conda-forge, installed into `/opt/env` |
| Python env | `/opt/env` (micromamba-managed conda env, prefix install) |
| CUDA toolkit | `13.2.78` (nvcc `cuda_13.2.r13.2/compiler.37668154_0`) — conda-forge |
| CUDA host compiler | `x86_64-conda-linux-gnu-g++` from GCC 13.4.0 (conda-forge) |
| CUDA arch list | `12.0;12.1` (SM120 / RTX Pro 6000 + SM121 / DGX Spark) |
| `CONDA_OVERRIDE_CUDA` | `""` (empty — not set to a version string) |
| `FLASHINFER_DISABLE_VERSION_CHECK` | `1` (permanent, in image ENV) |

---

## Component Versions

| Package | Version | Source | SHA-256 (first 20) |
|---|---|---|---|
| vllm | `0.21.1rc1.dev339+g1967a5627bc3` | local build | `7bf39ee8cecd6480488c` |
| torch | `2.11.0+cu130` | resolved-pypi-wheel | `96911323dcfcd42028c7` |
| torchaudio | `2.11.0+cu130` | resolved-pypi-wheel | `3fba988f4301fe13547f` |
| torchvision | `0.26.0+cu130` | resolved-pypi-wheel | `0f030a9bd8ada1a31b71` |
| transformers | `5.9.0` | resolved-pypi-wheel | `1d19509bcff7028ebc6b` |
| flashinfer-python | `0.6.12` | local build | `9d7a075ac46500342c9f` |
| flashinfer-cubin | `0.6.11.post3` | resolved-pypi-wheel | `982901b391f12bb8da36` |
| triton | `3.6.0` | resolved-pypi-wheel | `6f5928e6d44c34a97bbe` |
| tilelang | `0.1.9` | resolved-pypi-wheel | `4bbccfe9035aed775ffa` |
| tokenspeed-mla | `0.1.2` | resolved-pypi-wheel | `c9466a351fe039792e56` |
| tokenspeed-triton | `3.7.10.post20260505` | resolved-pypi-wheel | `19618c7db01a9bd33885` |
| nvidia-nccl-cu13 | `2.28.9` | resolved-pypi-wheel | `e4553a30f34195f3fa1d` |
| nvidia-cublas | `13.1.0.3` | resolved-pypi-wheel | `ee8722c1f0145ab246bc` |
| nvidia-cutlass-dsl | `4.5.0` | resolved-pypi-wheel | `3b051fe02ca69422ab84` |
| nvidia-cutlass-dsl-libs-base | `4.5.0` | resolved-pypi-wheel | `bd18322d9247f8c033a1` |
| nvidia-cutlass-dsl-libs-cu13 | `4.5.0` | resolved-pypi-wheel | `fc0b5a81ff591db72489` |
| nvidia-nvshmem-cu13 | `3.4.5` | resolved-pypi-wheel | `290f0a2ee94c9f3687a0` |
| nvidia-cuda-nvcc | `13.2.78` | resolved-pypi-wheel | `c3bd144dd9b6b25e0625` |
| nvidia-cudnn-cu13 | `9.19.0.56` | resolved-pypi-wheel | `d20e1734305e9d688889` |
| cuda-bindings | `13.3.0` | resolved-pypi-wheel | `a99c3b8d584f266c616b` |
| cuda-core | `1.0.1` | resolved-pypi-wheel | `be7b65311bf789640000` |
| cuda-tile | `1.3.0` | resolved-pypi-wheel | `e4865acbff1172aaee30` |
| mooncake-transfer-engine | `0.3.8.post1` | resolved-pypi-wheel | `87057f13c4e5e07d78dc` |
| deep_gemm (vendored) | `v2.5.0` / commit `1f2f161` | git submodule in vllm | — |

**Note on PyTorch index**: `cu130` is the only CUDA-13.x flavor published by PyTorch.
It runs correctly against CUDA 13.2 at runtime; no `cu132` wheels exist.

---

## Git Commits (exact, from provenance.json)

| Repo | Commit | Dirty |
|---|---|---|
| `vllm-project/vllm` (force-pushed PR tip) | `1967a5627bc3710b680bbec24ecb99aaddedf22b` | false |
| `deepseek-ai/flashinfer` (PR #3395 pre-force-push) | `9ad3567d85e46abcda8ba5140a5e6125b18c91f0` | false |
| `deepseek-ai/DeepGEMM`, PR #324 mid-development | `1f2f161dba747b7c12671d017f7c88e1249c3d3e` | true |
| build harness (private) | `e78700e9b1c1fad665613147cbd97882234a1e00` | true |

`provenance.json` was written at `2026-05-27T22:33:24Z`.

---

## vLLM — diffs vs upstream commit `1967a5627bc3`

Commit `1967a5627bc3` ("fix(sm120): pass scratch for small prefill chunks") is from
a force-pushed upstream PR on `vllm-project/vllm`. It is not on `main` but remains
fetchable by SHA.

### Patch 1 — PR #42784: SWA cache block mask (Eagle/MTP)

Applied as a file-copy layer at T−8 days from a `patches/vllm-42784-swa-eagle/`
directory.

**Files**: `vllm/v1/core/kv_cache_coordinator.py` and
`vllm/v1/core/single_type_kv_cache_manager.py`.

**Upstream commit**: `b90c4950db520998a97809e1268fc491badd88bc` — not on upstream main
at build time; fetchable by SHA. The applied files add a
`# Backported from vllm-project/vllm#42784.` attribution comment.

**Effect**: Disables the `SlidingWindowManager` block mask inside Eagle/MTP attention
groups (`eagle_extra_cache_blocks = 1`). Without this, prefix-cache hit rate drops
to 0% when using speculative decoding with Eagle/MTP.

### Patch 2 — PR #42879: Incremental DeepSeek DSML tool-call streaming

Applied as a file-copy layer at T−5 days from a `patches/vllm-dsv4-parsers-upstream/`
directory. Two files updated, one copied verbatim (no diff), one deleted.

**`vllm/tool_parsers/deepseekv32_tool_parser.py`** — upstream PR #42879
("Stream DeepSeek DSML tool-call argument deltas incrementally"), merged commit
`b372ad3e9018f032478619adbc7f7fdcc9318212` on `vllm-project/vllm` main. Replaces
the buffer-until-complete-`<invoke>` approach with true streaming: per-parameter
delta emission, new state machine (`_buffer`, `_in_tool_calls`, `_active_tool_*`),
`_process_streaming_buffer()` incremental parser.

**`vllm/tool_parsers/deepseekv4_tool_parser.py`** — present in the fork at `1967a5627bc3`
and copied verbatim by the patch layer (no changes). A thin subclass of
`DeepSeekV32ToolParser`:

```python
class DeepSeekV4ToolParser(DeepSeekV32ToolParser):
    tool_call_start_token: str = "<｜DSML｜tool_calls>"
    tool_call_end_token: str = "</｜DSML｜tool_calls>"
```

V4 uses `<｜DSML｜tool_calls>` / `</｜DSML｜tool_calls>` as the outer fence,
whereas V3.2 uses `<｜DSML｜function_calls>` / `</｜DSML｜function_calls>`.
The inner `<｜DSML｜invoke>` / `<｜DSML｜parameter>` grammar is identical.
`get_structural_tag()` dispatches via `get_model_structural_tag(model="deepseek_v4")`.

**`vllm/reasoning/__init__.py`** — removes the `deepseek_v4` → dedicated
`DeepSeekV4ReasoningParser` registration; `deepseek_v4` now falls back to the
standard `DeepSeekV3ReasoningParser`. Comment explains that PR #40806 moved the
DSML token-leakage fix into the tool parser, making a bespoke V4 reasoning parser
unnecessary.

**`vllm/reasoning/deepseek_v4_reasoning_parser.py`** — deleted (`rm -f`) by the
same layer.

---

## FlashInfer — diffs vs `v0.6.12`

Exact commit: **`9ad3567d85e46abcda8ba5140a5e6125b18c91f0`** — "perf(sparse-mla):
inline decode smem accessors", 2026-05-27. This is the pre-force-push tip of
FlashInfer PR #3395. After this commit the PR was rebased and gained GLM-NSA
model-type dispatch, `kv_scale_format`, `max_num_tokens`, and DSv3.2 autotuning —
none of which are in the image.

The commit is on a branch that was later overwritten; it is reachable via a
partial-clone (`--filter=blob:none`) which fetches dangling objects from GitHub.
The original pre-force-push branch history:

```
bff85f34  base (merged PR #3360)
3609a6cc  feat: add SM120 sparse MLA kernels           2026-05-23 08:39
171c5138  dedupe MG prefill kernels                    2026-05-23 09:04
c9ce4443  swa_indices: add SWA paged slot-id compute   2026-05-23 15:45
377d0f30  optimize sm120 dual-cache prefill             2026-05-26 05:04
e6f4a7ba  test: enable sm12x test coverage             2026-05-26 05:04
a54ce83a  fix: address sm120 review issues             2026-05-26 07:01
6e71070d  fix: skip empty prefill topk reads           2026-05-26 17:06
9b370297  fix: accept singleton prefill indices         2026-05-26 18:07
2caff230  fix: share sm120 decode scratch               2026-05-27 06:18
9ad3567d  perf: inline decode smem accessors  ← IMAGE  2026-05-27 06:27
```

---

## DeepGEMM — vendored at `vllm/third_party/deep_gemm/`

**Exact commit: `1f2f161dba747b7c12671d017f7c88e1249c3d3e`** of PR
[deepseek-ai/DeepGEMM#324](https://github.com/deepseek-ai/DeepGEMM/pull/324) —
"SM120: remove sm120-specific test files and fix SM90 test regression". Marked
`dirty=true` in provenance (build-system sanitization applied: CMake
`TORCH_CUDA_ARCH_LIST` extended to include `12.1`).

**Additional modification**: `vllm/third_party/deep_gemm/__init__.py` imports
`sm120_fp8_gemm_bench` which is **not present** at commit `1f2f161`. This was
added by the build harness or a post-install patch layer.

---

## Additional files not at `1967a5627bc3`

Six `triton_kernels` files exist in the image's vLLM `site-packages` that are
**not present** when building with the default `TRITON_KERNELS_TAG=v3.5.1` from
`cmake/external_projects/triton_kernels.cmake`. Their timestamps match the base
wheel install layer (T−10 days), confirming they were included at wheel build time.

vLLM's CMake fetches `triton_kernels` from `triton-lang/triton` (the Triton
monorepo, **not** the `triton` pip package). These 6 files were introduced in
Triton commit `c69c3a954` ("Reland refactor of tensor/layout/distributed") and
first appear in tag `v3.7.0`. The build harness either overrode
`DEFAULT_TRITON_KERNELS_TAG` or set `TRITON_KERNELS_SRC_DIR` to a local Triton
checkout at `v3.7.0` or newer.

- `vllm/third_party/triton_kernels/distributed.py` (435 lines)
- `vllm/third_party/triton_kernels/reduce.py` (290 lines)
- `vllm/third_party/triton_kernels/roofline.py` (301 lines)
- `vllm/third_party/triton_kernels/tensor_details/bitmatrix.py`
- `vllm/third_party/triton_kernels/tensor_details/bitmatrix_details/sum_bitmatrix_rows.py`
- `vllm/third_party/triton_kernels/tensor_details/ragged_tensor.py`

These are distributed MoE triton kernels (`ExptAssignment`, symmetric memory
all-reduce, bitmatrix routing). Their absence from our lucifer build has no
known runtime impact for DSv4 inference — vLLM does not import them on the
standard TP=2 code path.

---

## Runtime Configuration

### Entrypoint (`/usr/local/bin/dsv4-vllm-entrypoint`)

```bash
#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/env/bin:/opt/env/nvvm/bin:/opt/env/targets/x86_64-linux/nvvm/bin:${PATH:-}"
export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
export CUDA_HOME="${CUDA_HOME:-/opt/env/targets/x86_64-linux}"
export CUDA_PATH="${CUDA_PATH:-${CUDA_HOME}}"
export CUDAToolkit_ROOT="${CUDAToolkit_ROOT:-${CUDA_HOME}}"
export LD_LIBRARY_PATH="/opt/env/lib:/opt/env/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"

if [[ -x /opt/env/bin/nvcc ]]; then
  export DG_JIT_NVCC_COMPILER="${DG_JIT_NVCC_COMPILER:-/opt/env/bin/nvcc}"
  export FLASHINFER_NVCC="${FLASHINFER_NVCC:-/opt/env/bin/nvcc}"
  export PYTORCH_NVCC="${PYTORCH_NVCC:-/opt/env/bin/nvcc}"
fi
export CUDAHOSTCXX="${CUDAHOSTCXX:-/opt/env/bin/x86_64-conda-linux-gnu-g++}"
export NVCC_PREPEND_FLAGS="${NVCC_PREPEND_FLAGS:--ccbin ${CUDAHOSTCXX} -I${CUDA_HOME}/include/cccl -I${CUDA_HOME}/include}"

export FLASHINFER_DISABLE_VERSION_CHECK="${FLASHINFER_DISABLE_VERSION_CHECK:-1}"
export FLASHINFER_WORKSPACE_BASE="${FLASHINFER_WORKSPACE_BASE:-/cache/flashinfer}"
export VLLM_CACHE_ROOT="${VLLM_CACHE_ROOT:-/cache/vllm}"
export DG_JIT_CACHE_DIR="${DG_JIT_CACHE_DIR:-/cache/deep_gemm_jit}"
export TILELANG_CACHE_DIR="${TILELANG_CACHE_DIR:-/cache/tilelang}"
export TILELANG_TMP_DIR="${TILELANG_TMP_DIR:-${TILELANG_CACHE_DIR}/tmp}"
export TRITON_CACHE_DIR="${TRITON_CACHE_DIR:-/cache/triton}"
export TORCHINDUCTOR_CACHE_DIR="${TORCHINDUCTOR_CACHE_DIR:-/cache/torchinductor}"
export TORCH_EXTENSIONS_DIR="${TORCH_EXTENSIONS_DIR:-/cache/torch_extensions}"

if [[ "${DSV4_VLLM_CREATE_CACHE_DIRS:-1}" != "0" ]]; then
  mkdir -p "${FLASHINFER_WORKSPACE_BASE}" "${VLLM_CACHE_ROOT}" "${DG_JIT_CACHE_DIR}" "${TILELANG_CACHE_DIR}" "${TILELANG_TMP_DIR}" \
    "${TRITON_CACHE_DIR}" "${TORCHINDUCTOR_CACHE_DIR}" "${TORCH_EXTENSIONS_DIR}"
fi

exec vllm "$@"
```

### NCCL tuning (baked into image ENV)

Applied in the T−5 days layer alongside the parser patch:

```
NCCL_IB_DISABLE=1
NCCL_SOCKET_IFNAME=lo
NCCL_PROTO=LL,LL128,Simple
NCCL_ALLOC_P2P_NET_LL_BUFFERS=1
NCCL_P2P_LEVEL=SYS
NCCL_NET_GDR_LEVEL=SYS
NCCL_MIN_NCHANNELS=8
```

Also baked: `HF_HUB_OFFLINE=1`, `OMP_NUM_THREADS=8`,
`VLLM_WORKER_MULTIPROC_METHOD=spawn`, `VLLM_ALLREDUCE_USE_SYMM_MEM=0`.

### CUTLASS DSL cu13 overlay

`nvidia-cutlass-dsl-libs-base` and `nvidia-cutlass-dsl-libs-cu13` both version
`4.5.0` overlap files. The install sequence force-reinstalls `libs-cu13` last and
runs `check-cutedsl-overlay.py` to validate the cu13 overlay is in place
(script deleted in the same `RUN` step, not present in the final image).
`pip check` is intentionally skipped (FlashInfer local build can diverge from
vLLM's upstream metadata pin).

---

## Pixi / Conda Environment Summary

| Property | Value |
|---|---|
| pixi environment name | `vllm` |
| conda package count | 211 |
| pypi public wheel count | 182 |
| pypi local (replaced) | `flashinfer-python`, `vllm` |
| pixi lock SHA-256 | `66cf856985a5f40cd64adfa1db4c281898012d5bed21bf3db0246f0f40fd6a46` |
| wheelhouse SHA-256 | `29b2f4e18b29b691ee413d367572d09c263d7127c375f91ee34bdf1623700119` |

Key conda-forge packages (from `micromamba list --prefix /opt/env`):

| Package | Version | Channel |
|---|---|---|
| python | 3.12.13 | conda-forge |
| gcc / gxx | 13.4.0 | conda-forge |
| libgcc-ng / libstdcxx-ng | 15.2.0 | conda-forge |
| cmake | 4.3.2 | conda-forge |
| cuda-nvcc | 13.2.78 | conda-forge |
| cuda-cudart | 13.2.75 | conda-forge |
| sysroot_linux-64 | 2.28 | conda-forge |
| binutils | 2.45.1 | conda-forge |

---

## Reproduction Notes

- **vLLM repo**: `https://github.com/vllm-project/vllm.git`, fetch `1967a5627bc3` by SHA
- **vLLM requirements**: `requirements/build/cuda.txt` (fork restructured build deps into per-device subdirs)
- **PyTorch index**: `https://download.pytorch.org/whl/cu130` (`cu130` is the only CUDA-13.x flavor; works at runtime on CUDA 13.2)
- **Cherry-pick #42879** (`b372ad3e9018f032478619adbc7f7fdcc9318212`): fetch by SHA, cherry-pick
- **Cherry-pick #42784** (`b90c4950db520998a97809e1268fc491badd88bc`): fetch by SHA, cherry-pick
- **FlashInfer commit `9ad3567d`**: dangling ref; fetch by SHA from `flashinfer-ai/flashinfer`
- **DeepGEMM commit `1f2f161`**: fetch by SHA from `deepseek-ai/DeepGEMM`
- **CUDA arch list**: set `TORCH_CUDA_ARCH_LIST=12.0;12.1` (overridable via `DSV4_VLLM_CUDA_ARCH_LIST`)
- **Install method**: `pip --no-index --no-deps --require-hashes`; no compilation inside Docker
