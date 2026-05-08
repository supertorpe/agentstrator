from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
import hashlib
import time
import threading

from telegram import InlineKeyboardButton, InlineKeyboardMarkup

from config import SESSIONS_DIR, get_all_agents, get_agent_by_name
from client import AgentClient

# Callback data store to keep callback_data under Telegram's 64-byte limit.
# Maps short tokens -> full callback data dicts.
_callback_store: Dict[str, Dict[str, Any]] = {}
_callback_lock = threading.Lock()
_CALLBACK_TTL = 3600  # 1 hour
_callback_counter = 0


def store_callback_data(data: Dict[str, Any]) -> str:
    """Store callback data and return a short token."""
    global _callback_counter
    with _callback_lock:
        _callback_counter += 1
        token = f"cb{_callback_counter:06d}"  # e.g. "cb000042" (8 bytes)
        _callback_store[token] = {
            "data": data,
            "expires": time.time() + _CALLBACK_TTL,
        }
        # Clean expired entries
        now = time.time()
        expired = [k for k, v in _callback_store.items() if v["expires"] < now]
        for k in expired:
            del _callback_store[k]
        return token


def retrieve_callback_data(token: str) -> Optional[Dict[str, Any]]:
    """Retrieve callback data by token, or None if expired/missing."""
    with _callback_lock:
        entry = _callback_store.get(token)
        if entry and entry["expires"] > time.time():
            return entry["data"]
        _callback_store.pop(token, None)
        return None


def get_agent_display_name(agent: str) -> str:
    """Get display name for an agent."""
    # Agent name is already formatted
    return agent


def build_agent_selection_keyboard(agents: List[Dict[str, Any]] = None) -> InlineKeyboardMarkup:
    """Build keyboard for agent selection."""
    keyboard = []

    if agents is None:
        agents = []

    for agent in agents:
        name = agent.get("name", "unknown")
        display_name = agent.get("display_name", name)
        token = store_callback_data({"action": "select", "agent": name})
        keyboard.append([InlineKeyboardButton(display_name, callback_data=token)])

    if not keyboard:
        keyboard.append([InlineKeyboardButton("No agents available", callback_data="noop")])

    return InlineKeyboardMarkup(keyboard)


def build_mode_keyboard(agent: str, modes: List[Dict[str, Any]] = None) -> tuple[str, InlineKeyboardMarkup]:
    """Build keyboard for mode selection."""
    keyboard = []
    if modes is None:
        modes = [{"name": "plan"}, {"name": "build"}]

    # Build text description
    text_lines = ["Available modes:\n"]
    for mode in modes:
        mode_name = mode.get("name", "")
        mode_desc = mode.get("description", "")
        text_lines.append(f"• {mode_name}")
        if mode_desc:
            text_lines.append(f"  {mode_desc}")
        text_lines.append("")

    text = "\n".join(text_lines)

    # Build keyboard with short tokens
    for mode in modes:
        mode_name = mode.get("name", "")
        token = store_callback_data({"action": "mode", "agent": agent, "mode": mode_name})
        keyboard.append([InlineKeyboardButton(mode_name, callback_data=token)])

    return text, InlineKeyboardMarkup(keyboard)


def build_mode_switch_keyboard(current_mode: str, modes: List[Dict[str, Any]] = None) -> InlineKeyboardMarkup:
    """Build keyboard for switching modes."""
    keyboard = []
    if modes is None:
        modes = [{"name": "plan"}, {"name": "build"}]

    for mode in modes:
        mode_name = mode.get("name", "")
        label = f"📋 {mode_name}" + (" [ACTIVE]" if current_mode == mode_name else "")
        if current_mode == mode_name:
            callback = "noop"
        else:
            callback = store_callback_data({"action": "switchmode", "mode": mode_name})
        keyboard.append([InlineKeyboardButton(label, callback_data=callback)])

    return InlineKeyboardMarkup(keyboard)


