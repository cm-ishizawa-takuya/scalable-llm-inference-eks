variable "namespace" {
  description = "Namespace for Open WebUI."
  type        = string
  default     = "webui"
}

variable "chart_version" {
  description = "open-webui Helm chart version."
  type        = string
  default     = "17.0.0"
}

variable "openai_api_base_url" {
  description = "OpenAI-compatible endpoint Open WebUI talks to: the Gateway's /v1."
  type        = string
}

variable "request_timeout_seconds" {
  description = "HTTP client timeout toward the gateway. Must cover a full cold start when a chat arrives at zero replicas."
  type        = number
  default     = 900
}
