variable "service_name" {
  description = "Service name; used for the ECR repository and role names."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the deploy role, as owner/name."
  type        = string
}

variable "github_deploy_refs" {
  description = "OIDC `sub` patterns allowed to deploy (branch or GitHub environment)."
  type        = list(string)
  default     = ["ref:refs/heads/main", "environment:dev"]
}

variable "create_github_oidc_provider" {
  description = "Create the account-wide GitHub OIDC provider. Set false if it already exists."
  type        = bool
  default     = true
}

variable "log_group_arn" {
  description = "Log group ARN the task execution role may write to."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster the deploy role may update (used to scope ecs:UpdateService)."
  type        = string
  default     = "*"
}

variable "image_retention_count" {
  description = "Number of tagged images to keep in ECR."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
