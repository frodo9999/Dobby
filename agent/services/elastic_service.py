import os
from elasticsearch import Elasticsearch

_client: Elasticsearch | None = None
INDEX_NAME = "dobby_items"


def get_client() -> Elasticsearch:
    global _client
    if _client is None:
        _client = Elasticsearch(
            hosts=[os.environ["ELASTIC_ENDPOINT"]],
            api_key=os.environ["ELASTIC_API_KEY"]
        )
    return _client


def reset_index():
    """Delete the Elastic index entirely — call before a full re-seed."""
    es = get_client()
    if es.indices.exists(index=INDEX_NAME):
        es.indices.delete(index=INDEX_NAME)


def sync_from_mongo(items: list[dict]):
    """Index all items from MongoDB into Elastic."""
    es = get_client()

    # Create index if not exists
    if not es.indices.exists(index=INDEX_NAME):
        es.indices.create(index=INDEX_NAME, mappings={
            "properties": {
                "name":          {"type": "text", "analyzer": "standard"},
                "category":      {"type": "keyword"},
                "quantity":      {"type": "integer"},
                "cabinet_id":    {"type": "keyword"},
                "cabinet_name":  {"type": "text"},
                "room_name":     {"type": "text"},
                "contentSummary":{"type": "text"},
                "expiryDate":    {"type": "keyword"},
            }
        })

    for item in items:
        doc = {k: v for k, v in item.items() if k != "_id"}
        es.index(index=INDEX_NAME, id=str(item["_id"]), document=doc)

    es.indices.refresh(index=INDEX_NAME)
    print(f"✅ Indexed {len(items)} items into Elastic.")


def fetch_all_items(top_k: int = 50) -> list[dict]:
    """Return all indexed items — used as fallback when keyword search finds nothing."""
    es = get_client()
    response = es.search(index=INDEX_NAME, body={"query": {"match_all": {}}, "size": top_k})
    results = []
    for hit in response["hits"]["hits"]:
        doc = hit["_source"]
        doc["score"] = 0.0
        results.append(doc)
    return results


def search_items(query: str, top_k: int = 10) -> list[dict]:
    """Full-text + fuzzy search over item names, categories, and cabinet descriptions."""
    es = get_client()

    response = es.search(index=INDEX_NAME, body={
        "query": {
            "multi_match": {
                "query": query,
                "fields": ["name^3", "category^2", "cabinet_name", "room_name", "contentSummary"],
                "fuzziness": "AUTO",
                "operator": "or"
            }
        },
        "size": top_k
    })

    results = []
    for hit in response["hits"]["hits"]:
        doc = hit["_source"]
        doc["score"] = hit["_score"]
        results.append(doc)

    return results
