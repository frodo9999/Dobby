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
    kitchen = db.rooms.insert_one({"name": "厨房", "icon": "refrigerator"}).inserted_id
    bedroom = db.rooms.insert_one({"name": "卧室", "icon": "bed.double"}).inserted_id
    bathroom = db.rooms.insert_one({"name": "浴室", "icon": "bathtub"}).inserted_id
    living = db.rooms.insert_one({"name": "客厅", "icon": "sofa"}).inserted_id

    # Cabinets
    fridge = db.cabinets.insert_one({
        "name": "冰箱", "icon": "refrigerator", "room_id": kitchen,
        "contentSummary": "食品；牛奶、鸡蛋、蔬菜"
    }).inserted_id

    pantry = db.cabinets.insert_one({
        "name": "食品柜", "icon": "cabinet", "room_id": kitchen,
        "contentSummary": "食品；米面、调料、零食"
    }).inserted_id

    medicine_cabinet = db.cabinets.insert_one({
        "name": "药品柜", "icon": "cross.case", "room_id": bathroom,
        "contentSummary": "药品；感冒药、维生素、创可贴"
    }).inserted_id

    wardrobe = db.cabinets.insert_one({
        "name": "衣柜", "icon": "cabinet", "room_id": bedroom,
        "contentSummary": "衣物；T恤、裤子、外套"
    }).inserted_id

    bookshelf = db.cabinets.insert_one({
        "name": "书架", "icon": "books.vertical", "room_id": living,
        "contentSummary": "书籍；小说、教材、杂志"
    }).inserted_id

    # Items
    items = [
        {"name": "牛奶", "category": "食品", "quantity": 2, "cabinet_id": fridge, "expiryDate": "2026-06-15"},
        {"name": "鸡蛋", "category": "食品", "quantity": 12, "cabinet_id": fridge, "expiryDate": "2026-06-20"},
        {"name": "橙汁", "category": "食品", "quantity": 1, "cabinet_id": fridge, "expiryDate": "2026-06-18"},
        {"name": "大米", "category": "食品", "quantity": 5, "cabinet_id": pantry},
        {"name": "酱油", "category": "食品", "quantity": 1, "cabinet_id": pantry},
        {"name": "感冒灵", "category": "药品", "quantity": 1, "cabinet_id": medicine_cabinet, "expiryDate": "2027-01-01"},
        {"name": "维生素C", "category": "药品", "quantity": 60, "cabinet_id": medicine_cabinet, "expiryDate": "2027-06-01"},
        {"name": "T恤", "category": "衣物", "quantity": 5, "cabinet_id": wardrobe},
        {"name": "Python编程", "category": "书籍", "quantity": 1, "cabinet_id": bookshelf},
    ]
    db.items.insert_many(items)

    print("✅ Sample inventory seeded.")


def get_all_cabinets() -> list[dict]:
    db = get_db()
    cabinets = list(db.cabinets.find({}, {"_id": 1, "name": 1, "contentSummary": 1, "room_id": 1}))
    for c in cabinets:
        c["_id"] = str(c["_id"])
        c["room_id"] = str(c["room_id"])
        # Attach room name
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
