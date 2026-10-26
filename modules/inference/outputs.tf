output "namespace" {
  description = "Namespace of the inference workloads."
  value       = var.namespace
}

output "vllm_service" {
  description = "ClusterIP Service name of vLLM."
  value       = "vllm"
}

output "served_model_name" {
  description = "Model name to pass in OpenAI-compatible requests."
  value       = var.served_model_name
}
