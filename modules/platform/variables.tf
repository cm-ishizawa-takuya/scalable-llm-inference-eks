variable "envoy_gateway_version" {
  description = "Envoy Gateway Helm chart version."
  type        = string
  default     = "v1.9.2"
}

variable "agent_router_version" {
  description = "Agent Router (formerly Envoy AI Gateway) Helm chart version. The charts keep their old ai-gateway names."
  type        = string
  default     = "v1.2.0"
}
