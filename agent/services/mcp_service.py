"""
MongoDB MCP Service
-------------------
Thin async wrapper around the MongoDB MCP server (stdio transport).

The MongoDB MCP server is installed globally as a Node.js binary
(`mongodb-mcp-server`) inside the Docker container. Each call spawns
a short-lived subprocess, initialises an MCP session, calls the
requested tool, and then tears down cleanly.

Usage:
    from services.mcp_service import mcp_find

    cabinets = await mcp_find(
        database="dobby",
        collection="cabinets",
        projection={"_id": 1, "name": 1, "contentSummary": 1, "room_id": 1},
    )
"""

import json
import os
import shutil

from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


def _server_params() -> StdioServerParameters:
    """Return StdioServerParameters pointing at the installed MCP binary."""
    # Prefer the globally installed binary; fall back to npx for local dev.
    binary = shutil.which("mongodb-mcp-server") or "npx"
    args = [] if binary != "npx" else ["-y", "@mongodb-js/mongodb-mcp-server"]

    return StdioServerParameters(
        command=binary,
        args=args,
        env={
            **os.environ,
            "MDB_MCP_CONNECTION_STRING": os.environ["MONGODB_URI"],
            # Disable Atlas management tools — we only need DB tools
            "MDB_MCP_ATLAS_CLIENT_ID": "",
            "MDB_MCP_ATLAS_CLIENT_SECRET": "",
        },
    )


async def mcp_find(
    database: str,
    collection: str,
    filter: dict | None = None,
    projection: dict | None = None,
    limit: int = 100,
) -> list[dict]:
    """
    Call the MongoDB MCP server `find` tool and return the result as a
    list of plain Python dicts.
    """
    arguments: dict = {
        "database": database,
        "collection": collection,
        "limit": limit,
    }
    if filter:
        arguments["filter"] = filter
    if projection:
        arguments["projection"] = projection

    async with stdio_client(_server_params()) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("find", arguments=arguments)

    # The MCP server returns content as a list of TextContent objects.
    # Each item's .text field is a JSON string containing the documents.
    documents: list[dict] = []
    for content_item in result.content:
        raw = getattr(content_item, "text", None)
        if not raw:
            continue
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                documents.extend(parsed)
            elif isinstance(parsed, dict):
                documents.append(parsed)
        except json.JSONDecodeError:
            continue

    return documents
