output "model_s3_uri" {
  description = "S3 URI vLLM loads the model from."
  value       = "s3://${var.model_bucket_name}/${var.model_s3_prefix}"
}
