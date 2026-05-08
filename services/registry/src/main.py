from datetime import datetime, timezone
from typing import Optional
import json
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Agents Registry")

REGISTRY_FILE = os.getenv("REGISTRY_FILE_PATH", "/data/registry.json")
HEARTBEAT_TIMEOUT = int(os.getenv("HEARTBEAT_TIMEOUT_SECONDS", "60"))


class Agent(BaseModel):
    name: str
    url: str
    registered_at: Optional[str] = None
    last_heartbeat: Optional[str] = None


class RegisterRequest(BaseModel):
    name: str
    url: str


def load_agents() -> list:
    """Load agents from JSON file."""
    if not os.path.exists(REGISTRY_FILE):
        return []
    try:
        with open(REGISTRY_FILE, "r") as f:
            data = json.load(f)
            return data.get("agents", [])
    except (json.JSONDecodeError, IOError):
        return []


def save_agents(agents: list) -> None:
    """Save agents to JSON file."""
    with open(REGISTRY_FILE, "w") as f:
        json.dump({"agents": agents}, f, indent=2)


def cleanup_stale_agents() -> None:
    """Remove agents that haven't sent heartbeat within timeout."""
    agents = load_agents()
    now = datetime.now(timezone.utc)
    cleaned = []

    for agent in agents:
        last_hb = datetime.fromisoformat(agent["last_heartbeat"].replace("Z", "+00:00"))
        if (now - last_hb).total_seconds() <= HEARTBEAT_TIMEOUT:
            cleaned.append(agent)

    if len(cleaned) != len(agents):
        save_agents(cleaned)


@app.post("/register")
def register_agent(agent: RegisterRequest):
    """Register a new agent or update existing."""
    agents = load_agents()

    # Remove existing agent with same name
    agents = [a for a in agents if a["name"] != agent.name]

    # Add new agent with generated timestamps
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    agents.append({
        "name": agent.name,
        "url": agent.url,
        "registered_at": now,
        "last_heartbeat": now
    })

    save_agents(agents)
    return {"status": "registered", "name": agent.name}


@app.get("/agents")
def list_agents():
    """List all registered agents."""
    cleanup_stale_agents()
    agents = load_agents()
    return {"agents": agents}


@app.get("/agents/{name}")
def get_agent(name: str):
    """Get a specific agent by name."""
    agents = load_agents()
    for agent in agents:
        if agent["name"] == name:
            return {"agent": agent}
    raise HTTPException(status_code=404, detail="Agent not found")


class HeartbeatRequest(BaseModel):
    name: str


@app.post("/heartbeat")
def heartbeat(request: HeartbeatRequest):
    """Update agent's last heartbeat timestamp."""
    agents = load_agents()
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    for agent in agents:
        if agent["name"] == request.name:
            agent["last_heartbeat"] = now
            save_agents(agents)
            return {"status": "heartbeat updated", "name": request.name}

    raise HTTPException(status_code=404, detail="Agent not found")


@app.post("/deregister")
def deregister(request: HeartbeatRequest):
    """Unregister an agent."""
    agents = load_agents()
    agents = [a for a in agents if a["name"] != request.name]
    save_agents(agents)
    return {"status": "deregistered", "name": request.name}


@app.get("/health")
def health():
    """Health check endpoint."""
    return {"status": "healthy", "agents_count": len(load_agents())}
