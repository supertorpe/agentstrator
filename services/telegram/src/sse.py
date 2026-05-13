import asyncio
import json
import logging
from typing import Dict, Any, Optional

import httpx

from config import get_all_agents, get_agent_url

logger = logging.getLogger(__name__)


class SSEManager:
    """Manages SSE connections to all registered agents."""

    def __init__(self, bridge):
        self.bridge = bridge
        self._connections: Dict[str, asyncio.Task] = {}
        self._running = False
        self._reconnect_delays: Dict[str, float] = {}
        self._agent_urls: Dict[str, str] = {}

    async def start(self):
        self._running = True
        await self._sync_connections()

    async def stop(self):
        self._running = False
        for name, task in self._connections.items():
            task.cancel()
        self._connections.clear()
        self._agent_urls.clear()
        self._reconnect_delays.clear()

    async def _sync_connections(self):
        """Periodically sync connections with registered agents."""
        while self._running:
            try:
                agents = await get_all_agents()
                current_names = {a["name"] for a in agents}

                logger.info(f"SSE sync: found {len(agents)} agents: {current_names}")

                for agent in agents:
                    name = agent["name"]
                    if name not in self._connections:
                        url = agent.get("url")
                        if url:
                            logger.info(f"SSE: connecting to agent {name} at {url}/event")
                            self._agent_urls[name] = url
                            self._reconnect_delays[name] = 1.0
                            task = asyncio.create_task(self._listen(name, url))
                            self._connections[name] = task

                for name in list(self._connections.keys()):
                    if name not in current_names:
                        logger.info(f"SSE: disconnecting from agent {name}")
                        self._connections[name].cancel()
                        del self._connections[name]
                        self._agent_urls.pop(name, None)
                        self._reconnect_delays.pop(name, None)

            except Exception as e:
                logger.error(f"SSE sync error: {e}")

            await asyncio.sleep(30)

    async def _listen(self, agent_name: str, url: str):
        """Maintain SSE connection with reconnection."""
        while self._running:
            try:
                sse_url = f"{url}/event"
                logger.info(f"SSE: connecting to {agent_name} at {sse_url}")
                async with httpx.AsyncClient(timeout=None) as client:
                    async with client.stream("GET", sse_url) as response:
                        logger.info(f"SSE: connected to {agent_name}, status={response.status_code}")
                        self._reconnect_delays[agent_name] = 1.0
                        current_event: Dict[str, str] = {}
                        async for line in response.aiter_lines():
                            line = line.strip()
                            if not line:
                                if current_event:
                                    logger.info(f"SSE: received event from {agent_name}: {current_event.get('event')}")
                                    await self._process_event(agent_name, current_event)
                                    current_event = {}
                            elif line.startswith("event:"):
                                current_event["event"] = line[6:].strip()
                            elif line.startswith("data:"):
                                current_event["data"] = line[5:].strip()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"SSE error for {agent_name}: {e}")
                if not self._running:
                    break
                delay = self._reconnect_delays.get(agent_name, 1.0)
                await asyncio.sleep(delay)
                self._reconnect_delays[agent_name] = min(delay * 2, 60.0)

    async def _process_event(self, agent_name: str, event: dict):
        """Route an SSE event to the appropriate handler."""
        data_raw = event.get("data", "{}")

        try:
            data = json.loads(data_raw)
        except json.JSONDecodeError:
            logger.error(f"Invalid SSE data from {agent_name}: {data_raw}")
            return

        event_type = data.get("type") or event.get("event")
        logger.info(f"SSE: processing event type={event_type} from {agent_name}")

        if event_type == "permission.asked":
            await self._handle_permission_asked(agent_name, data)
        elif event_type and event_type not in ("server.connected",):
            logger.info(f"SSE: unhandled event type {event_type} from {agent_name}")

    async def _handle_permission_asked(self, agent_name: str, data: dict):
        """Handle a permission.asked event."""
        props = data.get("properties", data)
        request_id = props.get("id")
        permission = props.get("permission", "unknown")
        patterns = props.get("patterns", [])
        patterns_str = ", ".join(patterns) if patterns else "(no path)"

        logger.info(f"SSE: permission.asked from {agent_name}: id={request_id}, permission={permission}, patterns={patterns_str}")

        if not request_id:
            logger.error(f"permission.asked missing id from {agent_name}, data={json.dumps(data)}")
            return

        from handlers.message import get_pending_message
        from handlers.permission import show_permission_prompt

        pending = get_pending_message(agent_name)

        if pending:
            chat_id = int(pending["chat_id"])
            state = self.bridge.conversation_state.get(str(chat_id))
            is_active = state and state.get("active_agent") == agent_name
            logger.info(f"SSE: found pending message for {agent_name}, chat_id={chat_id}, is_active={is_active}")
            await show_permission_prompt(
                self.bridge.bot, chat_id, agent_name,
                request_id, permission, patterns_str, is_active,
            )
        else:
            logger.info(f"SSE: no pending message for {agent_name}, searching active chats")
            for chat_id_str, state in self.bridge.conversation_state.items():
                if state.get("active_agent") == agent_name:
                    logger.info(f"SSE: found active chat {chat_id_str} for {agent_name}")
                    await show_permission_prompt(
                        self.bridge.bot, int(chat_id_str), agent_name,
                        request_id, permission, patterns_str, True,
                    )
                    break
