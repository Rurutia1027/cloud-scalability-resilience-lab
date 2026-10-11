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
        width  = 8
        height = 6
        properties = {
          title                = "Running pods in csr-lab"
          region               = var.aws_region
          view                 = "singleValue"
          period               = 60
          stat                 = "Average"
          setPeriodToTimeRange = true
          metrics = [
            ["ContainerInsights", "namespace_number_of_running_pods", "ClusterName", aws_eks_cluster.lab.name, "Namespace", "csr-lab"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 16
        height = 6
        properties = {
          # One line per Kubernetes Service. couponservice and productservice
          # are the two application lines. HPA scale-out is this number rising.
          title  = "Running pods by service"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            [{
              expression = "SEARCH('{ContainerInsights,ClusterName,Namespace,Service} MetricName=\"service_number_of_running_pods\" ClusterName=\"${aws_eks_cluster.lab.name}\" Namespace=\"csr-lab\"', 'Average', 60)"
              id         = "podsByService"
              label      = "$${PROP('Dim.Service')}"
            }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 8
        properties = {
          # Pod names start with the Deployment: productservice-... and couponservice-...
          title  = "Pods in csr-lab"
          region = var.aws_region
          view   = "table"
          period = 60
          stat   = "Average"
          metrics = [
            [{
              expression = "SEARCH('{ContainerInsights,ClusterName,Namespace,PodName} MetricName=\"pod_cpu_utilization\" ClusterName=\"${aws_eks_cluster.lab.name}\" Namespace=\"csr-lab\"', 'Average', 60)"
              id         = "pods"
              label      = "$${PROP('Dim.PodName')}"
            }],
          ]
        }
      },
    ]
  })
}
