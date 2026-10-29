output "log_group_name" {
  description = "Application log group the container's awslogs driver writes to."
  value       = aws_cloudwatch_log_group.app.name
}

output "alarm_topic_arn" {
  description = "SNS topic that receives every alarm and OK notification."
  value       = aws_sns_topic.alarms.arn
}

output "rollback_alarm_name" {
  description = "Composite alarm the deploy pipeline watches to trigger automatic rollback."
  value       = aws_cloudwatch_composite_alarm.service_unhealthy.alarm_name
}

output "dashboard_url" {
  description = "Console URL for the service dashboard."
  value       = "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.service.dashboard_name}"
}
