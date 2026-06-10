"""
Unit tests for agents/intake_agent.py

All external dependencies (MongoDB, Gemini) are mocked.
Tests follow the spec in AI/Tasks/agent-smart-intake.md.
"""
import json
import pytest
from unittest.mock import patch, MagicMock, AsyncMock

from services.gemini_service import ItemDraft


# ---------------------------------------------------------------------------
# Helpers — minimal stub data
# ---------------------------------------------------------------------------

CABINET_FRIDGE = {
    "_id": "cab_fridge",
    "name": "冰箱",
    "room_name": "厨房",
    "contentSummary": "食品类物品",  # deliberately no item names, to keep prompt assertions clean
}

CABINET_MEDICINE = {
    "_id": "cab_medicine",
    "name": "药品柜",
    "room_name": "浴室",
    "contentSummary": "药品: 感冒灵, 维生素C",
}

ITEM_MILK = {"name": "牛奶", "cabinet_id": "cab_fridge"}
ITEM_EGGS = {"name": "鸡蛋", "cabinet_id": "cab_fridge"}

GEMINI_PLAN_RESPONSE = json.dumps([
    {
        "itemName": "洗发水",
        "recommendedCabinetId": "cab_medicine",
        "cabinetName": "药品柜",
        "roomName": "浴室",
        "reason": "药品柜存放个人护理用品",
        "confidence": 0.75,
    }
])


def _make_items(*names) -> list[ItemDraft]:
    return [ItemDraft(name=n, category="食品", quantity=1) for n in names]


# ---------------------------------------------------------------------------
# Test 1: Exact match returns confidence 1.0 without calling Gemini
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_exact_match_returns_confidence_1_without_gemini():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[ITEM_MILK]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock) as mock_gemini:

        from agents.intake_agent import plan_placement
        result = await plan_placement(_make_items("牛奶"))

    mock_gemini.assert_not_called()
    assert len(result) == 1
    assert result[0]["confidence"] == 1.0
    assert result[0]["cabinetName"] == "冰箱"
    assert "已有相同物品" in result[0]["reason"]


# ---------------------------------------------------------------------------
# Test 2: Unmatched item calls Gemini exactly once
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unmatched_item_calls_gemini():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE, CABINET_MEDICINE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[ITEM_MILK]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=GEMINI_PLAN_RESPONSE) as mock_gemini:

        from agents.intake_agent import plan_placement
        await plan_placement(_make_items("洗发水"))

    mock_gemini.assert_called_once()


# ---------------------------------------------------------------------------
# Test 3: Mixed items — Gemini called only for unmatched items
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_mixed_items_gemini_called_only_for_unmatched():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE, CABINET_MEDICINE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[ITEM_MILK]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=GEMINI_PLAN_RESPONSE) as mock_gemini:

        from agents.intake_agent import plan_placement
        result = await plan_placement(_make_items("牛奶", "洗发水"))

    mock_gemini.assert_called_once()
    # The prompt should NOT mention 牛奶 (already matched)
    prompt_sent = mock_gemini.call_args[0][0]
    assert "洗发水" in prompt_sent
    assert "牛奶" not in prompt_sent


# ---------------------------------------------------------------------------
# Test 4: All required fields present in each plan entry
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_all_required_fields_present_in_plan_entry():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[ITEM_MILK]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock):

        from agents.intake_agent import plan_placement
        result = await plan_placement(_make_items("牛奶"))

    required = {"itemName", "recommendedCabinetId", "cabinetName", "roomName", "reason", "confidence"}
    for entry in result:
        assert required.issubset(entry.keys()), f"Missing fields: {required - entry.keys()}"


# ---------------------------------------------------------------------------
# Test 5: Empty item list returns empty plan without errors
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_empty_item_list_returns_empty_plan():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock) as mock_gemini:

        from agents.intake_agent import plan_placement
        result = await plan_placement([])

    assert result == []
    mock_gemini.assert_not_called()


# ---------------------------------------------------------------------------
# Test 6: No cabinets raises ValueError
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_no_cabinets_raises_value_error():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[]):

        from agents.intake_agent import plan_placement
        with pytest.raises(ValueError, match="No cabinets"):
            await plan_placement(_make_items("牛奶"))


# ---------------------------------------------------------------------------
# Test 7: Invalid Gemini JSON raises ValueError
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_invalid_gemini_json_raises_value_error():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock,
               return_value="这不是 JSON"):

        from agents.intake_agent import plan_placement
        with pytest.raises(ValueError, match="invalid response"):
            await plan_placement(_make_items("洗发水"))


# ---------------------------------------------------------------------------
# Test 8: All confidence values are in [0.0, 1.0]
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_confidence_values_in_valid_range():
    gemini_response = json.dumps([
        {"itemName": "洗发水", "recommendedCabinetId": "cab_medicine",
         "cabinetName": "药品柜", "roomName": "浴室",
         "reason": "适合", "confidence": 0.8},
    ])
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE, CABINET_MEDICINE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=gemini_response):

        from agents.intake_agent import plan_placement
        result = await plan_placement(_make_items("牛奶", "洗发水"))

    for entry in result:
        assert 0.0 <= entry["confidence"] <= 1.0, \
            f"Confidence out of range: {entry['confidence']}"


# ---------------------------------------------------------------------------
# Test 9: Every input item appears exactly once in output
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_every_input_item_appears_in_output():
    gemini_response = json.dumps([
        {"itemName": "洗发水", "recommendedCabinetId": "cab_medicine",
         "cabinetName": "药品柜", "roomName": "浴室", "reason": "适合", "confidence": 0.7},
        {"itemName": "面包", "recommendedCabinetId": "cab_fridge",
         "cabinetName": "冰箱", "roomName": "厨房", "reason": "食品", "confidence": 0.9},
    ])
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE, CABINET_MEDICINE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[ITEM_MILK]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=gemini_response):

        from agents.intake_agent import plan_placement
        items = _make_items("牛奶", "洗发水", "面包")
        result = await plan_placement(items)

    assert len(result) == 3
    output_names = {r["itemName"] for r in result}
    assert output_names == {"牛奶", "洗发水", "面包"}


# ---------------------------------------------------------------------------
# Test 10: Gemini prompt must not contain raw MongoDB _id strings
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gemini_prompt_excludes_mongodb_ids():
    with patch("agents.intake_agent.get_all_cabinets", return_value=[CABINET_FRIDGE]), \
         patch("agents.intake_agent.get_items_in_cabinet", return_value=[]), \
         patch("agents.intake_agent.call_gemini_text", new_callable=AsyncMock,
               return_value=GEMINI_PLAN_RESPONSE) as mock_gemini:

        from agents.intake_agent import plan_placement
        await plan_placement(_make_items("洗发水"))

    prompt = mock_gemini.call_args[0][0]
    assert "ObjectId" not in prompt
    assert "$oid" not in prompt
