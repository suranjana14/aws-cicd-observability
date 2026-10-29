# High 5xx error rate

**Fires when:** `Errors5xx` ≥ threshold, or 5xx rate > 2% of requests, in 2 of 3 one-minute periods.

## First 5 minutes
1. Acknowledge the page and post in the incident channel: "Investigating elevated 5xx on orders-api (<env>)".
2. Open the service dashboard (Terraform output `dashboard_url`). Did errors start at a deploy? Check the `version` / `color` columns in the **Recent 5xx** widget.
3. If a deployment is in progress, **stop it** — CodeDeploy rolls back to blue automatically:
   ```bash
   aws deploy stop-deployment --deployment-id <id> --auto-rollback-enabled
   ```

## Diagnose
Logs Insights saved query **errors-by-version**:
```
filter status >= 500
| stats count(*) as errors by version, color, Route
| sort errors desc
```
- Errors on one version only → bad release. Roll back (above, or `kubectl rollout undo deploy/orders-api` on EKS).
- Errors on every version, one route → a downstream dependency. Check its health and recent changes.
- Errors everywhere → platform issue: check target health, task stops (`aws ecs describe-services`), AWS Health Dashboard.

## Mitigate
- Roll back first, debug second.
- If load related, scale out: `aws ecs update-service --cluster <c> --service orders-api --desired-count <n>`.

## Follow up
- Record a timeline, root cause, and an action item that would have caught it earlier (test, alarm, or canary check).
