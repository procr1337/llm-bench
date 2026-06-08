#!/bin/bash
set -euo pipefail

TP="${TP:-2}"
if [[ "$TP" == "4" ]]; then
  DEVICES=0,1,2,3
  MAX_MODEL_LEN=1048576
elif [[ "$TP" == "2" ]]; then
  DEVICES=0,1
  MAX_MODEL_LEN=262144
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
  --ulimit memlock=-1 --ulimit stack=67108864

  # Can't afford more DDR5...
  -e MAX_JOBS=16
  -e TRANSFORMERS_OFFLINE=1
  -e HF_OFFLINE=1

  -e NCCL_P2P_LEVEL=SYS
  -e NCCL_PROTO=LL,LL128,Simple
  -e NCCL_IB_DISABLE=1

  # necessary to utilize KV cache effectively:
  # https://github.com/vllm-project/vllm/pull/43447
  -e VLLM_PREFIX_CACHE_RETENTION_INTERVAL=4096
)

VLLM_COMMON=(
  deepseek-ai/DeepSeek-V4-Flash
  --max-model-len "$MAX_MODEL_LEN"
  --served-model-name deepseek-v4-flash
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
  --kv-cache-dtype fp8
  --tensor-parallel-size "$TP"
  --enable-prefix-caching
  --tokenizer-mode deepseek_v4
  --tool-call-parser deepseek_v4
  --enable-auto-tool-choice
  --reasoning-parser deepseek_v4
  --enable-prompt-tokens-details
  --default-chat-template-kwargs '{"thinking": true, "reasoning_effort": "high"}'
  #--kv-offloading-size 40
)

