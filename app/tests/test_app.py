import pytest
from app.app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as c:
        yield c


def test_index(client):
    res = client.get("/")
    assert res.status_code == 200
    assert res.get_json()["status"] == "ok"


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "healthy"


def test_get_items(client):
    res = client.get("/api/items")
    assert res.status_code == 200
    assert len(res.get_json()["items"]) == 2


def test_create_item(client):
    res = client.post("/api/items", json={"name": "Widget C"})
    assert res.status_code == 201
    assert res.get_json()["name"] == "Widget C"


def test_create_item_missing_name(client):
    res = client.post("/api/items", json={})
    assert res.status_code == 400


@pytest.mark.parametrize("path", ["/", "/health", "/api/items", "/does-not-exist"])
def test_security_headers_on_every_response(client, path):
    headers = client.get(path).headers
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert headers["X-Frame-Options"] == "DENY"
    assert "default-src 'none'" in headers["Content-Security-Policy"]
    # Directives with no default-src fallback must be set explicitly (ZAP rule 10055)
    for directive in ("frame-ancestors 'none'", "base-uri 'none'", "form-action 'none'"):
        assert directive in headers["Content-Security-Policy"]
    assert headers["Permissions-Policy"]
    assert headers["Cross-Origin-Resource-Policy"] == "same-origin"
    assert headers["Referrer-Policy"] == "no-referrer"
    assert headers["Cache-Control"] == "no-store"
