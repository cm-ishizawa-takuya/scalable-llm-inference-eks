output "gateway_controller_name" {
  description = "controllerName to reference from a GatewayClass."
  value       = "gateway.envoyproxy.io/gatewayclass-controller"
}

output "prometheus_url" {
  description = "In-cluster URL of the Prometheus server, for KEDA triggers."
  value       = "http://prometheus-server.monitoring.svc.cluster.local:80"
}
