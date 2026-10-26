# ECR pull-through cache for Docker Hub. The vLLM image (9 GB) is pulled from
# ECR inside the region instead of from Docker Hub on every cold start.

data "aws_caller_identity" "current" {}

locals {
  ecr_registry    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  ecr_prefix      = "docker-hub"
  vllm_image_repo = "vllm/vllm-openai"
}

# Docker Hub credentials. The value is written with a write-only argument and
# never stored in Terraform state. recovery_window_in_days = 0 lets destroy
# remove the secret immediately.
resource "aws_secretsmanager_secret" "docker_hub" {
  name                    = "ecr-pullthroughcache/${var.cluster_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "docker_hub" {
  secret_id = aws_secretsmanager_secret.docker_hub.id
  secret_string_wo = jsonencode({
    username    = var.dockerhub_username
    accessToken = var.dockerhub_token
  })
  secret_string_wo_version = var.dockerhub_credentials_version
}

resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  ecr_repository_prefix = local.ecr_prefix
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = aws_secretsmanager_secret.docker_hub.arn
}

# Pre-create the cached repository so nodes only need
# ecr:BatchImportUpstreamImage, not ecr:CreateRepository.
resource "aws_ecr_repository" "vllm" {
  name         = "${local.ecr_prefix}/${local.vllm_image_repo}"
  force_delete = true
}

resource "aws_iam_role_policy" "node_pull_through_cache" {
  name = "ecr-pull-through-cache"
  role = aws_iam_role.node.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchImportUpstreamImage"]
        Resource = aws_ecr_repository.vllm.arn
      },
    ]
  })
}

# ECR serves image layers from S3. With a gateway endpoint that traffic stays
# off the NAT gateway, which is free and faster. Model weights in S3 use it too.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.cluster_name}-s3"
  }
}

# ECR API and registry endpoints so that image pulls never leave the VPC.
# Layers still come from S3 through the gateway endpoint above. One AZ is
# enough for a demo; nodes in the other AZ reach it across the AZ boundary.
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.cluster_name}-vpc-endpoints"
  description = "HTTPS from the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = {
    Name = "${var.cluster_name}-vpc-endpoints"
  }
}

resource "aws_vpc_endpoint" "ecr" {
  for_each = toset(["ecr.api", "ecr.dkr"])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private[local.azs[0]].id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-${each.value}"
  }
}
