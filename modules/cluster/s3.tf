# Model weights live in S3 so that vLLM reads them through the S3 gateway
# endpoint instead of downloading from Hugging Face through the NAT gateway
# on every cold start. force_destroy lets `destroy` remove the weights too.
resource "aws_s3_bucket" "models" {
  bucket        = "${var.cluster_name}-models-${data.aws_caller_identity.current.account_id}-${var.region}"
  force_destroy = true
}