voipmonitor1() {
  NAME=voipmonitor1
  IMAGE=voipmonitor/dsv4-flash:lucifer-mxfp4-cutlass-20260603

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    "$IMAGE"
    serve "${VLLM_COMMON[@]}"
    --gpu-memory-utilization 0.95
    --block-size 256
    --load-format auto
    --max-num-seqs 64
    --max-cudagraph-capture-size 192
    --async-scheduling
    --no-scheduler-reserve-full-isl
    --max-num-batched-tokens 8192
    --attention-backend SPARSE_MLA_SM120
    --enable-chunked-prefill
    --enable-flashinfer-autotune
    --kernel-config.moe_backend flashinfer_cutlass
    --speculative-config.method mtp
    --speculative-config.num_speculative_tokens 2
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

voipmonitor2() {
  NAME=voipmonitor2
  IMAGE=voipmonitor/vllm:abyssal-abjuration-611a842-a16-dcp@sha256:8601786e427faa72368e3d57e04d30a80a33bfbf5372352bdfb4358667827f36

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    -e CUTE_DSL_ARCH=sm_120a
    -e VLLM_USE_AOT_COMPILE=1
    -e VLLM_USE_BREAKABLE_CUDAGRAPH=0
    -e VLLM_USE_MEGA_AOT_ARTIFACT=1
    -e VLLM_MEMORY_PROFILE_INCLUDE_ATTN=1
    -e B12X_MHC_MAX_TOKENS=16384
    -e VLLM_USE_FLASHINFER_SAMPLER=1
    -e VLLM_USE_B12X_WO_PROJECTION=1
    -e VLLM_USE_B12X_MHC=1
    -e VLLM_USE_B12X_FP8_GEMM=1
    -e VLLM_USE_B12X_MOE=1
    -e VLLM_USE_B12X_SPARSE_INDEXER=1
    -e VLLM_USE_V2_MODEL_RUNNER=1
    -e VLLM_PCIE_ALLREDUCE_BACKEND=b12x
    -e VLLM_ENABLE_PCIE_ALLREDUCE=1
    -e B12X_MLA_SM120_UNIFIED=1
    -e USES_B12X=True
    -e B12X_DENSE_SPLITK_TURBO=1
    -e B12X_W4A16_TC_DECODE=1
    -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

    --entrypoint /bin/sh
    "$IMAGE"
    -c 'unset NCCL_GRAPH_FILE NCCL_GRAPH_DUMP_FILE VLLM_B12X_MLA_EXTEND_MAX_CHUNKS && exec vllm serve "$@"' --
    "${VLLM_COMMON[@]}"

    --gpu-memory-utilization 0.88

    --attention-backend B12X_MLA_SPARSE
    --b12x-virtual-tp-moe-intermediate-alignment 32
    --moe-backend b12x
    --linear-backend b12x

    --block-size 256
    # --load-format instanttensor fails with `ModuleNotFoundError: No module named 'instanttensor'`
    --load-format auto
    --max-num-seqs 16
    --max-num-batched-tokens 2048
    --max-cudagraph-capture-size 192
    --async-scheduling
    --no-scheduler-reserve-full-isl
    --enable-chunked-prefill
    #--decode-context-parallel-size 2

    # This is probably pointless: `Skipping FlashInfer autotune because no FlashInfer compute kernels are active.`
    --enable-flashinfer-autotune

    --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
    --speculative-config '{"method":"mtp","num_speculative_tokens":2,"draft_sample_method":"greedy","moe_backend":"b12x"}'
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

lavd1() {
  NAME=lavd1
  IMAGE='lavd/vllm:b12x-abyssal-abjuration-6-5-13.2-2@sha256:d8a24af3e3010823399aa76d13fac7f197b265abe07f97d9e312e7d535ad7879'

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    -e CUTE_DSL_ARCH=sm_120a
    -e VLLM_USE_AOT_COMPILE=1
    -e VLLM_USE_BREAKABLE_CUDAGRAPH=0
    -e VLLM_USE_MEGA_AOT_ARTIFACT=1
    -e VLLM_MEMORY_PROFILE_INCLUDE_ATTN=1
    -e B12X_MHC_MAX_TOKENS=16384
    -e VLLM_USE_FLASHINFER_SAMPLER=1
    -e VLLM_USE_B12X_WO_PROJECTION=1
    -e VLLM_USE_B12X_MHC=1
    -e VLLM_USE_B12X_FP8_GEMM=1
    -e VLLM_USE_B12X_MOE=1
    -e VLLM_USE_B12X_SPARSE_INDEXER=1
    -e VLLM_USE_V2_MODEL_RUNNER=1
    -e VLLM_PCIE_ALLREDUCE_BACKEND=b12x
    -e VLLM_ENABLE_PCIE_ALLREDUCE=1
    -e B12X_MLA_SM120_UNIFIED=1
    -e USES_B12X=True
    -e B12X_DENSE_SPLITK_TURBO=1
    -e B12X_W4A16_TC_DECODE=1
    -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

    --entrypoint /bin/sh
    "$IMAGE"
    -c 'unset NCCL_GRAPH_FILE NCCL_GRAPH_DUMP_FILE VLLM_B12X_MLA_EXTEND_MAX_CHUNKS && exec vllm serve "$@"' --
    "${VLLM_COMMON[@]}"

    --gpu-memory-utilization 0.88

    --attention-backend B12X_MLA_SPARSE
    --b12x-virtual-tp-moe-intermediate-alignment 32
    --moe-backend b12x
    --linear-backend b12x

    --block-size 256
    --load-format instanttensor
    --max-num-seqs 16
    --max-num-batched-tokens 2048
    --max-cudagraph-capture-size 192
    --async-scheduling
    --no-scheduler-reserve-full-isl
    --enable-chunked-prefill

    # This is probably pointless: `Skipping FlashInfer autotune because no FlashInfer compute kernels are active.`
    --enable-flashinfer-autotune

    --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
    --speculative-config '{"method":"mtp","num_speculative_tokens":2,"draft_sample_method":"greedy","moe_backend":"b12x"}'
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}


cstechdev1() {
  NAME=cstechdev1
  IMAGE='cstechdev/dsv4-flash@sha256:27b80536a36212cef21664699aee35acbc14b37f147d41cd9b12361154f3c4db'

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    "$IMAGE"
    serve "${VLLM_COMMON[@]}"
    --gpu-memory-utilization 0.95
    --block-size 256
    --max-num-seqs 8
    --disable-custom-all-reduce
    --reasoning-config.reasoning_start_str ' thinking'
    --reasoning-config.reasoning_end_str ' response'
    --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
    --enable-flashinfer-autotune
    --speculative-config.method mtp
    --speculative-config.num_speculative_tokens 2
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

lucifer1() {
  NAME=lucifer1
  # "Reverse engineered" from cstechdev/dsv4-flash - see lucifer-image-analysis/cstechdev.md
  # built from llm-bench@91d75108209e295fdce5f495f46aca62ddcc1a69
  IMAGE=local/vllm:lucifer-91d7510

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    "$IMAGE"
    serve "${VLLM_COMMON[@]}"
    --gpu-memory-utilization 0.95
    --block-size 256
    --max-num-seqs 8
    --disable-custom-all-reduce
    --reasoning-config.reasoning_start_str ' thinking'
    --reasoning-config.reasoning_end_str ' response'
    --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
    --enable-flashinfer-autotune
    --speculative-config.method mtp
    --speculative-config.num_speculative_tokens 2
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

lucifer1_cutlass() {
  NAME=lucifer1_cutlass
  IMAGE=local/vllm:lucifer-91d7510

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    "$IMAGE"
    serve "${VLLM_COMMON[@]}"
    --gpu-memory-utilization 0.95
    --block-size 256
    --load-format auto
    --max-num-seqs 64
    --max-cudagraph-capture-size 192
    --async-scheduling
    --no-scheduler-reserve-full-isl
    --max-num-batched-tokens 8192
    --attention-backend SPARSE_MLA_SM120
    --enable-chunked-prefill
    --enable-flashinfer-autotune
    --kernel-config.moe_backend flashinfer_cutlass
    --speculative-config.method mtp
    --speculative-config.num_speculative_tokens 2
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

lucifer2() {
  NAME=lucifer2
  IMAGE=hg436/vllm-public:lucifer-9d9a0a0

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    "$IMAGE"
    serve "${VLLM_COMMON[@]}"
    --gpu-memory-utilization 0.95
    --block-size 256
    --load-format instanttensor
    --max-num-seqs 8
    --disable-custom-all-reduce
    --reasoning-config.reasoning_start_str ' thinking'
    --reasoning-config.reasoning_end_str ' response'
    --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
    --enable-flashinfer-autotune
    --speculative-config.method mtp
    --speculative-config.num_speculative_tokens 2
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

lucifer2_cutlass() {
  NAME=lucifer2_cutlass
  IMAGE=hg436/vllm-public:lucifer-9d9a0a0

  OPTS=(
    "${DOCKER_COMMON[@]}"
    -v /data/cache/$NAME:/cache
    -v /data/hf:/root/.cache/huggingface:ro

    "$IMAGE"
    serve "${VLLM_COMMON[@]}"
    --gpu-memory-utilization 0.95
    --block-size 256
    --load-format instanttensor
    --max-num-seqs 64
    --max-cudagraph-capture-size 192
    --async-scheduling
    --no-scheduler-reserve-full-isl
    --max-num-batched-tokens 8192
    --enable-chunked-prefill
    --enable-flashinfer-autotune
    --kernel-config.moe_backend flashinfer_cutlass
    --speculative-config.method mtp
    --speculative-config.num_speculative_tokens 2
  )

  docker rm -f "$NAME"
  docker run --name "$NAME" -d "${OPTS[@]}"
}

docker stop -t1 \
  voipmonitor1 \
  voipmonitor2 \
  lavd1 \
  cstechdev1 \
  lucifer1 \
  lucifer1_cutlass \
  lucifer2 \
  lucifer2_cutlass \
  || true

"$1"
