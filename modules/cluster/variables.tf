variable "region" {
  description = "AWS region the cluster lives in."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix for the VPC."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the EKS control plane, e.g. 1.36."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across. EKS needs at least two."
  type        = number
  default     = 2
}

# Docker Hub credentials for the ECR pull-through cache. Both are ephemeral:
# Terraform uses them during apply and never writes them to state or plan.
# Pass them as TF_VAR_dockerhub_username and TF_VAR_dockerhub_token.
variable "dockerhub_username" {
  description = "Docker Hub user name."
  type        = string
  ephemeral   = true
  sensitive   = true
}

variable "dockerhub_token" {
  description = "Docker Hub personal access token with read-only scope."
  type        = string
  ephemeral   = true
  sensitive   = true
}

variable "dockerhub_credentials_version" {
  description = "Bump this number to push a new secret value. Terraform cannot see the write-only value, so this is how it knows to update."
  type        = number
  default     = 1
}
