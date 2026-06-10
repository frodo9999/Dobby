"""
Integration tests for Inventory Discovery Agent endpoint.

These tests hit the real FastAPI app via TestClient.
Elastic index must be seeded — use the `seeded` fixture from conftest.py.
"""
import pytest


# ---------------------------------------------------------------------------
# Test 1: Direct query finds seeded item
# ---------------------------------------------------------------------------

def test_direct_query_finds_seeded_item(client, seeded):
    resp = client.post("/discovery", json={"query": "牛奶"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["found"] is True
    names = [item["name"] for item in body["items"]]
    assert "牛奶" in names


# ---------------------------------------------------------------------------
# Test 2: Empty query returns 422
# ---------------------------------------------------------------------------

def test_empty_query_returns_422(client):
    resp = client.post("/discovery", json={"query": ""})
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Test 3: Response schema is consistent for found and not-found cases
# ---------------------------------------------------------------------------

def test_response_schema_consistent_when_found(client, seeded):
    resp = client.post("/discovery", json={"query": "牛奶"})
    assert resp.status_code == 200
    body = resp.json()
    for key in ("query", "found", "summary", "items"):
        assert key in body, f"Missing top-level key: {key}"


def test_response_schema_consistent_when_not_found(client, seeded):
    resp = client.post("/discovery", json={"query": "一个不存在的非常奇怪的物品名称xyz"})
    assert resp.status_code == 200
    body = resp.json()
    for key in ("query", "found", "summary", "items"):
        assert key in body, f"Missing top-level key: {key}"
    # Not-found responses must have an empty items list
    if not body["found"]:
        assert body["items"] == []
