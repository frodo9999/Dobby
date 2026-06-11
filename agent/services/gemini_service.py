import os
import base64
import json
import httpx
from pydantic import BaseModel
import google.auth
import google.auth.transport.requests

# Vertex AI endpoint for Gemini (uses ADC / service account auth)
PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "gen-lang-client-0672894527")
LOCATION = os.environ.get("GCP_LOCATION", "us-central1")
API_URL = (
    f"https://{LOCATION}-aiplatform.googleapis.com/v1/projects/{PROJECT_ID}"
    f"/locations/{LOCATION}/publishers/google/models/gemini-2.5-flash-lite:generateContent"
)


_credentials = None
_http_client: httpx.AsyncClient | None = None


async def _get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(timeout=30)
    return _http_client

def _get_access_token() -> str:
    """Get a valid OAuth2 access token via Application Default Credentials, refreshing only when needed."""
    global _credentials
    if _credentials is None:
        _credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
    auth_req = google.auth.transport.requests.Request()
    if not _credentials.valid:
        _credentials.refresh(auth_req)
    return _credentials.token


class ItemDraft(BaseModel):
    name: str
    category: str = "Other"
    quantity: int = 1
    expiryDate: str | None = None


async def _call_gemini(prompt: str, image_bytes: bytes | None = None) -> str:
    parts = []
    if image_bytes:
        parts.append({
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64.b64encode(image_bytes).decode()
            }
        })
    parts.append({"text": prompt})

    body = {"contents": [{"role": "user", "parts": parts}]}
    token = _get_access_token()

    client = await _get_http_client()
    resp = await client.post(
        API_URL,
        headers={"Authorization": f"Bearer {token}"},
        json=body
    )
    resp.raise_for_status()
    data = resp.json()

    text = data["candidates"][0]["content"]["parts"][0]["text"]
    return text.strip().removeprefix("```json").removesuffix("```").strip()


async def extract_items_from_image(image_bytes: bytes, is_receipt: bool = False, language: str = "en") -> list[ItemDraft]:
    if language == "zh":
        if is_receipt:
            prompt = """你是一个家庭库存助手。请分析这张超市收据并提取所有商品。
返回JSON数组：
[{"name": "商品名称（中文）", "category": "食品|药品|衣物|电子产品|书籍|工具|厨具|玩具|文件|其他", "quantity": 数量, "expiryDate": "YYYY-MM-DD或null"}]
只返回JSON，不要其他文字。"""
        else:
            prompt = """你是一个家庭库存助手。请分析这张照片并识别图中的物品。
返回JSON数组：
[{"name": "物品名称（中文）", "category": "食品|药品|衣物|电子产品|书籍|工具|厨具|玩具|文件|其他", "quantity": 数量, "expiryDate": "YYYY-MM-DD或null"}]
只返回JSON，不要其他文字。"""
    else:
        if is_receipt:
            prompt = """You are a home inventory assistant. Analyze this supermarket receipt and extract all items.
Return a JSON array:
[{"name": "item name", "category": "Food|Medicine|Clothing|Electronics|Books|Tools|Kitchenware|Toys|Documents|Other", "quantity": number, "expiryDate": "YYYY-MM-DD or null"}]
Return only JSON, no other text."""
        else:
            prompt = """You are a home inventory assistant. Analyze this photo and identify the item(s) shown.
Return a JSON array:
[{"name": "item name", "category": "Food|Medicine|Clothing|Electronics|Books|Tools|Kitchenware|Toys|Documents|Other", "quantity": number, "expiryDate": "YYYY-MM-DD or null"}]
Return only JSON, no other text."""

    text = await _call_gemini(prompt, image_bytes)
    raw = json.loads(text)
    if isinstance(raw, dict):
        raw = [raw]
    return [ItemDraft(**item) for item in raw]


async def call_gemini_text(prompt: str) -> str:
    """Text-only Gemini call, used by agents."""
    return await _call_gemini(prompt)
