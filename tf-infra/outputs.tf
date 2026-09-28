output "ecr_repository_urls" {
  description = "Registries that receive the built images."
  value       = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}

output "pipeline_name" {
  description = "CodePipeline that builds both images."
  value       = aws_codepipeline.images.name
}

output "github_connection_arn" {
  description = "Authorize this pending connection once in the AWS console before the first push."
  value       = aws_codestarconnections_connection.github.arn
}

output "github_connection_console_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/codesuite/settings/connections"
}