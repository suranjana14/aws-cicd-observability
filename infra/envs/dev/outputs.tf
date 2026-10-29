output "log_group_name" {
  value = module.observability.log_group_name
}

output "alarm_topic_arn" {
  value = module.observability.alarm_topic_arn
}

output "rollback_alarm_name" {
  value = module.observability.rollback_alarm_name
}

output "dashboard_url" {
  value = module.observability.dashboard_url
}

output "ecr_repository_url" {
  value = module.delivery.ecr_repository_url
}

output "deploy_role_arn" {
  value = module.delivery.deploy_role_arn
}

output "task_execution_role_arn" {
  value = module.delivery.task_execution_role_arn
}

output "task_role_arn" {
  value = module.delivery.task_role_arn
}
