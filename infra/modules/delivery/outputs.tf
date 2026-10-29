output "ecr_repository_url" {
  description = "Push target for CI images."
  value       = aws_ecr_repository.app.repository_url
}

output "deploy_role_arn" {
  description = "Role GitHub Actions assumes via OIDC (aws-actions/configure-aws-credentials `role-to-assume`)."
  value       = aws_iam_role.deploy.arn
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN for the task definition."
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ECS task (application) role ARN for the task definition."
  value       = aws_iam_role.task.arn
}
