output "gateway_name" {
  description = "Gateway name for HTTPRoute parentRefs."
  value       = var.gateway_name
}

output "gateway_namespace" {
  description = "Gateway namespace for HTTPRoute parentRefs."
  value       = var.namespace
}
