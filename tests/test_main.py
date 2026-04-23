import fakeredis
from fastapi.testclient import TestClient

import api.main as main


def test_create_job_pushes_queue(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(main, "r", fake)
    client = TestClient(main.app)

    response = client.post("/jobs")

    assert response.status_code == 200
    payload = response.json()
    assert "job_id" in payload
    assert fake.hget(f"job:{payload['job_id']}", "status") == "queued"
    assert fake.llen("jobs") == 1


def test_get_job_returns_status(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    fake.hset("job:abc123", "status", "completed")
    monkeypatch.setattr(main, "r", fake)
    client = TestClient(main.app)

    response = client.get("/jobs/abc123")

    assert response.status_code == 200
    assert response.json() == {"job_id": "abc123", "status": "completed"}


def test_get_job_not_found(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(main, "r", fake)
    client = TestClient(main.app)

    response = client.get("/jobs/missing")

    assert response.status_code == 404
    assert response.json()["detail"] == "not found"


def test_health_ok(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(main, "r", fake)
    client = TestClient(main.app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
