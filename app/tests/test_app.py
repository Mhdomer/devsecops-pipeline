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
