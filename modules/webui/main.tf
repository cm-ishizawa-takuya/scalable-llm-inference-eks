################################################################################
# Open WebUI: a chat UI that speaks the OpenAI API. It points at the Gateway,
# so every chat goes through Envoy -> EPP -> vLLM like any other client.
# Demo settings: no login, no persistence, no Ollama, no pipelines.
################################################################################

resource "helm_release" "open_webui" {
  name             = "open-webui"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://helm.openwebui.com/"
  chart            = "open-webui"
  version          = var.chart_version

  values = [
    yamlencode({
      ollama    = { enabled = false }
      pipelines = { enabled = false }
      websocket = { enabled = false }
      # Chat history lives in an emptyDir and disappears with the Pod.
      persistence  = { enabled = false }
      replicaCount = 1
      resources = {
        requests = { cpu = "250m", memory = "512Mi" }
      }
      enableOpenaiApi  = true
      openaiBaseApiUrl = var.openai_api_base_url
      extraEnvVars = [
        # Open demo UI: no accounts.
        { name = "WEBUI_AUTH", value = "False" },
        { name = "ENABLE_OLLAMA_API", value = "False" },
        # Any non-empty key; the gateway does not check it.
        { name = "OPENAI_API_KEY", value = "unused" },
        # A chat that wakes vLLM from zero waits for the whole cold start.
        { name = "AIOHTTP_CLIENT_TIMEOUT", value = tostring(var.request_timeout_seconds) },
        { name = "AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST", value = "60" },
        # Environment variables win over values saved in the database.
        { name = "ENABLE_PERSISTENT_CONFIG", value = "False" },
      ]
    }),
  ]
}
