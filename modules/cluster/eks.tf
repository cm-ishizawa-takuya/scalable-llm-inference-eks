resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  # Access entries only. The identity running Terraform becomes cluster admin.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Auto Mode manages the core add-ons on the AWS side, so the self-managed
  # VPC CNI, CoreDNS and kube-proxy must not be installed.
  bootstrap_self_managed_addons = false

  # These three must be enabled together for Auto Mode.
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids              = values(aws_subnet.private)[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # A demo cluster is short-lived; do not pay for extended support.
  upgrade_policy {
    support_type = "STANDARD"
  }

  # IAM permissions must exist before the cluster is created and must outlive
  # it, otherwise EKS cannot clean up the EC2 resources it manages.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
