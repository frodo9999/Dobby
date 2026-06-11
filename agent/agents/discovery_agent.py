import json
from services.elastic_service import search_items, fetch_all_items
from services.gemini_service import call_gemini_text


def _format_candidates(raw_items: list[dict]) -> list[dict]:
    """
    Project Elastic documents into the minimal fields needed by Gemini.
    Pre-formats the location string as "房间 · 柜子" so Gemini can copy it
    directly into its response without reformatting.
    Excludes internal fields (_id, score, cabinet_id, etc.).
    """
    result = []
    for item in raw_items:
        room = item.get("room_name", "")
        cabinet = item.get("cabinet_name", "")
        location = f"{room} · {cabinet}" if room and cabinet else room or cabinet or "未知位置"
        result.append({
            "name": item.get("name", ""),
            "category": item.get("category", ""),
            "quantity": item.get("quantity", 0),
            "location": location,
            "expiryDate": item.get("expiryDate"),
        })
    return result


async def discover(query: str, language: str = "en") -> dict:
    """
    Multi-step reasoning agent:
    Step 1 — Validate query
    Step 2 — Elastic keyword search (fast path)
    Step 3 — Full inventory fallback if Elastic returns nothing (intent/substitute queries)
    Step 4 — If inventory is empty, return not-found immediately (no Gemini call)
    Step 5 — Build Gemini prompt with pre-formatted candidates
    Step 6 — Parse and validate Gemini response
    Step 7 — Return response
    """

    # Step 1: Validate
    if not query or not query.strip():
        raise ValueError("Query must not be empty")

    # Step 2: Elastic keyword search
    search_results = search_items(query, top_k=10)

    # Step 3: Full inventory fallback
    if not search_results:
        search_results = fetch_all_items(top_k=50)

    # Step 4: Empty inventory — no Gemini call needed
    if not search_results:
        return {
            "query": query,
            "found": False,
            "summary": "家中没有找到相关物品。" if language == "zh" else "No matching items found in your inventory.",
            "items": [],
            "suggestion": "可以考虑添加物品到您的库存。" if language == "zh" else "Consider adding items to your inventory.",
        }

    # Step 5: Build Gemini prompt
    candidates = _format_candidates(search_results)
    candidates_json = json.dumps(candidates, ensure_ascii=False)

    if language == "zh":
        prompt = f"""你是一个智能家庭库存助手。

用户的问题是："{query}"

以下是家庭库存中的候选物品（JSON格式，包含名称、类别、数量、位置和保质期）：
{candidates_json}

根据用户的问题，从上方列表中找出相关物品。你必须：
1. 理解用户的意图（例如"有什么吃的？"= 寻找食品；"有什么喝的？"= 寻找饮料）
2. 找出完全匹配（exact）、替代品（substitute）或满足用户需求的相关物品（related）
3. 对于保质期查询（例如"快过期的"），使用expiryDate字段判断相关性
4. 忽略与用户需求无关的物品
5. 不要编造候选列表中没有的物品
6. 直接使用候选列表中的location值，不要修改
7. 用中文回答，物品名称保持原样

返回以下格式的JSON：
{{
  "query": "用户的问题",
  "found": true或false,
  "summary": "一句话中文回答",
  "items": [
    {{
      "name": "物品名称",
      "category": "类别",
      "quantity": 数量,
      "location": "直接使用候选列表中的location值",
      "matchType": "exact或substitute或related",
      "reason": "推荐该物品的原因（中文）"
    }}
  ],
  "suggestion": "如果没有找到，建议添加什么物品（如果找到了则省略此字段）"
}}

只返回JSON，不要其他文字，不要markdown代码块。"""
    else:
        prompt = f"""You are a smart home inventory assistant.

The user's question is: "{query}"

Below are candidate items from the home inventory (JSON format, each with name, category, quantity, location, and expiry date):
{candidates_json}

Based on the user's question, find the relevant items from the list above. You must:
1. Understand the user's intent (e.g. "any food to eat?" = looking for food; "what can I drink?" = looking for beverages)
2. Find items that are an exact match (exact), a substitute (substitute), or otherwise satisfy the user's need (related)
3. For expiry queries (e.g. "expiring soon"), use the expiryDate field to determine relevance
4. Ignore items unrelated to the user's need
5. Do NOT invent items not present in the candidate list
6. Use the location value directly from the candidate list without modification
7. Respond entirely in English — item names may remain as-is if they are proper nouns

Return JSON in this exact format:
{{
  "query": "the user's question",
  "found": true or false,
  "summary": "one-sentence answer in English",
  "items": [
    {{
      "name": "item name",
      "category": "category",
      "quantity": number,
      "location": "use the location value from the candidate list directly",
      "matchType": "exact or substitute or related",
      "reason": "why this item is recommended, in English"
    }}
  ],
  "suggestion": "if nothing found, suggest what to add (omit this field if items were found)"
}}

Return only JSON, no other text, no markdown code blocks."""

    # Step 6: Call Gemini and parse response
    text = await call_gemini_text(prompt)
    try:
        result = json.loads(text)
    except (json.JSONDecodeError, ValueError) as e:
        raise ValueError(f"Gemini returned invalid response: {e}") from e

    # Step 7: Normalise and return
    # Ensure `items` always exists (Gemini sometimes omits it on not-found responses)
    result.setdefault("items", [])
    return result
