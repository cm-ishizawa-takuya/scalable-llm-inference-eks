// k6 load script: a fixed number of virtual users send chat completions
// through the Gateway in a loop. Env: VUS, DURATION, MAX_TOKENS.
import http from "k6/http";
import { check } from "k6";

export const options = {
  vus: Number(__ENV.VUS || 8),
  duration: __ENV.DURATION || "5m",
};

const url = __ENV.URL || "http://inference.gateway.svc.cluster.local/v1/chat/completions";
const prompts = [
  "Kubernetes の Pod と Deployment の違いを説明してください。",
  "EKS Auto Mode の利点を 3 つ挙げてください。",
  "KV キャッシュとは何か、LLM の推論でなぜ重要かを説明してください。",
  "Spot インスタンスを使うときの注意点を教えてください。",
];

export default function () {
  // A unique prefix per request. Without it the EPP's prefix-cache scorer
  // keeps sending identical prompts to the replica that already cached
  // them, and a new replica never receives traffic.
  const nonce = `[req ${__VU}-${__ITER}-${Date.now()}] `;
  const body = JSON.stringify({
    model: __ENV.MODEL || "qwen3-4b",
    messages: [{ role: "user", content: nonce + prompts[__VU % prompts.length] }],
    max_tokens: Number(__ENV.MAX_TOKENS || 256),
  });
  const res = http.post(url, body, {
    headers: { "Content-Type": "application/json" },
    timeout: "900s",
  });
  check(res, { "status 200": (r) => r.status === 200 });
}
