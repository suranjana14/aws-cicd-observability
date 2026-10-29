# Container CPU / memory saturation

**Fires when:** ECS service CPU > 80% or memory > 85% for 4 of 5 minutes (Container Insights).

## First 5 minutes
1. Is traffic up (`Requests` widget)? If yes, this is load: scale out.
2. Is memory climbing steadily with flat traffic? Likely a leak: tasks will be OOM-killed (`stopCode` / exit 137).

## Diagnose
```bash
aws ecs describe-services --cluster <c> --services orders-api --query 'services[0].events[:10]'
aws ecs list-tasks --cluster <c> --service-name orders-api --desired-status STOPPED
aws ecs describe-tasks --cluster <c> --tasks <arn> --query 'tasks[].containers[].[reason,exitCode]'
```

## Mitigate
- Increase desired count; confirm Service Auto Scaling target tracking is enabled.
- Leak after a deploy → roll back.

## Follow up
- Right-size the task definition from a week of Container Insights data.
