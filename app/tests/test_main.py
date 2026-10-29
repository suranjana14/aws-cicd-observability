import json
import logging

from fastapi.testclient import TestClient

from app.main import app, emf_record

client = TestClient(app)


def test_healthz():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_readyz_reports_version_and_color():
    body = client.get("/readyz").json()
    assert body["status"] == "ready"
    assert {"version", "color", "uptime_seconds"} <= body.keys()


def test_request_id_is_propagated():
    r = client.get("/healthz", headers={"x-request-id": "abc-123"})
    assert r.headers["x-request-id"] == "abc-123"


def test_order_roundtrip():
    created = client.post("/api/v1/orders", json={"sku": "SKU-1", "quantity": 2})
    assert created.status_code == 201
    order_id = created.json()["id"]
    fetched = client.get(f"/api/v1/orders/{order_id}")
    assert fetched.status_code == 200
    assert fetched.json()["quantity"] == 2


def test_order_validation():
    assert client.post("/api/v1/orders", json={"sku": ""}).status_code == 422
    assert client.get("/api/v1/orders/does-not-exist").status_code == 404


def test_emf_record_shape():
    rec = emf_record("/healthz", 503, 12.345, "rid")
    directive = rec["_aws"]["CloudWatchMetrics"][0]
    names = {m["Name"] for m in directive["Metrics"]}
    assert names == {"Latency", "Requests", "Errors5xx"}
    assert rec["Errors5xx"] == 1
    for dims in directive["Dimensions"]:
        for d in dims:
            assert d in rec


def test_every_request_logs_emf(caplog):
    with caplog.at_level(logging.INFO):
        logger = logging.getLogger("orders-api")
        logger.propagate = True
        try:
            client.get("/healthz")
        finally:
            logger.propagate = False
    lines = [json.loads(r.getMessage()) for r in caplog.records if r.getMessage().startswith("{")]
    assert any(line.get("Route") == "/healthz" for line in lines)
