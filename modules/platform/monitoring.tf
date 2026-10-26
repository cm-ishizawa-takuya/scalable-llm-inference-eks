################################################################################
# Prometheus: scrapes vLLM and EPP metrics that KEDA reads. Server only, short
# retention, no persistent volume. Annotated Pods are picked up by the chart's
# default `kubernetes-pods` scrape job.
################################################################################

resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_chart_version

  values = [
    yamlencode({
      alertmanager             = { enabled = false }
      kube-state-metrics       = { enabled = false }
      prometheus-node-exporter = { enabled = false }
      prometheus-pushgateway   = { enabled = false }
      server = {
        retention        = "2d"
        persistentVolume = { enabled = false }
        global = {
          scrape_interval     = "15s"
          evaluation_interval = "15s"
        }
        resources = {
          requests = { cpu = "200m", memory = "512Mi" }
        }
      }
    }),
  ]
}

################################################################################
# KEDA: turns Prometheus queries into replica counts through an HPA.
# Installs the ScaledObject CRDs, so ScaledObjects live in later units.
################################################################################

resource "helm_release" "keda" {
  name             = "keda"
  namespace        = "keda"
  create_namespace = true
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_chart_version
}
