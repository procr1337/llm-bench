#!/bin/bash
set -euo pipefail
name="$1"
cd "$(dirname "$0")"
mkdir -p results/"$name"
TP=${TP:-2}
echo "TP: $TP"
if [[ "$TP" == "4" ]]; then
  CONCURRENCY="${2:-1,4,16}"
elif [[ "$TP" == "2" ]]; then
  CONCURRENCY="${2:-1,4,8}"
else
  echo "Unsupported TP value: $TP"
  exit 1
fi

OPTS=(
  --network llm
  -v "$(pwd)/results/$name:/out"
  local/llm-inference-bench
  --host 172.23.0.10
  --port 8000
  --no-hw-monitor
  --concurrency "$CONCURRENCY"
  --contexts 0,32768,131072
  --output /out/benchmark_results.json
)
docker run -ti --rm "${OPTS[@]}"

OPTS=(
  --network llm
  -v "$(pwd)/results/$name:/out"
  local/llm-inference-bench
  --host 172.23.0.10
  --port 8000
  --no-hw-monitor
  --concurrency "$CONCURRENCY"
  --contexts 131072
  --distinct-prefixes
  --output /out/benchmark_results_distinct_prefixes.json
)
docker run -ti --rm "${OPTS[@]}"
