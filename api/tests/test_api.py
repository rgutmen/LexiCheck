import os

os.environ["LEXI_DATABASE_URL"] = "sqlite:///./test.db"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from lexicheck.main import app  # noqa: E402
from lexicheck.settings import Settings  # noqa: E402


def test_database_url_from_discrete_values():
    s = Settings(database_url=None, db_host="db.internal", db_user="u", db_password="p@ss/word")
    assert s.resolved_database_url == (
        "postgresql+psycopg://u:p%40ss%2Fword@db.internal:5432/lexicheck?sslmode=require"
    )


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c
    if os.path.exists("test.db"):
        os.remove("test.db")


def test_health(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").status_code == 200


def test_detects_misspelling_with_offset(client):
    text = "This sentense has an eror."
    body = client.post("/v1/check", json={"text": text, "language": "en"}).json()
    words = {i["word"]: i for i in body["issues"]}
    assert set(words) == {"sentense", "eror"}
    assert text[words["eror"]["offset"] :].startswith("eror")
    assert "sentence" in words["sentense"]["suggestions"]


def test_preserves_capitalisation(client):
    body = client.post("/v1/check", json={"text": "Helo world"}).json()
    assert body["issues"][0]["suggestions"][0][0].isupper()


def test_spanish(client):
    payload = {"text": "Hola mundo, esto es una pruebba", "language": "es"}
    body = client.post("/v1/check", json=payload)
    assert [i["word"] for i in body.json()["issues"]] == ["pruebba"]


def test_rejects_unknown_language(client):
    assert client.post("/v1/check", json={"text": "hi", "language": "xx"}).status_code == 422


def test_rejects_empty_text(client):
    assert client.post("/v1/check", json={"text": ""}).status_code == 422


def test_history_and_metrics(client):
    client.post("/v1/check", json={"text": "recorded entry"})
    history = client.get("/v1/history?limit=1").json()
    assert history[0]["preview"] == "recorded entry"
    assert "lexicheck_http_requests_total" in client.get("/metrics").text
