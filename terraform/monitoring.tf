# =========================
# CLOUDWATCH LOG GROUP PARA A API
# =========================
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/ec2/devsecops-api"
  retention_in_days = 30

  tags = {
    Name = "devsecops-api-logs"
  }
}

# =========================
# TÓPICO SNS PARA ALERTAS DE SEGURANÇA
# =========================
resource "aws_sns_topic" "security_alerts" {
  name = "devsecops-security-alerts"
}

# =========================
# FILA SQS PARA NOTIFICAÇÕES LOCAIS
# =========================
resource "aws_sqs_queue" "alert_queue_local" {
  name = "devsecops-alerts-queue"

  tags = {
    Name = "devsecops-alerts-queue"
  }
}

# =========================
# CLOUDWATCH METRIC ALARM - CPU DA EC2
# =========================
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "devsecops-ec2-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta: Uso de CPU da instancia EC2 acima de 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.api.id
  }

  alarm_actions = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name = "devsecops-ec2-high-cpu"
  }
}

# =========================
# CLOUDWATCH DASHBOARD
# =========================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "devsecops-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.api.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Uso de CPU da EC2 (%)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.api.id],
            [".", "NetworkOut", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Tráfego de Rede da EC2 (Bytes)"
        }
      }
    ]
  })
}


