variable "REGISTRY_IMAGE" {
  default = "ghcr.io/prontolab/gb-25"
}

target "default" {
  context    = "."
  dockerfile = "container/Containerfile"
  tags       = ["${REGISTRY_IMAGE}:latest"]
  output     = ["type=docker"]
}
