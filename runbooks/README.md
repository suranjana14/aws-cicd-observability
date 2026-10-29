# Runbooks

Every alarm description links to one of these. Each runbook follows the same shape: **what fired → first 5 minutes → diagnose → mitigate → follow up**.

| Alarm | Runbook |
|---|---|
| `*-5xx-errors`, `*-error-rate` | [high-error-rate.md](high-error-rate.md) |
| `*-latency-p99` | [high-latency.md](high-latency.md) |
| `*-ecs-cpu-high`, `*-ecs-memory-high` | [container-saturation.md](container-saturation.md) |
| `*-unhealthy-targets`, failed CodeDeploy / rollout | [failed-deployment.md](failed-deployment.md) |
