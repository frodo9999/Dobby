"""
Unit tests for agents/discovery_agent.py

All external dependencies (Elastic, Gemini) are mocked.
Tests follow the spec in AI/Tasks/agent-inventory-discovery.md.
"""
import json
import pytest
from unittest.mock import patch, AsyncMock


# ---------------------------------------------------------------------------
# Helpers — minimal stub data
# ---------------------------------------------------------------------------

ELASTIC_MILK = {
    "name": "牛奶", "category": "食品", "quantity": 2,
    "cabinet_name": "冰箱", "room_name": "厨房",
    "expiryDate": "2026-07-09", "score": 3.5,
}

ELASTIC_EGGS = {
    "name": "鸡蛋", "category": "食品", "quantity": 12,
    "cabinet_name": "冰箱", "room_name": "厨房",
    "expiryDate": "2026-06-20", "score": 2.1,
}

FOUND_GEMINI_RESPONSE = json.dumps({
    "query": "牛奶",
    "found": True,
    "summary": "找到了牛奶。",
    "items": [
        {
            "name": "牛奶",
            "category": "食品",
            "quantity": 2,
            "location": "厨房 · 冰箱",
            "matchType": "exact",
            "reason": "完全匹配",
        }
    ],
})

NOT_FOUND_GEMINI_RESPONSE = json.dumps({
    "query": "洗碗机",
    "found": False,
    "summary": "家中没有洗碗机。",
    "items": [],
    "suggestion": "可以考虑购买洗碗机",
})

INTENT_GEMINI_RESPONSE = json.dumps({
    "query": "有吃的吗",
    "found": True,
    "summary": "家里有牛奶和鸡蛋。",
    "items": [
        {"name": "牛奶", "category": "食品", "quantity": 2,
         "location": "厨房 · 冰箱", "matchType": "related", "reason": "食品"},
        {"name": "鸡蛋", "category": "食品", "quantity": 12,
         "location": "厨房 · 冰箱", "matchType": "related", "reason": "食品"},
    ],
})


# ---------------------------------------------------------------------------
# Test 1: Empty query raises ValueError without calling Elastic or Gemini
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_empty_query_raises_value_error():
    with patch("agents.discovery_agent.search_items") as mock_elastic, \
         patch("agents.discovery_agent.fetch_all_items") as mock_all, \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock) as mock_gemini:

        from agents.discovery_agent import discover
        with pytest.raises(ValueError, match="empty"):
            await discover("")

    mock_elastic.assert_not_called()
    mock_all.assert_not_called()
    mock_gemini.assert_not_called()


# ---------------------------------------------------------------------------
# Test 2: Direct query uses Elastic results — fetch_all_items NOT called
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_direct_query_uses_elastic_results():
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items") as mock_all, \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=FOUND_GEMINI_RESPONSE):

        from agents.discovery_agent import discover
        await discover("牛奶")

    mock_all.assert_not_called()


# ---------------------------------------------------------------------------
# Test 3: Intent query falls back to full inventory when Elastic returns empty
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_intent_query_falls_back_to_full_inventory():
    with patch("agents.discovery_agent.search_items", return_value=[]), \
         patch("agents.discovery_agent.fetch_all_items",
               return_value=[ELASTIC_MILK, ELASTIC_EGGS]) as mock_all, \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=INTENT_GEMINI_RESPONSE):

        from agents.discovery_agent import discover
        await discover("有吃的吗")

    mock_all.assert_called_once()


# ---------------------------------------------------------------------------
# Test 4: Empty inventory returns not-found without calling Gemini
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_empty_inventory_returns_not_found_without_gemini():
    with patch("agents.discovery_agent.search_items", return_value=[]), \
         patch("agents.discovery_agent.fetch_all_items", return_value=[]), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock) as mock_gemini:

        from agents.discovery_agent import discover
        result = await discover("牛奶")

    mock_gemini.assert_not_called()
    assert result["found"] is False


# ---------------------------------------------------------------------------
# Test 5: Gemini is called exactly once per request (both paths)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gemini_called_exactly_once_for_direct_query():
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=FOUND_GEMINI_RESPONSE) as mock_gemini:

        from agents.discovery_agent import discover
        await discover("牛奶")

    mock_gemini.assert_called_once()


