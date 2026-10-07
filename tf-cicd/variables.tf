variable "aws_region" {
    description = "Region for the image-build pipeline. Idle cost stays at zero in this region."
    type = string 
    default = "eu-west-1"
}

variable "name_prefix" {
    description = "Prefix for pipeline, build and repository names."
    type = string 
    default = "csr-lab"
}

variable "github_owner" {
    description = "GitHub organization or user that owns the source repository."
    type = string
    default = "Rurutia1027"
}


variable "github_repo" {
    description = "GitHub repository name."
    type = string
    default = "cloud-scalability-resilience-lab"
}

variable "github_branch" {
    description = "Branch that starts an image build when service code changes."
    type = string 
    default = "main"
}

variable "github_connection_arn" {
    description = "Existing CodeConnections connection ARN. Leave empty to create a new pending connection. Set it in terraform.tfvars, which is gitignored."
    type        = string
    default     = ""
}
