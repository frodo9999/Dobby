"""
Shared fixtures for all test modules.
Integration tests that need seeded data import `seeded_elastic` fixture.
"""
import pytest
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# App client
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def client():
    """FastAPI TestClient — session-scoped so the app starts once per test run."""
    from dotenv import load_dotenv
    load_dotenv()
    from main import app
    with TestClient(app) as c:
        yield c


# ---------------------------------------------------------------------------
# Seed fixture for integration tests
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def seeded(client):
    """Ensure MongoDB + Elastic are seeded before integration tests run."""
    resp = client.post("/admin/seed")
    assert resp.status_code == 200, f"Seed failed: {resp.text}"
    yield
