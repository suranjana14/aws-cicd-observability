variable "service_name" {
  description = "Service name; used for resource names and the EMF `Service` dimension."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
}

variable "metric_namespace" {
  description = "CloudWatch namespace the app writes EMF metrics to."
  type        = string
  default     = "Portfolio/OrdersApi"
}

variable "log_retention_days" {
  description = "Retention for the application log group."
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "Optional CMK for log group and SNS encryption. Null uses AWS-managed keys."
  type        = string
  default     = null
}

variable "alarm_emails" {
  description = "Email addresses subscribed to the alarm topic (each must confirm the subscription)."
  type        = list(string)
  default     = []
}

variable "error_threshold" {
  description = "5xx responses per period that trigger the error alarm."
  type        = number
  default     = 5
}

variable "latency_p99_threshold_ms" {
  description = "p99 latency (ms) that triggers the latency alarm."
  type        = number
  default     = 800
}

variable "alarm_period_seconds" {
  description = "Evaluation period for application alarms."
  type        = number
  default     = 60
}

variable "ecs_cluster_name" {
  description = "Optional ECS cluster name; enables container CPU/memory alarms and dashboard widgets."
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name (required when ecs_cluster_name is set)."
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "Optional ALB ARN suffix (app/name/id); enables load balancer alarms."
  type        = string
  default     = ""
}

variable "target_group_arn_suffix" {
  description = "Optional target group ARN suffix (targetgroup/name/id); used with alb_arn_suffix."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
