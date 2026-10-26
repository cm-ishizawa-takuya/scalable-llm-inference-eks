output "region" {
  description = "AWS region of the cluster."
  value       = var.region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate of the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_iam_role_name" {
  description = "IAM role name that Auto Mode nodes assume. Custom NodeClasses reference it."
  value       = aws_iam_role.node.name
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs where nodes run."
  value       = values(aws_subnet.private)[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for internet-facing load balancers."
  value       = values(aws_subnet.public)[*].id
}

output "vllm_image_repository" {
  description = "ECR repository that caches the vLLM image from Docker Hub."
  value       = "${local.ecr_registry}/${aws_ecr_repository.vllm.name}"
}
