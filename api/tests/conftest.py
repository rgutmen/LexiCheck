import os

# Tests never hit a real database or OpenAI.
os.environ["LEXI_DATABASE_URL"] = "sqlite:///./test.db"
os.environ.pop("OPENAI_API_KEY", None)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from lexicheck.main import app  # noqa: E402


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c
    if os.path.exists("test.db"):
        os.remove("test.db")
