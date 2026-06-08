group "default" {
  targets = ["llm-inference-bench"]
}

target "llm-inference-bench" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "llm-inference-bench"
  tags       = ["local/llm-inference-bench:latest"]
  output     = ["type=docker"]
}

target "vllm-lucifer" {
  context    = "."
  dockerfile = "Dockerfile.lucifer"
  target     = "lucifer-vllm-cu132"
  tags       = ["local/vllm:lucifer"]
  output     = ["type=docker"]
}
