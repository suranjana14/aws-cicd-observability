variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Service name."
  type        = string
  default     = "orders-api"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "github_repository" {
  description = "owner/name of the repository whose workflows may deploy."
  type        = string
  default     = "suranjana14/aws-cicd-observability"
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has the GitHub OIDC provider."
  type        = bool
  default     = true
}

variable "alarm_emails" {
  description = "On-call email addresses for alarm notifications."
  type        = list(string)
  default     = []
}

variable "ecs_cluster_name" {
  description = "Existing ECS cluster to monitor (optional)."
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "Existing ECS service to monitor (optional)."
  type        = string
  default     = ""
}
