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

    reset_index()
    sync_from_mongo(all_items)
    return {"status": "saved", "count": count}


# ---------------------------------------------------------------------------
# Manual Sync (iOS manual add / edit / delete)
# ---------------------------------------------------------------------------

class SyncItemRequest(BaseModel):
    name: str
    category: str = ""
    quantity: int = 1
    notes: str = ""
    expiryDate: str = ""       # ISO date string "YYYY-MM-DD" or ""
    cabinetName: str = ""
    roomName: str = ""
    oldName: str = ""          # for edits: the original name before rename


@app.post("/items/sync")
async def sync_item(req: SyncItemRequest):
    """Upsert a single item from iOS manual add/edit. Looks up cabinet by name+room."""
    from services.mongo_service import get_db
    from services.elastic_service import sync_from_mongo
    from bson import ObjectId

    db = get_db()

    # Find cabinet by name + room name
    room = db.rooms.find_one({"name": req.roomName})
    if not room:
        raise HTTPException(status_code=404, detail=f"Room not found: {req.roomName}")
    cabinet = db.cabinets.find_one({"name": req.cabinetName, "room_id": room["_id"]})
    if not cabinet:
        raise HTTPException(status_code=404, detail=f"Cabinet not found: {req.cabinetName}")

    doc = {
        "name": req.name,
        "category": req.category,
        "quantity": req.quantity,
        "notes": req.notes,
        "cabinet_id": cabinet["_id"],
    }
    if req.expiryDate:
        doc["expiryDate"] = req.expiryDate

    # Use oldName for edit lookups (rename case), otherwise use current name
    import re
    lookup_name = req.oldName if req.oldName else req.name
    existing = db.items.find_one({
        "name": {"$regex": f"^{re.escape(lookup_name)}$", "$options": "i"},
        "cabinet_id": cabinet["_id"]
    })

    if existing:
        db.items.update_one({"_id": existing["_id"]}, {"$set": doc})
    else:
        db.items.insert_one(doc)

    # Re-sync Elasticsearch
    all_items = list(db.items.find({}))
    for item in all_items:
        item["_id"] = str(item["_id"])
        cab_id = item.get("cabinet_id")
        cab = db.cabinets.find_one({"_id": ObjectId(cab_id) if isinstance(cab_id, str) else cab_id})
        if cab:
            item["cabinet_name"] = cab.get("name", "")
            item["cabinet_id"] = str(cab["_id"])
            room_doc = db.rooms.find_one({"_id": cab.get("room_id")})
            item["room_name"] = room_doc["name"] if room_doc else ""
    reset_index()
    sync_from_mongo(all_items)
    return {"status": "synced", "item": req.name}


class DeleteItemRequest(BaseModel):
    name: str
    cabinetName: str
    roomName: str


@app.delete("/items/sync")
async def delete_item(req: DeleteItemRequest):
    """Delete a single item from iOS manual delete."""
    from services.mongo_service import get_db
    from services.elastic_service import sync_from_mongo
    from bson import ObjectId

    db = get_db()

    room = db.rooms.find_one({"name": req.roomName})
    if not room:
        raise HTTPException(status_code=404, detail=f"Room not found: {req.roomName}")
    cabinet = db.cabinets.find_one({"name": req.cabinetName, "room_id": room["_id"]})
    if not cabinet:
        raise HTTPException(status_code=404, detail=f"Cabinet not found: {req.cabinetName}")

    import re
    db.items.delete_one({
        "name": {"$regex": f"^{re.escape(req.name)}$", "$options": "i"},
        "cabinet_id": cabinet["_id"]
    })

    # Re-sync Elasticsearch
    all_items = list(db.items.find({}))
    for item in all_items:
        item["_id"] = str(item["_id"])
        cab_id = item.get("cabinet_id")
        cab = db.cabinets.find_one({"_id": ObjectId(cab_id) if isinstance(cab_id, str) else cab_id})
        if cab:
            item["cabinet_name"] = cab.get("name", "")
            item["cabinet_id"] = str(cab["_id"])
            room_doc = db.rooms.find_one({"_id": cab.get("room_id")})
            item["room_name"] = room_doc["name"] if room_doc else ""
    reset_index()
    sync_from_mongo(all_items)
    return {"status": "deleted", "item": req.name}


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
