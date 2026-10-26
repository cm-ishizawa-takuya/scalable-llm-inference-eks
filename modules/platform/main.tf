################################################################################
# Envoy Gateway and Agent Router depend on each other at startup: the Agent
# Router controller watches Gateway API resources (CRDs installed by the Envoy
# Gateway chart), and Envoy Gateway only becomes ready once it can list
# InferencePools (a permission the Agent Router chart grants). So Envoy Gateway
# is installed first without waiting for readiness, then Agent Router. The
# gateway unit waits for the Gateway to be programmed, which implies both are up.
################################################################################

resource "helm_release" "agent_router_crds" {
  name             = "agent-router-crds"
  namespace        = "envoy-ai-gateway-system"
  create_namespace = true
  chart            = "oci://docker.io/envoyproxy/ai-gateway-crds-helm"
  version          = var.agent_router_version
}

# Envoy Gateway, configured to call the Agent Router controller as its
# extension server and to accept InferencePool as a backend kind. The chart
# also installs the Gateway API CRDs.
resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  namespace        = "envoy-gateway-system"
  create_namespace = true
  chart            = "oci://docker.io/envoyproxy/gateway-helm"
  version          = var.envoy_gateway_version

  values = [
    file("${path.module}/files/envoy-gateway-values.yaml"),
    file("${path.module}/files/envoy-gateway-values-inferencepool.yaml"),
  ]

  # Readiness depends on Agent Router, which is installed next.
  wait = false

  depends_on = [kubernetes_manifest.gie_crds]
}

# Agent Router controller: Envoy Gateway extension that teaches it to route to
# InferencePool backends through an Endpoint Picker. Also grants Envoy Gateway
# read access to InferencePools.
resource "helm_release" "agent_router" {
  name      = "agent-router"
  namespace = "envoy-ai-gateway-system"
  chart     = "oci://docker.io/envoyproxy/ai-gateway-helm"
  version   = var.agent_router_version

  depends_on = [helm_release.agent_router_crds, helm_release.envoy_gateway]
}

################################################################################
# Gateway API Inference Extension CRDs (InferencePool, InferencePoolImport)
################################################################################

locals {
  # kubernetes_manifest rejects server-populated keys such as `status`, so
  # only the parts that define the CRD are kept. Annotations stay because
  # *.k8s.io groups must carry api-approved.kubernetes.io.
  gie_crds = {
    for doc in provider::kubernetes::manifest_decode_multi(
      file("${path.module}/files/gateway-api-inference-extension-crds.yaml")
      ) : doc.metadata.name => {
      apiVersion = doc.apiVersion
      kind       = doc.kind
      metadata = {
        name        = doc.metadata.name
        annotations = try(doc.metadata.annotations, {})
        labels      = try(doc.metadata.labels, {})
      }
      spec = doc.spec
    }
  }
}

resource "kubernetes_manifest" "gie_crds" {
  for_each = local.gie_crds

  manifest = each.value
}
