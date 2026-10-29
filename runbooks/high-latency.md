# High p99 latency

**Fires when:** p99 `Latency` above threshold (default 800 ms) in 3 of 5 one-minute periods.

## First 5 minutes
1. Check the dashboard: is p50 also up (everything slow) or only p99 (a slow path / noisy neighbour)?
2. Check the container CPU/memory widget. Saturated → see [container-saturation.md](container-saturation.md).
3. Correlate with the last deploy (`version` in logs).

## Diagnose
Saved query **slowest-requests** shows the routes and request IDs; follow a `request_id` through downstream logs.

## Mitigate
- Bad release → roll back.
- Saturation → scale out, then raise task CPU/memory in the task definition.
- Slow dependency → enable/shorten timeouts and fail fast rather than queueing.

## Follow up
- Revisit the threshold if it fired without user impact; tune, don't silence.
