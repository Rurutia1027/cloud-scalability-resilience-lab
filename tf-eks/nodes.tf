data "aws_iam_policy_document" "nodes_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.name_prefix}-eks-nodes"
  assume_role_policy = data.aws_iam_policy_document.nodes_assume.json
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# This is what lets kubelet pull the private ECR images directly, so the
# Deployments need no imagePullSecret.
resource "aws_iam_role_policy_attachment" "nodes_ecr_read" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# The CloudWatch agent runs on the nodes and uses the node role, which avoids
# setting up IRSA just for the observability addon.
resource "aws_iam_role_policy_attachment" "nodes_cloudwatch_agent" {
  count = var.enable_container_insights ? 1 : 0

  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_node_group" "lab" {
  cluster_name    = aws_eks_cluster.lab.name
  node_group_name = "${var.name_prefix}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = aws_subnet.nodes[*].id
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  disk_size       = 20

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  # The node group is not autoscaled in this lab. Terraform should not fight a
  # manual scale-up made during a load test.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr_read,
  ]
}

# EKS attaches the cluster security group to the node instances, and it has no
# inbound rule from the internet. This one opens the productservice NodePort so
# k6 can drive load against a node's public IP.
resource "aws_vpc_security_group_ingress_rule" "product_node_port" {
  count = length(var.load_test_ingress_cidrs)

  security_group_id = aws_eks_cluster.lab.vpc_config[0].cluster_security_group_id
  cidr_ipv4         = var.load_test_ingress_cidrs[count.index]
  from_port         = var.product_node_port
  to_port           = var.product_node_port
  ip_protocol       = "tcp"
  description       = "productservice NodePort for the load test"
}
