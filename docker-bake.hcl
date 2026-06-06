group "default" {
  targets = ["llm-inference-bench"]
}

target "llm-inference-bench" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "llm-inference-bench"
  tags       = ["llm-inference-bench:latest"]
  output     = ["type=docker"]
}
