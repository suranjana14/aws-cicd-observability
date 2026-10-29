# Failed deployment / unhealthy targets

**Fires when:** ALB `UnHealthyHostCount` > 0 for 3 minutes, or a CodeDeploy / rolling deployment fails.

## Blue/green (ECS + CodeDeploy)
1. `aws deploy get-deployment --deployment-id <id>`: which lifecycle hook failed?
2. `AfterAllowTestTraffic` failed → green never reported the new version on `/readyz`. Production traffic never moved; blue still serves. Fix forward in a new commit.
3. Rolled back on alarm → the composite `service-unhealthy` alarm fired during the canary. Treat as [high-error-rate.md](high-error-rate.md) for the green version.

## Rolling (EKS)
```bash
kubectl rollout status deploy/orders-api --timeout=5m
kubectl describe pod -l app=orders-api | sed -n '/Events/,$p'
kubectl rollout undo deploy/orders-api
```
`maxUnavailable: 0` means old pods keep serving until new pods pass readiness, so a failed rollout reduces surge capacity, not availability.

## Common causes
- Image pull errors: check ECR permissions on the task execution role and that the tag exists (tags are immutable).
- Health check path or port mismatch between the task definition and the target group.
- Missing environment variable or secret on the new task definition revision.
