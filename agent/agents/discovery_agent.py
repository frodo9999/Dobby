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


async def discover(query: str) -> dict:
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
            "summary": "家中没有找到相关物品。",
            "items": [],
            "suggestion": "可以考虑添加物品到您的库存",
        }

    # Step 5: Build Gemini prompt
    candidates = _format_candidates(search_results)
    candidates_json = json.dumps(candidates, ensure_ascii=False)

    prompt = f"""你是一个智能家庭库存助手。

用户的问题是："{query}"

以下是家庭库存中的候选物品（JSON格式，每项包含名称、分类、数量、位置和到期日）：
{candidates_json}

请根据用户的问题，从上面的物品中找出相关的物品。你需要：
1. 理解用户的意图（例如："有吃的吗" = 寻找食品；"有什么可以喝的" = 寻找饮品）
2. 找出完全匹配（exact）、可替代（substitute）、或能满足用户需求的相关物品（related）
3. 对于到期日查询（如"快过期的"），根据 expiryDate 字段判断
4. 忽略与用户需求无关的物品
5. 不要编造不在候选列表中的物品
6. location 字段直接使用候选列表中的值，不要修改

以 JSON 格式返回：
{{
  "query": "用户的问题",
  "found": true或false,
  "summary": "一句话总结回答",
  "items": [
    {{
      "name": "物品名称",
      "category": "分类",
      "quantity": 数量,
      "location": "直接使用候选列表中的location值",
      "matchType": "exact 或 substitute 或 related",
      "reason": "为什么推荐这个物品"
    }}
  ],
  "suggestion": "如果没有找到，建议用户添加的物品（找到时可省略此字段）"
}}

只返回 JSON，不要其他文字，不要 markdown 代码块。"""

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
