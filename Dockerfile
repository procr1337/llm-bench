FROM python:3.12-slim AS llm-inference-bench

WORKDIR /app

RUN pip install --no-cache-dir httpx rich psutil

COPY llm-inference-bench/ .

ENTRYPOINT ["python3", "llm_decode_bench.py"]
