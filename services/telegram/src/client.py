import logging
from typing import List, Optional, Dict, Any

import httpx

from config import get_agent_url, get_all_agents

logger = logging.getLogger(__name__)


class AgentClient:
    """HTTP client for communicating with agents."""

    @staticmethod
    async def create_session(agent: str) -> Optional[str]:
        """Create a new session on the specified agent."""
        try:
            agent_url_base = await get_agent_url(agent)
            if not agent_url_base:
                logger.error(f"Agent URL not found for: {agent}")
                return None
            agent_url = f"{agent_url_base}/session"
            async with httpx.AsyncClient() as client:
                response = await client.post(agent_url, json={}, timeout=43200.0)
                if response.status_code == 200:
                    return response.json().get("id")
        except Exception as e:
            logger.error(f"Error creating session: {e}")
        return None

    @staticmethod
    async def get_agent_sessions(agent: str) -> List[Dict[str, Any]]:
        """Get sessions from an agent."""
        try:
            agent_url_base = await get_agent_url(agent)
            if not agent_url_base:
                logger.error(f"Agent URL not found for: {agent}")
                return []
            agent_url = f"{agent_url_base}/session"
            async with httpx.AsyncClient() as client:
                response = await client.get(agent_url, timeout=43200.0)
                if response.status_code == 200:
                    data = response.json()
                    if isinstance(data, list):
                        return data
                    return data.get("sessions", [])
        except Exception as e:
            logger.error(f"Error getting sessions from {agent}: {e}")
        return []

    @staticmethod
    async def delete_agent_session(agent: str, session_id: str) -> bool:
        """Delete a session on an agent."""
        try:
            agent_url_base = await get_agent_url(agent)
            if not agent_url_base:
                logger.error(f"Agent URL not found for: {agent}")
                return False
            agent_url = f"{agent_url_base}/session/{session_id}"
            async with httpx.AsyncClient() as client:
                response = await client.delete(agent_url, timeout=43200.0)
                return response.status_code == 200
        except Exception as e:
            logger.error(f"Error deleting session: {e}")
        return False

    @staticmethod
    async def send_message(
        agent: str,
        session_id: str,
        mode: str,
        text: str,
        model: Optional[str] = None,
        timeout: float = 43200.0
    ) -> httpx.Response:
        """Send a message to an agent session."""
        agent_url_base = await get_agent_url(agent)
        if not agent_url_base:
            raise ValueError(f"Agent URL not found for: {agent}")
        agent_url = f"{agent_url_base}/session/{session_id}/message"
        body = {"agent": mode, "parts": [{"type": "text", "text": text}]}
        if model:
            parts = model.split("/", 1)
            body["model"] = {"providerID": parts[0], "modelID": parts[1]} if len(parts) == 2 else model
        async with httpx.AsyncClient() as client:
            response = await client.post(
                agent_url,
                json=body,
                timeout=timeout
            )
            return response

    @staticmethod
    async def get_agent_modes(agent: str) -> List[Dict[str, Any]]:
        """Get available modes from an agent's /agent endpoint."""
        try:
            agent_url_base = await get_agent_url(agent)
            if not agent_url_base:
                logger.error(f"Agent URL not found for: {agent}")
                return [{"name": "plan"}, {"name": "build"}]
            agent_url = f"{agent_url_base}/agent"
            async with httpx.AsyncClient() as client:
                response = await client.get(agent_url, timeout=43200.0)
                if response.status_code == 200:
                    agents = response.json()
                    return [a for a in agents if not a.get("hidden", False)]
        except Exception as e:
            logger.error(f"Error getting agent modes: {e}")
        return [{"name": "plan"}, {"name": "build"}]

    @staticmethod
    async def get_agent_providers(agent: str) -> List[Dict[str, Any]]:
        """Get available providers and models from an agent's /config/providers endpoint."""
        try:
            agent_url_base = await get_agent_url(agent)
            if not agent_url_base:
                logger.error(f"Agent URL not found for: {agent}")
                return []
            agent_url = f"{agent_url_base}/config/providers"
            async with httpx.AsyncClient() as client:
                response = await client.get(agent_url, timeout=43200.0)
                if response.status_code == 200:
                    data = response.json()
                    return data.get("providers", [])
        except Exception as e:
            logger.error(f"Error getting agent providers: {e}")
        return []

    @staticmethod
    async def reply_permission(agent: str, request_id: str, reply: str) -> bool:
        """Reply to a permission request on the specified agent."""
        try:
            agent_url_base = await get_agent_url(agent)
            if not agent_url_base:
                logger.error(f"Agent URL not found for: {agent}")
                return False
            agent_url = f"{agent_url_base}/permission/{request_id}/reply"
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    agent_url,
                    json={"reply": reply},
                    timeout=30.0,
                )
                return response.status_code == 200
        except Exception as e:
            logger.error(f"Error replying to permission: {e}")
        return False
