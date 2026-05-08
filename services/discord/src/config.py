import os
import httpx
import asyncio
from pathlib import Path
from typing import Optional, List, Dict, Any

REGISTRY_URL = os.getenv("REGISTRY_URL", "http://registry:8090")

LOG_RETENTION_DAYS = int(os.getenv("LOG_RETENTION_DAYS", "30"))
SESSIONS_DIR = Path("/home/user/sessions")

# Cache for agents
_agents_cache: Optional[List[Dict[str, Any]]] = None
_cache_timestamp: float = 0
CACHE_TTL = 30  # seconds


async def query_registry(endpoint: str) -> dict:
    """Query the registry service."""
    if REGISTRY_URL.startswith("file://"):
        return await _query_registry_file(endpoint)
    else:
        return await _query_registry_http(endpoint)


async def _query_registry_file(endpoint: str) -> dict:
    """Query registry from local file."""
    import json
    file_path = REGISTRY_URL.replace("file://", "")
    
    if not file_path.startswith("/"):
        print(f"Warning: Registry file path must be absolute: {file_path}")
        return {"agents": []}
    
    if endpoint == "agents":
        try:
            with open(file_path, "r") as f:
                data = json.load(f)
                return {"agents": data.get("agents", [])}
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Warning: Failed to read registry file: {e}")
            return {"agents": []}
    
    return {"agents": []}


async def _query_registry_http(endpoint: str) -> dict:
    """Query registry via HTTP."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(f"{REGISTRY_URL}/{endpoint}")
        response.raise_for_status()
        return response.json()


async def get_all_agents(force_refresh: bool = False) -> list:
    """Get all agents from registry with caching."""
    global _agents_cache, _cache_timestamp
    
    import time
    current_time = time.time()
    
    if not force_refresh and _agents_cache and (current_time - _cache_timestamp) < CACHE_TTL:
        return _agents_cache
    
    try:
        response = await query_registry("agents")
        _agents_cache = response.get("agents", [])
        _cache_timestamp = current_time
        return _agents_cache
    except Exception as e:
        print(f"Warning: Failed to query registry: {e}")
        return _agents_cache or []


async def get_agent_by_name(name: str) -> Optional[Dict[str, Any]]:
    """Get a specific agent by name from registry."""
    agents = await get_all_agents()
    for agent in agents:
        if agent.get("name") == name:
            return agent
    return None


async def get_agent_url(name: str) -> Optional[str]:
    """Get URL for a specific agent."""
    agent = await get_agent_by_name(name)
    if agent:
        return agent.get("url")
    return None


async def refresh_agents_cache():
    """Force refresh the agents cache."""
    await get_all_agents(force_refresh=True)
