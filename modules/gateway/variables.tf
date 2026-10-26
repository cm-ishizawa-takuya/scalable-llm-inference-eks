variable "namespace" {
  description = "Namespace that holds the Gateway and the Envoy proxy Pods it creates."
  type        = string
  default     = "gateway"
}

variable "gateway_name" {
  description = "Name of the Gateway. Routes in other units attach to it."
  type        = string
  default     = "inference"
}
