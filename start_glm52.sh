#!/bin/bash
set -euo pipefail

TP="${TP:-8}"
if [[ "$TP" == "6" ]]; then
  DEVICES=0,1,2,3,4,5
  MAX_MODEL_LEN=128000
elif [[ "$TP" == "8" ]]; then
  DEVICES=0,1,2,3,4,5,6,7
  MAX_MODEL_LEN=1000000
else
  echo "Unsupported TP: $TP"
  exit 1
fi

echo "Using TP $TP"


DOCKER_COMMON=(
  --gpus '"device='"$DEVICES"'"'
  --ipc host
  --shm-size 8g
  --network llm --ip 172.23.0.10
  --memory 160g
  --ulimit memlock=-1 --ulimit stack=67108864 --ulimit nofile=1048576

  -e MAX_JOBS=32
  -e TRANSFORMERS_OFFLINE=1
  -e HF_HUB_OFFLINE=1

  -e CUDA_VISIBLE_DEVICES="$DEVICES"

  -e NCCL_P2P_LEVEL=SYS
  -e NCCL_PROTO=LL,LL128,Simple
  -e NCCL_IB_DISABLE=1
  -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

)

# graph cap = max num seq * (1 + MTP); here 16 * (1 + 1) = 32 for MTP1
VLLM_COMMON=(
  lukealonso/GLM-5.2-NVFP4
  --max-model-len "$MAX_MODEL_LEN"
  --served-model-name glm-5.2
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
  --kv-cache-dtype fp8
  --tensor-parallel-size "$TP"
  --enable-prefix-caching
  --tool-call-parser glm47
  --enable-auto-tool-choice
  --reasoning-parser glm45
  --default-chat-template-kwargs '{"reasoning_effort":"high"}'
  --enable-prompt-tokens-details
  --hf-overrides '{"use_index_cache":true,"index_topk_pattern":"FFFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSSFSSS"}'
  --quantization modelopt_fp4
)

glm52_voipmonitor1() {
  NAME=glm52_voipmonitor1
  IMAGE='voipmonitor/vllm:eldritch-enlightenment-v8722ac7-b12x8ce61f9-cu132-20260629@sha256:534ad1a3f7e5877ee131b0ad886f6d372fd40b787a2bd2f3e98a40573d51ddcf'

  # Container entrypoint: clear stale NCCL graph vars, keep the TP-padding
  # alignment fix (no-op on this v11 image, which already ships alignment==1),
  # then exec the real server. Serve args are passed after the `--`.
  SH_ENTRYPOINT='unset NCCL_GRAPH_FILE NCCL_GRAPH_DUMP_FILE VLLM_B12X_MLA_EXTEND_MAX_CHUNKS && exec vllm serve "$@"'

  MTP=3
  NUM_SEQS=32
  DCP=2

  OPTS=(
    "${DOCKER_COMMON[@]}"
    --entrypoint /bin/sh
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    -e CUDA_DEVICE_MAX_CONNECTIONS=32
    -e OMP_NUM_THREADS=16
    -e CUTE_DSL_ARCH=sm_120a
    -e SAFETENSORS_FAST_GPU=1

    -e VLLM_USE_AOT_COMPILE=1
    -e VLLM_USE_BREAKABLE_CUDAGRAPH=0
    -e VLLM_USE_MEGA_AOT_ARTIFACT=1
    -e VLLM_USE_FLASHINFER_SAMPLER=1
    -e VLLM_USE_B12X_FP8_GEMM=1
    -e VLLM_USE_B12X_MOE=1
    -e VLLM_USE_B12X_SPARSE_INDEXER=1
    -e VLLM_USE_V2_MODEL_RUNNER=1
    -e VLLM_ENABLE_PCIE_ALLREDUCE=1
    -e VLLM_PCIE_ALLREDUCE_BACKEND=b12x
    -e VLLM_PCIE_ONESHOT_ALLREDUCE_MAX_SIZE=64KB
    -e B12X_DENSE_SPLITK_TURBO=1
    -e B12X_W4A16_TC_DECODE=1
    -e B12X_MOE_FORCE_A16=1
    -e VLLM_CACHE_DIR=/cache/jit/vllm
    -e TRITON_CACHE_DIR=/cache/jit/triton
    -e TORCH_EXTENSIONS_DIR=/cache/jit/torch_extensions
    -e TORCHINDUCTOR_CACHE_DIR=/cache/jit/torchinductor
    -e FLASHINFER_WORKSPACE_BASE=/cache/jit/flashinfer
    -e XDG_CACHE_HOME=/cache/jit

    "$IMAGE"
    -c "$SH_ENTRYPOINT"
    --
    "${VLLM_COMMON[@]}"
    --pipeline-parallel-size 1
    --decode-context-parallel-size $DCP
    --dcp-comm-backend ag_rs
    --dcp-kv-cache-interleave-size 1
    --enable-chunked-prefill
    --load-format fastsafetensors
    --async-scheduling
    -cc.pass_config.fuse_allreduce_rms=True
    --gpu-memory-utilization 0.93
    --max-num-batched-tokens 8192
    --max-num-seqs $NUM_SEQS
    --max-cudagraph-capture-size $(($NUM_SEQS*(1 + $MTP)))
    --attention-backend B12X_MLA_SPARSE
    --moe-backend b12x
    --speculative-config '{"method":"mtp","num_speculative_tokens":'$MTP',"moe_backend":"b12x","draft_sample_method":"probabilistic"}'
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

docker stop -t1 \
  glm52_voipmonitor1 \
  || true

"$1"
