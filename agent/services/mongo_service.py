import os
import certifi
from pymongo import MongoClient
from pymongo.database import Database

_client: MongoClient | None = None

def get_db() -> Database:
    global _client
    if _client is None:
        _client = MongoClient(os.environ["MONGODB_URI"], tlsCAFile=certifi.where())
    return _client["dobby"]


# ---------------------------------------------------------------------------
# Schema helpers
# ---------------------------------------------------------------------------

def seed_sample_inventory():
    """Seed MongoDB with a sample home inventory for demo purposes."""
    db = get_db()

    # Clear existing data
    db.rooms.drop()
    db.cabinets.drop()
    db.items.drop()

    # Rooms
    kitchen = db.rooms.insert_one({"name": "Kitchen", "icon": "refrigerator"}).inserted_id
    bedroom = db.rooms.insert_one({"name": "Bedroom", "icon": "bed.double"}).inserted_id
    bathroom = db.rooms.insert_one({"name": "Bathroom", "icon": "bathtub"}).inserted_id
    living = db.rooms.insert_one({"name": "Living Room", "icon": "sofa"}).inserted_id

    # Cabinets
    fridge = db.cabinets.insert_one({
        "name": "Refrigerator", "icon": "refrigerator", "room_id": kitchen,
        "contentSummary": "Food; milk, eggs, vegetables, juice"
    }).inserted_id

    pantry = db.cabinets.insert_one({
        "name": "Pantry", "icon": "cabinet", "room_id": kitchen,
        "contentSummary": "Food; rice, pasta, condiments, snacks"
    }).inserted_id

    medicine_cabinet = db.cabinets.insert_one({
        "name": "Medicine Cabinet", "icon": "cross.case", "room_id": bathroom,
        "contentSummary": "Medicine; cold medicine, vitamins, band-aids"
    }).inserted_id

    wardrobe = db.cabinets.insert_one({
        "name": "Wardrobe", "icon": "cabinet", "room_id": bedroom,
        "contentSummary": "Clothing; t-shirts, pants, jackets"
    }).inserted_id

    bookshelf = db.cabinets.insert_one({
        "name": "Bookshelf", "icon": "books.vertical", "room_id": living,
        "contentSummary": "Books; novels, textbooks, magazines"
    }).inserted_id

    # Items
    items = [
        {"name": "Milk", "category": "Food", "quantity": 2, "cabinet_id": fridge, "expiryDate": "2026-06-15"},
        {"name": "Eggs", "category": "Food", "quantity": 12, "cabinet_id": fridge, "expiryDate": "2026-06-20"},
        {"name": "Orange Juice", "category": "Food", "quantity": 1, "cabinet_id": fridge, "expiryDate": "2026-06-18"},
        {"name": "Rice", "category": "Food", "quantity": 5, "cabinet_id": pantry},
        {"name": "Soy Sauce", "category": "Food", "quantity": 1, "cabinet_id": pantry},
        {"name": "Cold Medicine", "category": "Medicine", "quantity": 1, "cabinet_id": medicine_cabinet, "expiryDate": "2027-01-01"},
        {"name": "Vitamin C", "category": "Medicine", "quantity": 60, "cabinet_id": medicine_cabinet, "expiryDate": "2027-06-01"},
        {"name": "T-Shirt", "category": "Clothing", "quantity": 5, "cabinet_id": wardrobe},
        {"name": "Python Programming", "category": "Books", "quantity": 1, "cabinet_id": bookshelf},
    ]
    db.items.insert_many(items)

    print("✅ Sample inventory seeded.")


async def get_all_cabinets() -> list[dict]:
    """
    Fetch all cabinets via the MongoDB MCP server (find tool).
    Falls back to direct pymongo if MCP is unavailable.
    """
    try:
        from services.mcp_service import mcp_find
        raw_cabinets = await mcp_find(
            database="dobby",
            collection="cabinets",
            projection={"_id": 1, "name": 1, "contentSummary": 1, "room_id": 1},
        )
        if raw_cabinets:
            db = get_db()
            cabinets = []
            for c in raw_cabinets:
                # MCP returns _id as {"$oid": "..."} — normalise to string
                oid = c.get("_id")
                if isinstance(oid, dict):
                    c["_id"] = oid.get("$oid", str(oid))
                else:
                    c["_id"] = str(oid)

                room_id = c.get("room_id")
                if isinstance(room_id, dict):
                    room_id = room_id.get("$oid", str(room_id))
                c["room_id"] = str(room_id) if room_id else ""

                # Attach room name via direct lookup (lightweight)
                from bson import ObjectId
                try:
                    room = db.rooms.find_one({"_id": ObjectId(c["room_id"])})
                    c["room_name"] = room["name"] if room else ""
                except Exception:
                    c["room_name"] = ""

                cabinets.append(c)
            print("✅ get_all_cabinets: fetched via MongoDB MCP server")
            return cabinets
    except Exception as e:
        print(f"⚠️  MCP unavailable, falling back to pymongo: {e}")

    # Fallback: direct pymongo
    db = get_db()
    cabinets = list(db.cabinets.find({}, {"_id": 1, "name": 1, "contentSummary": 1, "room_id": 1}))
    for c in cabinets:
        c["_id"] = str(c["_id"])
        c["room_id"] = str(c["room_id"])
        room = db.rooms.find_one({"_id": c.get("room_id")})
        c["room_name"] = room["name"] if room else ""
    return cabinets


def get_items_in_cabinet(cabinet_id: str) -> list[dict]:
    from bson import ObjectId
    db = get_db()
    items = list(db.items.find({"cabinet_id": ObjectId(cabinet_id)}))
    for item in items:
        item["_id"] = str(item["_id"])
        item["cabinet_id"] = str(item["cabinet_id"])
    return items


def insert_items(items: list[dict]) -> int:
    """Insert confirmed items. Returns count inserted."""
    from bson import ObjectId
    db = get_db()
    for item in items:
        if "cabinet_id" in item:
            item["cabinet_id"] = ObjectId(item["cabinet_id"])
    result = db.items.insert_many(items)
    return len(result.inserted_ids)
