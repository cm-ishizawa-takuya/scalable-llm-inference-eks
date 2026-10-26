resource "kubernetes_manifest" "namespace" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = var.namespace
    }
  }
}

################################################################################
# Pod Identity: the Job's ServiceAccount may write to the model bucket
################################################################################

resource "aws_iam_role" "uploader" {
  name = "${var.cluster_name}-model-uploader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "uploader" {
  name = "model-bucket-write"
  role = aws_iam_role.uploader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.model_bucket_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = "${var.model_bucket_arn}/*"
      },
    ]
  })
}

resource "kubernetes_manifest" "uploader_sa" {
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "model-uploader"
      namespace = var.namespace
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}

resource "aws_eks_pod_identity_association" "uploader" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "model-uploader"
  role_arn        = aws_iam_role.uploader.arn
}

################################################################################
# One-shot upload Job
################################################################################

resource "kubernetes_manifest" "upload_script" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "model-upload-script"
      namespace = var.namespace
    }
    data = {
      "upload.py" = file("${path.module}/upload.py")
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}

resource "kubernetes_manifest" "upload_job" {
  manifest = {
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "model-upload"
      namespace = var.namespace
    }
    spec = {
      backoffLimit = 2
      template = {
        spec = {
          serviceAccountName = "model-uploader"
          # Never: a failed Pod stays around with its logs instead of being
          # restarted in place and deleted when the Job gives up.
          restartPolicy = "Never"
          containers = [
            {
              name  = "upload"
              image = "public.ecr.aws/docker/library/python:3.12-slim"
              command = [
                "sh", "-c",
                "pip install --quiet --no-cache-dir huggingface_hub boto3 && python /scripts/upload.py",
              ]
              env = [
                { name = "MODEL_ID", value = var.model_id },
                { name = "BUCKET", value = var.model_bucket_name },
                { name = "PREFIX", value = var.model_s3_prefix },
                { name = "HF_HOME", value = "/data/hf" },
              ]
              resources = {
                requests = {
                  cpu                 = "2"
                  memory              = "4Gi"
                  "ephemeral-storage" = "30Gi"
                }
              }
              volumeMounts = [
                { name = "scripts", mountPath = "/scripts", readOnly = true },
                { name = "data", mountPath = "/data" },
              ]
            },
          ]
          volumes = [
            {
              name = "scripts"
              configMap = {
                name = "model-upload-script"
              }
            },
            {
              name = "data"
              emptyDir = {
                sizeLimit = "30Gi"
              }
            },
          ]
        }
      }
    }
  }

  # Block until the Job finishes so that dependent units (vLLM) only start
  # once the weights are in S3.
  wait {
    condition {
      type   = "Complete"
      status = "True"
    }
  }

  timeouts {
    create = "40m"
  }

  depends_on = [
    kubernetes_manifest.uploader_sa,
    kubernetes_manifest.upload_script,
    aws_eks_pod_identity_association.uploader,
  ]
}
