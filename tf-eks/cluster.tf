data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name_prefix}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name_prefix}-eks/cluster"
  retention_in_days = 7
}

resource "aws_eks_cluster" "lab" {
  name     = "${var.name_prefix}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.nodes[*].id
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    # The identity that runs apply becomes cluster admin, so kubectl works right after
    # aws eks update-kubeconfig without a separate aws-auth edit.
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Audit is left out on purpose. Its log volume is the expensive part of control
  # plane logging and nothing in this lab reads it.
  enabled_cluster_log_types = ["api", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.lab.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.lab.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# CoreDNS and metrics-server both schedule real Pods, so they wait for the node group.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.lab.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.lab]
}

# Without this the HPA TARGETS column stays <unknown> and replicas never move.
resource "aws_eks_addon" "metrics_server" {
  cluster_name                = aws_eks_cluster.lab.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.lab]
}

resource "aws_eks_addon" "container_insights" {
  count = var.enable_container_insights ? 1 : 0

  cluster_name                = aws_eks_cluster.lab.name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.lab,
    aws_iam_role_policy_attachment.nodes_cloudwatch_agent,
  ]
}
