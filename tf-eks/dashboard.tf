resource "aws_cloudwatch_dashboard" "lab" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU and connections"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.app.identifier],
            [".", "DatabaseConnections", ".", "."],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "RDS latency and memory"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_db_instance.app.identifier],
            [".", "WriteLatency", ".", "."],
            [".", "FreeableMemory", ".", "."],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          # Empty until the amazon-cloudwatch-observability addon is installed,
          # which is var.enable_container_insights.
          title  = "Pod CPU and memory"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "ClusterName", aws_eks_cluster.lab.name],
            [".", "pod_memory_utilization", ".", "."],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          # Running pod count is how HPA scale-out shows up on the board. Read it
          # next to pod CPU: replicas rise after CPU crosses the 60% target.
          title  = "Running pods and restarts"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["ContainerInsights", "service_number_of_running_pods", "ClusterName", aws_eks_cluster.lab.name, "Namespace", "csr-lab"],
            ["ContainerInsights", "pod_number_of_container_restarts", "ClusterName", aws_eks_cluster.lab.name, "Namespace", "csr-lab"],
          ]
        }
      },
    ]
  })
}
