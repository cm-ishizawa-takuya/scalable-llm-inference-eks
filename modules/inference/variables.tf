variable "namespace" {
  description = "Namespace for the inference workloads."
  type        = string
  default     = "inference"
}

variable "vllm_image_repository" {
  description = "Repository of the vLLM OpenAI-compatible server image. The unit points this at the ECR pull-through cache."
  type        = string
  default     = "vllm/vllm-openai"
}

variable "vllm_image_tag" {
  description = "Tag of the vLLM image."
  type        = string
  default     = "v0.32.0"
}

variable "cluster_name" {
  description = "EKS cluster name, used for the Pod Identity association and IAM role names."
  type        = string
}

variable "model_bucket_name" {
  description = "S3 bucket that holds the model weights."
  type        = string
}

variable "model_bucket_arn" {
  description = "ARN of the model weights bucket."
  type        = string
}

variable "model_s3_prefix" {
  description = "Key prefix of the model files in the bucket."
  type        = string
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

variable "gateway_name" {
  description = "Gateway the HTTPRoute attaches to."
  type        = string
}

variable "gateway_namespace" {
  description = "Namespace of that Gateway."
  type        = string
}

variable "router_chart_version" {
  description = "llm-d router (Endpoint Picker + InferencePool) Helm chart version."
  type        = string
  default     = "v1.0.0"
}

variable "request_timeout" {
  description = "HTTPRoute request timeout. Must exceed a full cold start so a request that arrives at zero replicas survives until vLLM is ready."
  type        = string
  default     = "900s"
}
