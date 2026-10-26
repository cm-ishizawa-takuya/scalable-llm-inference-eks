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
- EKS、EC2、S3、ECR、IAM のリソースを作成できる AWS 認証情報があること
- 使うリージョンで EC2 のクォータ `All G and VT Spot Instance Requests` が 4 vCPU 以上あること（g4dn.xlarge の Spot を 1 台起動するため）

## 実行手順

認証情報とリージョンを環境変数で渡します。リージョンはどこでも構いません。

```
mise install
export AWS_REGION=us-east-1   # 使うリージョンに置き換える
```

`cluster` ユニットを適用します。初回だけ `backend bootstrap` で state 用の S3 バケットを作ってください。EKS クラスターの作成には 10 分ほどかかります。

```
cd units/cluster
terragrunt backend bootstrap
terragrunt apply
```

kubeconfig を取得して、Auto Mode の built-in NodePool が見えれば完了です。Pod がない間、ノードは 1 台も起動しません。

```
aws eks update-kubeconfig --name scalable-llm-inference
kubectl get nodepools
```

## 後片付け

GPU ノードが 0 台でも、EKS クラスター、NAT Gateway、CPU ノード、NLB には料金がかかります。検証しない時間帯はクラスターごと削除してください。

```
cd units/cluster
terragrunt destroy
```

state 用の S3 バケットは Terragrunt が管理外で作るので、最後に手で削除します。

```
aws s3 rb s3://scalable-llm-inference-tfstate-<アカウント ID>-<リージョン> --force
```
