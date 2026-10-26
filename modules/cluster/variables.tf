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
