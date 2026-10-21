output "public_ip" {
  description = "Public address of the lab instance."
  value       = aws_instance.lab.public_ip
}

output "grafana_url" {
  description = "Same Grafana boards as the local compose stack. Login is anonymous admin."
  value       = "http://${aws_instance.lab.public_ip}:3000"
}

output "product_url" {
  description = "productservice through the compose gateway."
  value       = "http://${aws_instance.lab.public_ip}:9090/productapi/products"
}

output "ssh_command" {
  description = "Shell on the instance. The scaler and the baseline sampler run here."
  value       = "ssh -i tf/lab-key.pem ec2-user@${aws_instance.lab.public_ip}"
}

output "baseline_then_k6" {
  description = "Measure one replica, then drive it. The sampler must be running on the instance before k6 starts."
  value       = <<-EOT
    ssh -i tf/lab-key.pem ec2-user@${aws_instance.lab.public_ip} '/opt/docker-assignment/bin/measure-baseline.sh'
    bin/k6-load.sh http://${aws_instance.lab.public_ip}:9090
  EOT
}
