variable "REGISTRY_IMAGE" {
  default = "ghcr.io/prontolab/gb-25"
}

target "default" {
  context    = ".."
  dockerfile = "container/Containerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
  tags       = ["${REGISTRY_IMAGE}:latest"]
}