@pytest.mark.asyncio
async def test_gemini_called_exactly_once_for_fallback_query():
    with patch("agents.discovery_agent.search_items", return_value=[]), \
         patch("agents.discovery_agent.fetch_all_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=INTENT_GEMINI_RESPONSE) as mock_gemini:

        from agents.discovery_agent import discover
        await discover("有吃的吗")

    mock_gemini.assert_called_once()


# ---------------------------------------------------------------------------
# Test 6: Gemini prompt does not contain MongoDB _id fields
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gemini_prompt_excludes_mongo_id():
    item_with_id = {**ELASTIC_MILK, "_id": "507f1f77bcf86cd799439011"}
    with patch("agents.discovery_agent.search_items", return_value=[item_with_id]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=FOUND_GEMINI_RESPONSE) as mock_gemini:

        from agents.discovery_agent import discover
        await discover("牛奶")

    prompt = mock_gemini.call_args[0][0]
    assert "_id" not in prompt
    assert "507f1f77bcf86cd799439011" not in prompt


# ---------------------------------------------------------------------------
# Test 7: Gemini prompt includes expiryDate for each candidate item
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gemini_prompt_includes_expiry_date():
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=FOUND_GEMINI_RESPONSE) as mock_gemini:

        from agents.discovery_agent import discover
        await discover("牛奶")

    prompt = mock_gemini.call_args[0][0]
    assert "expiryDate" in prompt
    assert "2026-07-09" in prompt


# ---------------------------------------------------------------------------
# Test 8: Found response has all required fields
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_found_response_has_all_required_fields():
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=FOUND_GEMINI_RESPONSE):

        from agents.discovery_agent import discover
        result = await discover("牛奶")

    assert "query" in result
    assert "found" in result
    assert "summary" in result
    assert "items" in result
    assert len(result["items"]) > 0

    item = result["items"][0]
    for field in ("name", "category", "quantity", "location", "matchType", "reason"):
        assert field in item, f"Missing field in item: {field}"


# ---------------------------------------------------------------------------
# Test 9: Not-found response has all required fields
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_not_found_response_has_all_required_fields():
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=NOT_FOUND_GEMINI_RESPONSE):

        from agents.discovery_agent import discover
        result = await discover("洗碗机")

    assert result["found"] is False
    assert result["items"] == []
    assert "query" in result
    assert "summary" in result
    assert "suggestion" in result


# ---------------------------------------------------------------------------
# Test 10: matchType values are always one of the three valid values
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_match_type_values_are_valid():
    valid_types = {"exact", "substitute", "related"}
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK, ELASTIC_EGGS]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=INTENT_GEMINI_RESPONSE):

        from agents.discovery_agent import discover
        result = await discover("有吃的吗")

    for item in result["items"]:
        assert item["matchType"] in valid_types, \
            f"Invalid matchType: {item['matchType']}"


# ---------------------------------------------------------------------------
# Test 11: Invalid Gemini JSON raises ValueError
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_invalid_gemini_json_raises_value_error():
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value="这不是 JSON，是普通文字"):

        from agents.discovery_agent import discover
        with pytest.raises(ValueError, match="invalid response"):
            await discover("牛奶")


# ---------------------------------------------------------------------------
# Test 12: location field is formatted as "房间 · 柜子" from Elastic source data
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_location_field_formatted_correctly():
    """
    The agent assembles the location string from room_name + cabinet_name
    in the Elastic document BEFORE passing to Gemini, so Gemini always
    receives a pre-formatted location it can copy into its response.
    This test verifies the prompt contains the correctly formatted location.
    """
    with patch("agents.discovery_agent.search_items", return_value=[ELASTIC_MILK]), \
         patch("agents.discovery_agent.fetch_all_items"), \
         patch("agents.discovery_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=FOUND_GEMINI_RESPONSE) as mock_gemini:

        from agents.discovery_agent import discover
        await discover("牛奶")

    prompt = mock_gemini.call_args[0][0]
    assert "厨房 · 冰箱" in prompt
