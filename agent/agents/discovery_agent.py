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
            "summary": "No matching items found in your inventory.",
            "items": [],
            "suggestion": "Consider adding items to your inventory.",
        }

    # Step 5: Build Gemini prompt
    candidates = _format_candidates(search_results)
    candidates_json = json.dumps(candidates, ensure_ascii=False)

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
