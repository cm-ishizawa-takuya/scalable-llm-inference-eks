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

variable "prometheus_chart_version" {
  description = "prometheus-community/prometheus Helm chart version."
  type        = string
  default     = "29.38.2"
}

variable "keda_chart_version" {
  description = "KEDA Helm chart version."
  type        = string
  default     = "2.21.0"
}
