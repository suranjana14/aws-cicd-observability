locals {
  tags = {
    Project     = "cicd-observability"
    Service     = var.service_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "observability" {
  source = "../../modules/observability"

  service_name       = var.service_name
  environment        = var.environment
  metric_namespace   = "Portfolio/OrdersApi"
  log_retention_days = 14
  alarm_emails       = var.alarm_emails

  error_threshold          = 5
  latency_p99_threshold_ms = 800

  ecs_cluster_name = var.ecs_cluster_name
  ecs_service_name = var.ecs_service_name

  tags = local.tags
}

module "delivery" {
  source = "../../modules/delivery"

  service_name                = var.service_name
  environment                 = var.environment
  github_repository           = var.github_repository
  github_deploy_refs          = ["ref:refs/heads/main", "environment:${var.environment}"]
  create_github_oidc_provider = var.create_github_oidc_provider
  log_group_arn               = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${module.observability.log_group_name}"

  tags = local.tags
}

data "aws_caller_identity" "current" {}
