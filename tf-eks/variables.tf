variable "aws_region" {
  description = "Same region as the image pipeline, so node pulls from ECR stay in-region."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Prefix shared with tf-cicd, so cluster and repository names line up."
  type        = string
  default     = "csr-lab"
}

variable "kubernetes_version" {
  description = "Must stay inside EKS standard support. Extended support raises the control plane to $0.60/hour."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR for the lab VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones. Two is the lower bound for the node-failure experiment."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "node_instance_type" {
  description = "Node size for the managed node group."
  type        = string
  default     = "t3.small"
}

variable "node_min_size" {
  description = "Minimum nodes. Two keeps Pods schedulable when one Availability Zone is unavailable."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired nodes at creation."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes. Four replicas at 100m CPU each still fit on two t3.small nodes."
  type        = number
  default     = 4
}

variable "db_name" {
  description = "Schema both services connect to. Matches the local docker-compose database."
  type        = string
  default     = "servicedb"
}

variable "db_username" {
  description = "RDS master user."
  type        = string
  default     = "labadmin"
}

variable "db_password" {
  description = "RDS master password. Pass it through terraform.tfvars, which is gitignored."
  type        = string
  sensitive   = true
}

variable "product_node_port" {
  description = "NodePort of the productservice Service in deploy/k8s/21-productservice.yaml."
  type        = number
  default     = 30090
}

variable "load_test_ingress_cidrs" {
  description = "Who may reach the productservice NodePort. Narrow this to your own address before a real run."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_container_insights" {
  description = "Installs the CloudWatch agent for pod metrics. Adds $1-$2 over a few hours, so it is off by default."
  type        = bool
  default     = false
}
