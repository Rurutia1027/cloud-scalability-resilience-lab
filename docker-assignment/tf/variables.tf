variable "aws_region" {
  description = "Region for the lab instance."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Prefix for the instance, VPC, and security group."
  type        = string
  default     = "docker-lab"
}

variable "vpc_cidr" {
  description = "CIDR for the lab VPC. Kept off 10.0.0.0/16 so it does not overlap the EKS lab."
  type        = string
  default     = "10.42.0.0/16"
}

variable "instance_type" {
  description = "Needs room for several 512MiB JVM replicas plus Grafana. t3.large is 8 GiB."
  type        = string
  default     = "t3.large"
}
