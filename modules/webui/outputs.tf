output "service" {
  description = "Service to port-forward to reach the UI (port 80)."
  value       = "svc/open-webui -n ${var.namespace}"
}
