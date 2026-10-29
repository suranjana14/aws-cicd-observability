"""Tiny health/orders API used to demonstrate CI/CD and observability patterns.

Every request emits one structured JSON log line. Lines that carry an
`_aws` block are CloudWatch Embedded Metric Format (EMF), so latency and
error counts become CloudWatch metrics without a sidecar or agent.
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
import uuid

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

SERVICE_NAME = os.getenv("SERVICE_NAME", "orders-api")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "0.1.0")
DEPLOY_COLOR = os.getenv("DEPLOY_COLOR", "blue")  # set by the blue/green pipeline
METRIC_NAMESPACE = os.getenv("METRIC_NAMESPACE", "Portfolio/OrdersApi")

logger = logging.getLogger(SERVICE_NAME)
logger.setLevel(logging.INFO)
_handler = logging.StreamHandler(sys.stdout)
_handler.setFormatter(logging.Formatter("%(message)s"))
logger.addHandler(_handler)
logger.propagate = False

app = FastAPI(title=SERVICE_NAME, version=SERVICE_VERSION)

_ORDERS: dict[str, dict] = {}
_STARTED_AT = time.time()


def emf_record(route: str, status: int, latency_ms: float, request_id: str) -> dict:
    """Build a CloudWatch Embedded Metric Format log record."""
    return {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": METRIC_NAMESPACE,
                    "Dimensions": [["Service"], ["Service", "Route"]],
                    "Metrics": [
                        {"Name": "Latency", "Unit": "Milliseconds"},
                        {"Name": "Requests", "Unit": "Count"},
                        {"Name": "Errors5xx", "Unit": "Count"},
                    ],
                }
            ],
        },
        "Service": SERVICE_NAME,
        "Route": route,
        "Latency": round(latency_ms, 2),
        "Requests": 1,
        "Errors5xx": 1 if status >= 500 else 0,
        "status": status,
        "request_id": request_id,
        "version": SERVICE_VERSION,
        "color": DEPLOY_COLOR,
    }


@app.middleware("http")
async def observe(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    start = time.perf_counter()
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception:  # noqa: BLE001 - log every unhandled error, then re-raise as 500
        status = 500
        response = JSONResponse({"detail": "internal error"}, status_code=500)
    latency_ms = (time.perf_counter() - start) * 1000
    route = request.scope.get("route").path if request.scope.get("route") else request.url.path
    logger.info(json.dumps(emf_record(route, status, latency_ms, request_id)))
    response.headers["x-request-id"] = request_id
    return response


@app.get("/healthz")
def healthz() -> dict:
    """Liveness: the process is up. Used by container health checks."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict:
    """Readiness: safe to receive traffic. Used by ALB target groups / k8s readiness probes."""
    return {
        "status": "ready",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "color": DEPLOY_COLOR,
        "uptime_seconds": int(time.time() - _STARTED_AT),
    }


@app.post("/api/v1/orders", status_code=201)
def create_order(order: dict) -> dict:
    if not order.get("sku") or int(order.get("quantity", 0)) <= 0:
        raise HTTPException(status_code=422, detail="sku and positive quantity are required")
    order_id = str(uuid.uuid4())
    _ORDERS[order_id] = {"id": order_id, "sku": order["sku"], "quantity": int(order["quantity"])}
    return _ORDERS[order_id]


@app.get("/api/v1/orders/{order_id}")
def get_order(order_id: str) -> dict:
    if order_id not in _ORDERS:
        raise HTTPException(status_code=404, detail="order not found")
    return _ORDERS[order_id]
