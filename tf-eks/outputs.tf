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

output "product_load_test_hint" {
  description = "Where k6 points. Resolve a node address with the command below."
  value       = "kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"ExternalIP\")].address}' then http://<ip>:${var.product_node_port}/productapi/products"
}

output "dashboard_url" {
  description = "Application and database metrics on one board."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.lab.dashboard_name}"
}
