output "cluster_name" {
  description = "EKS cluster that runs the images."
  value       = aws_eks_cluster.lab.name
}

output "update_kubeconfig_command" {
  description = "Run this before the first kubectl apply."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.lab.name}"
}

output "db_endpoint" {
  description = "RDS host and port."
  value       = aws_db_instance.app.endpoint
}

output "spring_datasource_url" {
  description = "Value for SPRING_DATASOURCE_URL in deploy/k8s/10-config.yaml."
  value       = "jdbc:mysql://${aws_db_instance.app.endpoint}/${var.db_name}"
}

output "create_db_secret_command" {
  description = "The password is never committed, so the Secret is created from the shell."
  value       = "kubectl create secret generic db -n csr-lab --from-literal=password='<the db_password you passed to terraform>'"
}

output "aws_region" {
  description = "Region the cluster and the ALB are created in."
  value       = var.aws_region
}

output "alb_controller_role_arn" {
  description = "IAM role the AWS Load Balancer Controller service account assumes."
  value       = aws_iam_role.alb_controller.arn
}

output "product_alb_hostname_command" {
  description = "Prints the ALB DNS name after the Ingress has an address."
  value       = "kubectl get ingress productservice -n csr-lab -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "product_load_test_hint" {
  description = "k6 against the ALB DNS name. The NodePort path remains for the before/after comparison."
  value       = "bin/k6-load.sh http://$(kubectl get ingress productservice -n csr-lab -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
}

output "dashboard_url" {
  description = "Application and database metrics on one board."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.lab.dashboard_name}"
}
