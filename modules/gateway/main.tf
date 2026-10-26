resource "kubernetes_manifest" "namespace" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = var.namespace
    }
  }
}

# Selects Envoy Gateway as the implementation for Gateways of this class.
resource "kubernetes_manifest" "gateway_class" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "envoy"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  }
}

# Envoy Gateway deploys one Envoy proxy per Gateway. Clients (Open WebUI, the
# load generator) run inside the cluster, so a ClusterIP Service is enough and
# no load balancer is created.
resource "kubernetes_manifest" "envoy_proxy" {
  manifest = {
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "EnvoyProxy"
    metadata = {
      name      = var.gateway_name
      namespace = var.namespace
    }
    spec = {
      provider = {
        type = "Kubernetes"
        kubernetes = {
          envoyService = {
            type = "ClusterIP"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}

resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = var.namespace
    }
    spec = {
      gatewayClassName = "envoy"
      infrastructure = {
        parametersRef = {
          group = "gateway.envoyproxy.io"
          kind  = "EnvoyProxy"
          name  = var.gateway_name
        }
      }
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          # Routes live in other namespaces (inference, webui).
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        },
      ]
    }
  }

  # Programmed means Envoy Gateway (and therefore Agent Router, which it
  # depends on) is up and the proxy is deployed.
  wait {
    condition {
      type   = "Programmed"
      status = "True"
    }
  }

  timeouts {
    create = "10m"
  }

  depends_on = [kubernetes_manifest.gateway_class, kubernetes_manifest.envoy_proxy]
}
