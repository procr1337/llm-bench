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

target "voipmonitor2-wsfix" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "voipmonitor2-wsfix"
  tags       = ["voipmonitor/vllm:abyssal-abjuration-611a842-a16-dcp-wsfix"]
  output     = ["type=docker"]
}
