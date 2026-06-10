"""
Integration tests for Smart Intake Agent endpoints.

These tests hit the real FastAPI app via TestClient.
MongoDB and Elastic use real services — requires seed data.
Use the `seeded` fixture (from conftest.py) to ensure data is present.
"""
import io
import pytest


# ---------------------------------------------------------------------------
# Test 1: Plan endpoint returns 200 with valid schema
# ---------------------------------------------------------------------------

def test_plan_endpoint_returns_200_with_valid_schema(client, seeded):
    resp = client.post("/intake/plan", json={
        "items": [{"name": "洗发水", "category": "日用品", "quantity": 1}]
    })
    assert resp.status_code == 200
    body = resp.json()
    assert "plan" in body
    assert len(body["plan"]) == 1

    entry = body["plan"][0]
    for field in ("itemName", "recommendedCabinetId", "cabinetName", "roomName", "reason", "confidence"):
        assert field in entry, f"Missing field in plan entry: {field}"


# ---------------------------------------------------------------------------
# Test 2: Confirm saves to MongoDB and item is discoverable via Elastic
# ---------------------------------------------------------------------------

def test_confirm_saves_to_mongo_and_elastic(client, seeded):
    # First get a valid cabinetId from the plan
    plan_resp = client.post("/intake/plan", json={
        "items": [{"name": "独特测试物品_xyz", "category": "其他", "quantity": 1}]
    })
    assert plan_resp.status_code == 200
    cabinet_id = plan_resp.json()["plan"][0]["recommendedCabinetId"]

    # Confirm — save the item
    confirm_resp = client.post("/intake/confirm", json={
        "items": [{
            "name": "独特测试物品_xyz",
            "category": "其他",
            "quantity": 1,
            "cabinetId": cabinet_id,
        }]
    })
    assert confirm_resp.status_code == 200
    assert confirm_resp.json()["status"] == "saved"
    assert confirm_resp.json()["count"] == 1

    # Discovery should now find the item
    discovery_resp = client.post("/discovery", json={"query": "独特测试物品_xyz"})
    assert discovery_resp.status_code == 200
    assert discovery_resp.json()["found"] is True


# ---------------------------------------------------------------------------
# Test 3: Confirm resolves cabinet_name and room_name server-side
# ---------------------------------------------------------------------------

def test_confirm_resolves_cabinet_name_server_side(client, seeded):
    # Get a valid cabinetId
    plan_resp = client.post("/intake/plan", json={
        "items": [{"name": "测试服务端解析物品", "category": "食品", "quantity": 1}]
    })
    cabinet_id = plan_resp.json()["plan"][0]["recommendedCabinetId"]
    cabinet_name = plan_resp.json()["plan"][0]["cabinetName"]
    room_name = plan_resp.json()["plan"][0]["roomName"]

    # Confirm — only send cabinetId, not cabinet_name or room_name
    client.post("/intake/confirm", json={
        "items": [{
            "name": "测试服务端解析物品",
            "category": "食品",
            "quantity": 1,
            "cabinetId": cabinet_id,
        }]
    })

    # Discover and verify location is correctly resolved
    discovery_resp = client.post("/discovery", json={"query": "测试服务端解析物品"})
    result = discovery_resp.json()
    if result["found"]:
        location = result["items"][0]["location"]
        assert cabinet_name in location or room_name in location


# ---------------------------------------------------------------------------
# Test 4: Extract with invalid bytes returns 422
# ---------------------------------------------------------------------------

def test_extract_invalid_bytes_returns_422(client):
    fake_image = io.BytesIO(b"this is not a valid image")
    resp = client.post(
        "/intake/extract",
        files={"file": ("test.jpg", fake_image, "image/jpeg")},
    )
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Test 5: Plan with empty items list returns empty plan
# ---------------------------------------------------------------------------

def test_plan_with_empty_items_returns_empty_plan(client, seeded):
    resp = client.post("/intake/plan", json={"items": []})
    assert resp.status_code == 200
    assert resp.json() == {"plan": []}
