"""AI rewrite tests. OpenAI is never called: a fake transport plays its part."""

import json

import httpx
import pytest

from lexicheck import rewriter
from lexicheck.settings import get_settings


def fake_openai(reply: str | None = "Ahoy, matey!", status: int = 200, seen: list | None = None):
    def handler(request: httpx.Request) -> httpx.Response:
        if seen is not None:
            seen.append(json.loads(request.content))
        if status != 200:
            return httpx.Response(status, json={"error": {"message": "boom"}})
        return httpx.Response(
            200,
            json={
                "model": "gpt-4o-mini-2024-07-18",
                "choices": [{"message": {"content": reply}}],
                "usage": {"total_tokens": 42},
            },
        )

    return httpx.Client(transport=httpx.MockTransport(handler))


@pytest.fixture
def with_key(monkeypatch):
    monkeypatch.setattr(get_settings(), "openai_api_key", "sk-test")
    yield


def test_disabled_without_key(monkeypatch):
    monkeypatch.setattr(get_settings(), "openai_api_key", None)
    assert not rewriter.enabled()
    with pytest.raises(rewriter.RewriteUnavailable):
        rewriter.rewrite("hi", "pirate")


def test_prompt_and_result(with_key):
    seen: list = []
    result = rewriter.rewrite("helo there", "pirate", client=fake_openai(seen=seen))
    assert result.text == "Ahoy, matey!"
    assert result.tokens == 42
    sent = seen[0]
    assert sent["model"] == get_settings().openai_model
    assert "pirate" in sent["messages"][0]["content"]
    assert sent["messages"][1] == {"role": "user", "content": "helo there"}
    assert sent["max_completion_tokens"] == get_settings().openai_max_output_tokens


def test_upstream_error_and_empty_reply(with_key):
    with pytest.raises(rewriter.RewriteFailed):
        rewriter.rewrite("hi", "poem", client=fake_openai(status=500))
    with pytest.raises(rewriter.RewriteFailed):
        rewriter.rewrite("hi", "poem", client=fake_openai(reply="   "))


def test_rejects_unknown_style(with_key):
    with pytest.raises(ValueError):
        rewriter.rewrite("hi", "klingon", client=fake_openai())


def test_endpoints(client, with_key, monkeypatch):
    feats = client.get("/v1/features").json()
    assert feats["ai_rewrite"] is True
    assert {"id": "poem", "label": "Rhyming poem"} in feats["styles"]

    monkeypatch.setattr(
        rewriter, "rewrite", lambda text, style: rewriter.Rewrite("Arr!", style, "m", 7)
    )
    ok = client.post("/v1/rewrite", json={"text": "hello", "style": "pirate"})
    assert ok.json() == {"text": "Arr!", "style": "pirate", "model": "m"}

    assert client.post("/v1/rewrite", json={"text": "x", "style": "nope"}).status_code == 422
    too_long = "a" * (get_settings().rewrite_max_chars + 1)
    assert client.post("/v1/rewrite", json={"text": too_long, "style": "poem"}).status_code == 422
    assert "lexicheck_ai_tokens_total" in client.get("/metrics").text


def test_endpoint_returns_503_without_key(client, monkeypatch):
    monkeypatch.setattr(get_settings(), "openai_api_key", None)
    assert client.get("/v1/features").json()["ai_rewrite"] is False
    assert client.post("/v1/rewrite", json={"text": "hi", "style": "poem"}).status_code == 503
