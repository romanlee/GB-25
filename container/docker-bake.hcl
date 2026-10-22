variable "REGISTRY_IMAGE" {
  default = "ghcr.io/prontolab/gb-25"
}

target "default" {
  context    = "."
  dockerfile = "container/Containerfile"
  output     = ["type=docker,name=${REGISTRY_IMAGE}"]
}
