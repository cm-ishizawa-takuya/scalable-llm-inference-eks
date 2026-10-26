# scalable-llm-inference-eks

EKS Auto Mode 上に、負荷に応じて GPU ノードと vLLM Pod が 0 から増減する LLM 推論基盤を作るサンプルです。Gateway API Inference Extension と KEDA を組み合わせ、Pod が 0 台のときに届いた HTTP リクエストを切らずに待たせ、起動後に応答を返します。

## 構成

AWS 側と Kubernetes 側をどちらも Terraform で書き、Terragrunt のユニットとして依存順に適用します。ユニットは `units/<name>/` に置きます。

| ユニット | 作るもの |
| --- | --- |
| `cluster` | EKS Auto Mode クラスター、GPU 用 NodePool、モデル重みを置く S3 バケット、ECR プルスルーキャッシュ |
| `platform` | Envoy Gateway、Agent Router、Gateway API Inference Extension の CRD、KEDA、Prometheus |
| `inference` | vLLM、InferencePool、Endpoint Picker、HTTPRoute、ScaledObject |
| `webui` | Open WebUI |

ユニットは上から順に追加していきます。現時点ではツールチェーンの定義だけがあり、ユニットはまだありません。

## 前提

- [mise](https://mise.jdx.dev/)をインストール済みであること
- EKS、EC2、S3、ECR、IAM のリソースを作成できる AWS 認証情報があること
- 使うリージョンで EC2 のクォータ `All G and VT Spot Instance Requests` が 4 vCPU 以上あること（g4dn.xlarge の Spot を 1 台起動するため）

## 実行手順

```
mise install
```

ユニットを追加するたびに、適用コマンドを書き足します。

## 後片付け

GPU ノードが 0 台でも、EKS クラスター、CPU ノード、NLB には料金がかかります。検証しない時間帯はクラスターごと削除してください。削除コマンドもユニットを追加するたびに書き足します。