def build_session_selection_keyboard(agent: str, mode: str, sessions: List[Dict[str, Any]]) -> InlineKeyboardMarkup:
    """Build keyboard for session selection."""
    keyboard = []
    keyboard.append([InlineKeyboardButton(f"📱 {get_agent_display_name(agent)}", callback_data="noop")])

    for session in sessions:
        label = session.get("title", session.get("id", "Unknown"))
        callback = store_callback_data({"action": "session", "agent": agent, "mode": mode, "session_id": session["id"]})
        keyboard.append([InlineKeyboardButton(label, callback_data=callback)])

    new_cb = store_callback_data({"action": "new_session", "agent": agent, "mode": mode})
    keyboard.append([InlineKeyboardButton("➕ New Session", callback_data=new_cb)])
    return InlineKeyboardMarkup(keyboard)


async def build_sessions_keyboard(
    conversation_state: Optional[Dict[str, Any]],
    chat_id: Optional[int] = None
) -> InlineKeyboardMarkup:
    """Build keyboard showing all agent sessions."""
    keyboard = []

    # Get active session info
    active_sessions = {}
    active_agent = None
    if chat_id and conversation_state and str(chat_id) in conversation_state:
        state = conversation_state[str(chat_id)]
        active_sessions = state.get("sessions", {})
        active_agent = state.get("active_agent")

    # Get all agents from registry
    agents = await get_all_agents()

    if not agents:
        keyboard.append([InlineKeyboardButton("Use /agents to start", callback_data="noop")])
        return InlineKeyboardMarkup(keyboard)

    for agent in agents:
        agent_name = agent.get("name", "")
        display_name = agent.get("display_name", agent_name)

        sessions = await AgentClient.get_agent_sessions(agent_name)

        # Worker header
        keyboard.append([InlineKeyboardButton(
            f"📱 {display_name}",
            callback_data="noop"
        )])

        # Sessions for this worker
        for session in sessions:
            session_id = session.get("id", "")
            title = session.get("title", "Unknown")

            is_active = active_agent == agent_name and active_sessions.get(agent_name, {}).get("session_id") == session_id

            row = []
            label = f"  • {title}" + (" [ACTIVE]" if is_active else "")
            if is_active:
                callback = "noop"
            else:
                callback = store_callback_data({
                    "action": "session",
                    "agent": agent_name,
                    "mode": "build",
                    "session_id": session_id,
                })
            row.append(InlineKeyboardButton(label, callback_data=callback))
            del_cb = store_callback_data({"action": "delete_session", "agent": agent_name, "session_id": session_id})
            row.append(InlineKeyboardButton("🗑️", callback_data=del_cb))
            keyboard.append(row)

        # New session button for this worker
        new_cb = store_callback_data({"action": "new_session", "agent": agent_name, "mode": "build"})
        keyboard.append([InlineKeyboardButton(
            f"  + New session",
            callback_data=new_cb
        )])

    if not keyboard:
        keyboard.append([InlineKeyboardButton("Use /agents to start", callback_data="noop")])

    return InlineKeyboardMarkup(keyboard)


def build_log_keyboard() -> InlineKeyboardMarkup:
    """Build keyboard showing available session log files."""
    from session_log import list_sessions
    from datetime import datetime

    keyboard = []
    sessions = list_sessions()

    if not sessions:
        return InlineKeyboardMarkup([[InlineKeyboardButton("No logs available", callback_data="noop")]])

    for session in sessions[:25]:
        session_id = session["session_id"]
        agent = session.get("agent", "unknown")
        title = session.get("title", "Untitled")
        display_name = get_agent_display_name(agent)

        created_at = session.get("created_at", "")
        if created_at:
            try:
                dt = datetime.fromisoformat(created_at)
                formatted_time = dt.strftime("%m-%d %H:%M")
                label = f"📄 {formatted_time} - {display_name} - {title[:25]}"
            except (ValueError, TypeError):
                label = f"📄 {display_name} - {title[:25]}"
        else:
            label = f"📄 {display_name} - {title[:25]}"

        log_cb = store_callback_data({"action": "viewlog", "session_id": session_id})
        keyboard.append([InlineKeyboardButton(label, callback_data=log_cb)])

    back_cb = store_callback_data({"action": "back_to_main"})
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data=back_cb)])
    return InlineKeyboardMarkup(keyboard)
