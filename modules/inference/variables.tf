variable "namespace" {
  description = "Namespace for the inference workloads."
  type        = string
  default     = "inference"
}

variable "vllm_image" {
  description = "vLLM OpenAI-compatible server image."
  type        = string
  default     = "vllm/vllm-openai:v0.32.0"
}

variable "model_id" {
  description = "Hugging Face model ID vLLM loads."
  type        = string
  default     = "Qwen/Qwen3-4B-Instruct-2507"
}

variable "served_model_name" {
  description = "Model name exposed by the OpenAI-compatible API. Clients and the router use this name."
  type        = string
  default     = "qwen3-4b"
}

variable "dtype" {
  description = "Weight dtype. T4 GPUs have no bfloat16 support, so the default is fp16."
  type        = string
  default     = "half"
}

variable "max_model_len" {
  description = "Maximum context length in tokens. Bounded by the VRAM left after the weights are loaded."
  type        = number
  default     = 8192
}

variable "gpu_memory_utilization" {
  description = "Fraction of GPU memory vLLM may use for weights and KV cache."
  type        = number
  default     = 0.90
}

variable "replicas" {
  description = "Initial number of vLLM replicas. Autoscaling takes over in a later unit."
  type        = number
  default     = 1
}

variable "model_cache_size" {
  description = "Size limit of the emptyDir that caches downloaded weights on the node's local storage."
  type        = string
  default     = "40Gi"
}
