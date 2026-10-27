# scalable-llm-inference-eks

EKS Auto Mode 上に、負荷に応じて GPU ノードと vLLM Pod が 0 から増減する LLM 推論基盤を作るサンプルです。Gateway API Inference Extension と KEDA を組み合わせ、Pod が 0 台のときに届いた HTTP リクエストを切らずに待たせ、起動後に応答を返します。

## 構成

AWS 側と Kubernetes 側をどちらも Terraform で書き、Terragrunt のユニットとして依存順に適用します。ユニットは `units/<name>/` に置きます。

| ユニット | 作るもの |
| --- | --- |
| `cluster` | VPC、VPC エンドポイント、IAM ロール、EKS Auto Mode クラスター、ECR プルスルーキャッシュ、モデル重み用の S3 バケット |
| `nodepool` | GPU 用 NodePool |
| `model` | モデルの重みを Hugging Face から S3 へコピーする Job と、その Pod Identity |
| `platform` | Envoy Gateway、Agent Router、Gateway API Inference Extension の CRD、KEDA、Prometheus |
| `gateway` | GatewayClass、Gateway、Envoy の Service を ClusterIP にする EnvoyProxy 設定 |
| `inference` | vLLM、InferencePool、Endpoint Picker（Flow Control 有効）、HTTPRoute、KEDA の ScaledObject |
| `webui` | Open WebUI |

ユニットは依存順に並んでいます。`terragrunt run --all apply` はこの順で適用します。

共通設定は `root.hcl` にあります。リージョンは環境変数 `AWS_REGION` から読み、Terraform の state は `scalable-llm-inference-tfstate-<アカウント ID>-<リージョン>` という名前の S3 バケットに置きます。

## 前提

- [mise](https://mise.jdx.dev/)をインストール済みであること
- EKS、EC2、S3、ECR、Secrets Manager、IAM のリソースを作成できる AWS 認証情報があること
- 使うリージョンで EC2 の G 系クォータが 4 vCPU 以上あること。対象は Spot の `All G and VT Spot Instance Requests` とオンデマンドの `Running On-Demand G and VT instances` の 2 つで、新しいリージョンでは 0 のことがある
- Docker Hub のアカウントと読み取り専用のアクセストークン（vLLM のイメージを ECR のプルスルーキャッシュ経由で取得するため）

## 実行手順

コマンドはすべてこのリポジトリのルートで実行します。AWS の認証情報はプロファイルなど AWS CLI の通常の方法で設定しておき、リージョンと Docker Hub の認証情報は環境変数で渡します。リージョンはどこでも構いません。Docker Hub の 2 つは Terraform の ephemeral 変数として扱われ、state には残りません。

```
mise install
export AWS_REGION=us-east-1   # 使うリージョンに置き換える
export TF_VAR_dockerhub_username=<Docker Hub のユーザー名>
export TF_VAR_dockerhub_token=<Docker Hub のアクセストークン>
```

全ユニットを依存順に適用します。初回は `--backend-bootstrap` が state 用の S3 バケットを作ります。EKS の作成を含めて 20 分ほどかかり、完了時点で vLLM は 0 レプリカ、GPU ノードは 0 台です。

```
terragrunt run --all --backend-bootstrap apply
```

kubeconfig を取得し、Open WebUI を手元に引いて `http://localhost:8080` を開いてください。最初のメッセージを送ると GPU ノードと vLLM が起動し、7 分前後で応答が返ります。待っている間の起動の様子は `kubectl get nodeclaims` と `kubectl -n inference get pods` で追えます。

```
aws eks update-kubeconfig --name scalable-llm-inference
kubectl -n webui port-forward svc/open-webui 8080:80
```

### 負荷をかけて 1 から 2 へ増やす

`manifests/load-test/` の k6 スクリプトで 8 並列のリクエストを 15 分間流すと、EPP の実行中リクエスト数が 1 レプリカあたり 4 を超え、KEDA が 2 台目を起動します。2 台目が応答を返し始めるのは起動から 7 分前後です。

```
kubectl -n inference create configmap load-script --from-file=manifests/load-test/load.js
kubectl -n inference apply -f manifests/load-test/job.yaml
kubectl -n inference get hpa -w
```

途中で負荷を止めるには Job を削除します。負荷が止まると、レプリカは 5 分後に 1 へ戻り、さらに 5 分で 0 へ戻ります。

```
kubectl -n inference delete job load-test
```

## 後片付け

GPU ノードが 0 台でも、EKS クラスター、NAT Gateway、VPC エンドポイント、CPU ノードには料金がかかります。検証しない時間帯はクラスターごと削除してください。全ユニットを依存の逆順に削除し、10 分ほどで終わります。

```
terragrunt run --all destroy
```

state 用の S3 バケットは Terragrunt が管理外で作るので、最後に手で削除します。

```
aws s3 rb s3://scalable-llm-inference-tfstate-<アカウント ID>-<リージョン> --force
```
