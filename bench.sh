#!/bin/bash
set -euo pipefail
name="$1"
cd "$(dirname "$0")"
mkdir -p results/"$name"
OPTS=(
  --network llm
  -v "$(pwd)/results/$name:/out"
  llm-inference-bench
  --host 172.23.0.10
  --port 8000
  --no-hw-monitor
  --concurrency 1,4,16
  --contexts 0,32768,131072
  --output /out/benchmark_results.json
)
docker run -ti --rm "${OPTS[@]}"
