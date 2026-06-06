FROM python:3.12-slim AS llm-inference-bench

WORKDIR /app

RUN pip install --no-cache-dir httpx rich psutil

COPY llm-inference-bench/ .

ENTRYPOINT ["python3", "llm_decode_bench.py"]


# ---------- vLLM overlay: b12x prefill workspace reserve ----------
FROM voipmonitor/vllm:abyssal-abjuration-611a842-a16-dcp@sha256:8601786e427faa72368e3d57e04d30a80a33bfbf5372352bdfb4358667827f36 AS voipmonitor2-wsfix

COPY patches/patch_b12x_workspace_reserve.py /tmp/patch_b12x_workspace_reserve.py
RUN python3 /tmp/patch_b12x_workspace_reserve.py && rm /tmp/patch_b12x_workspace_reserve.py
