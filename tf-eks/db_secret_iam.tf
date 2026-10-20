data "tls_certificate" "eks" {
  url = aws_eks_cluster.lab.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.lab.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

locals {
  eks_oidc_host = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

# The pod identity. Same job as the Vault token mounted into an IDM pod:
# the Deployment names a secret id, and only this role may read that one secret.
data "aws_iam_policy_document" "db_secret_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_host}:sub"
      values = [
        "system:serviceaccount:${var.name_prefix}:productservice",
        "system:serviceaccount:${var.name_prefix}:couponservice",
      ]
    }
  }
}

resource "aws_iam_role" "db_secret" {
  name               = "${var.name_prefix}-db-secret"
  assume_role_policy = data.aws_iam_policy_document.db_secret_assume.json
}

resource "aws_iam_role_policy" "db_secret_read" {
  name = "${var.name_prefix}-db-secret-read"
  role = aws_iam_role.db_secret.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_db_instance.app.master_user_secret[0].secret_arn
      }
    ]
  })
}
