variable "cluster_name" {
  description = "EKS cluster name, used for the Pod Identity association and IAM role names."
  type        = string
}

variable "model_bucket_name" {
  description = "S3 bucket that receives the model weights."
  type        = string
}

variable "model_bucket_arn" {
  description = "ARN of the model weights bucket."
  type        = string
}

variable "model_id" {
  description = "Hugging Face model ID to download."
  type        = string
}

variable "model_s3_prefix" {
  description = "Key prefix under which the model files are stored in the bucket."
  type        = string
}

variable "namespace" {
  description = "Namespace for the upload Job."
  type        = string
  default     = "models"
}
