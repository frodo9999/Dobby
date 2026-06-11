import json
from services.mongo_service import get_all_cabinets, get_items_in_cabinet
from services.gemini_service import ItemDraft, call_gemini_text


async def plan_placement(items: list[ItemDraft], language: str = "en") -> list[dict]:
    """
    Multi-step reasoning agent:
    Step 1 — Fetch all cabinets from MongoDB
    Step 2 — Build exact-match index from existing items
    Step 3 — Split items into exact-match bucket and Gemini bucket
    Step 4 — Call Gemini only for items with no exact match
    Step 5 — Merge results; exact-match entries override with confidence 1.0
    Step 6 — Return merged plan (one entry per input item, same order)
    """

    # Early return for empty input
    if not items:
        return []

    # Step 1: Fetch cabinets via MongoDB MCP server
    cabinets = await get_all_cabinets()
    if not cabinets:
        raise ValueError("No cabinets found in inventory")

    # Step 2: Build exact-match index {item_name_lower → cabinet}
    exact_match_index: dict[str, dict] = {}
    for cabinet in cabinets:
        for existing in get_items_in_cabinet(cabinet["_id"]):
            key = existing["name"].strip().lower()
            exact_match_index[key] = cabinet

    # Step 3: Split into two buckets
    exact_bucket: dict[str, dict] = {}   # itemName → cabinet
    gemini_bucket: list[ItemDraft] = []

    for item in items:
        key = item.name.strip().lower()
        if key in exact_match_index:
            exact_bucket[item.name] = exact_match_index[key]
        else:
            gemini_bucket.append(item)

    # Step 4: Gemini reasoning for unmatched items
    gemini_results: list[dict] = []
    if gemini_bucket:
        cabinet_context = json.dumps([{
            "id": c["_id"],
            "name": c["name"],
            "room": c["room_name"],
            "contentSummary": c.get("contentSummary", ""),
        } for c in cabinets], ensure_ascii=False)

        items_context = json.dumps([{
            "name": item.name,
            "category": item.category,
            "quantity": item.quantity,
        } for item in gemini_bucket], ensure_ascii=False)

        if language == "zh":
            prompt = f"""你是一个智能家庭库存管理助手。

以下是家中所有柜子的信息（JSON格式）：
{cabinet_context}

以下是需要存放的新物品（JSON格式）：
{items_context}

请为每件物品推荐最合适的柜子。规则：
1. 选择contentSummary与物品类别和名称语义最相近的柜子
2. 每件物品都必须分配到一个柜子

返回JSON数组，每个元素包含：
{{
  "itemName": "物品名称",
  "recommendedCabinetId": "柜子id",
  "cabinetName": "柜子名称",
  "roomName": "房间名称",
  "reason": "一句话说明推荐原因（中文）",
  "confidence": 0.0到1.0的置信度分数
}}

只返回JSON数组，不要其他文字，不要markdown代码块。"""
        else:
            prompt = f"""You are a smart home inventory management assistant.

Below is information about all cabinets in the home (JSON format):
{cabinet_context}

Below are the new items that need to be stored (JSON format):
{items_context}

Recommend the most suitable cabinet for each item. Rules:
1. Choose the cabinet whose contentSummary is most semantically similar to the item's category and name
2. Every item must be assigned to a cabinet

Return a JSON array where each element contains:
{{
  "itemName": "item name",
  "recommendedCabinetId": "cabinet id",
  "cabinetName": "cabinet name",
  "roomName": "room name",
  "reason": "one-sentence reason for the recommendation, in English",
  "confidence": confidence score from 0.0 to 1.0
}}

Return only the JSON array, no other text, no markdown code blocks."""

        text = await call_gemini_text(prompt)
        try:
            gemini_results = json.loads(text)
        except (json.JSONDecodeError, ValueError) as e:
            raise ValueError(f"Gemini returned invalid response: {e}") from e

    # Step 5: Merge — build result indexed by itemName for easy lookup
    gemini_map: dict[str, dict] = {r["itemName"]: r for r in gemini_results}

    plan: list[dict] = []
    for item in items:
        if item.name in exact_bucket:
            cabinet = exact_bucket[item.name]
            plan.append({
                "itemName": item.name,
                "recommendedCabinetId": cabinet["_id"],
                "cabinetName": cabinet["name"],
                "roomName": cabinet.get("room_name", ""),
                "reason": "该柜子里已有相同物品。" if language == "zh" else "This cabinet already contains the same item.",
                "confidence": 1.0,
            })
        elif item.name in gemini_map:
            plan.append(gemini_map[item.name])
        else:
            # Fallback: Gemini didn't return an entry for this item — use first cabinet
            fallback = cabinets[0]
            plan.append({
                "itemName": item.name,
                "recommendedCabinetId": fallback["_id"],
                "cabinetName": fallback["name"],
                "roomName": fallback.get("room_name", ""),
                "reason": "未能确定最佳位置，已分配到默认柜子。" if language == "zh" else "Could not determine best location; assigned to default cabinet.",
                "confidence": 0.1,
            })

    return plan
