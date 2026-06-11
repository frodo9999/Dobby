from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

from services.gemini_service import extract_items_from_image
from services.mongo_service import seed_sample_inventory, get_all_cabinets, insert_items
from services.elastic_service import sync_from_mongo, reset_index
from agents.intake_agent import plan_placement
from agents.discovery_agent import discover

app = FastAPI(title="Dobby Agent API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health / Index
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {"status": "ok", "service": "Dobby Agent API"}


@app.get("/")
def index():
    # Locally: web/ is one level up. In Docker: web/ is copied into /app/web/
    import os
    candidates = ["web/index.html", "../web/index.html"]
    for path in candidates:
        if os.path.exists(path):
            return FileResponse(path)
    return {"error": "UI not found"}


# ---------------------------------------------------------------------------
# Setup / Seed
# ---------------------------------------------------------------------------

@app.post("/admin/seed")
def seed():
    """Seed MongoDB with sample inventory and sync to Elastic."""
    seed_sample_inventory()
    reset_index()  # wipe Elastic before re-indexing to avoid duplicates
    from services.mongo_service import get_db
    from bson import ObjectId
    db = get_db()
    items = list(db.items.find({}))
    for item in items:
        item["_id"] = str(item["_id"])
        cab_id = item.get("cabinet_id")
        if cab_id:
            cab = db.cabinets.find_one({"_id": cab_id})
            if cab:
                item["cabinet_name"] = cab.get("name", "")
                item["cabinet_id"] = str(cab["_id"])
                room = db.rooms.find_one({"_id": cab.get("room_id")})
                item["room_name"] = room["name"] if room else ""
    sync_from_mongo(items)
    return {"status": "seeded", "items": len(items)}


# ---------------------------------------------------------------------------
# Smart Intake Agent
# ---------------------------------------------------------------------------

@app.post("/intake/extract")
async def intake_extract(
    file: UploadFile = File(...),
    is_receipt: bool = False,
    language: str = "en",
):
    """Step 1: Extract item drafts from a photo or receipt using Gemini Vision."""
    image_bytes = await file.read()
    try:
        items = await extract_items_from_image(image_bytes, is_receipt=is_receipt, language=language)
        if not items:
            raise HTTPException(status_code=422, detail="Could not extract items from image")
        return {"items": [item.model_dump() for item in items]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=422, detail="Could not extract items from image") from e


@app.post("/intake/plan")
async def intake_plan(payload: dict):
    """Step 2: Agent reasons over MongoDB inventory to produce a placement plan."""
    from services.gemini_service import ItemDraft
    raw_items = payload.get("items", [])
    language = payload.get("language", "en")
    items = [ItemDraft(**i) for i in raw_items]

    # Empty list is valid — return empty plan
    if not items:
        return {"plan": []}

    try:
        plan = await plan_placement(items, language=language)
        return {"plan": plan}
    except ValueError as e:
        msg = str(e)
        if "No cabinets" in msg:
            raise HTTPException(status_code=422, detail=msg)
        raise HTTPException(status_code=500, detail=msg)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/intake/confirm")
async def intake_confirm(payload: dict):
    """Step 3: User confirmed placement — persist items to MongoDB and re-sync Elastic."""
    items = payload.get("items", [])
    if not items:
        raise HTTPException(status_code=400, detail="No items provided")

    # Normalise camelCase cabinetId → snake_case cabinet_id
    for item in items:
        if "cabinetId" in item and "cabinet_id" not in item:
            item["cabinet_id"] = item.pop("cabinetId")

    count = insert_items(items)

    # Re-sync Elastic with cabinet/room names resolved server-side
    from services.mongo_service import get_db
    from bson import ObjectId
    db = get_db()
    all_items = list(db.items.find({}))
    for item in all_items:
        item["_id"] = str(item["_id"])
        cab_id = item.get("cabinet_id")
        cab = db.cabinets.find_one(
            {"_id": ObjectId(cab_id) if isinstance(cab_id, str) else cab_id}
        )
        if cab:
            item["cabinet_name"] = cab.get("name", "")
            item["cabinet_id"] = str(cab["_id"])
            room = db.rooms.find_one({"_id": cab.get("room_id")})
            item["room_name"] = room["name"] if room else ""

    sync_from_mongo(all_items)
    return {"status": "saved", "count": count}


# ---------------------------------------------------------------------------
# Inventory Discovery Agent
# ---------------------------------------------------------------------------

class DiscoveryRequest(BaseModel):
    query: str
    language: str = "en"


@app.post("/discovery")
async def inventory_discovery(request: DiscoveryRequest):
    """Natural language query → Elastic search → Gemini reasoning → structured response."""
    if not request.query or not request.query.strip():
        raise HTTPException(status_code=422, detail="Query must not be empty")
    try:
        result = await discover(request.query, language=request.language)
        return result
    except ValueError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
