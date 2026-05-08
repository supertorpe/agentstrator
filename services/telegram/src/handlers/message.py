import asyncio
import logging
from datetime import datetime
from pathlib import Path

import httpx
from telegram import Bot
from telegram import InlineKeyboardButton, InlineKeyboardMarkup

from keyboards import get_agent_display_name, store_callback_data
from client import AgentClient
from config import get_agent_url, SESSIONS_DIR
from session_log import log_conversation, save_metadata, list_sessions, update_title

logger = logging.getLogger(__name__)


def save_session_metadata(session_id: str, agent: str, title: str, mode: str, created_at: str = None) -> str:
    """Save session metadata. Returns session_id for compatibility."""
    save_metadata(session_id, agent, title, mode)
    return session_id


def log_to_file(session_id: str, direction: str, text: str, mode: str = None, folder_name: str = None):
    """Log a message to the session's log file. Uses centralized session_log."""
    log_conversation(session_id, direction, text, mode or "")


async def handle_message(
    bot: Bot,
    chat_id: int,
    username: str,
    text: str,
    allowed_users: set | None,
    conversation_state: dict,
):
    """Handle regular message asynchronously."""
    if not _is_allowed(username, allowed_users):
        await bot.send_message(chat_id=chat_id, text="Access denied.")
        return

    chat_id_str = str(chat_id)

    if chat_id_str in conversation_state:
        state = conversation_state[chat_id_str]
        sessions = state.get("sessions", {})
        active_agent = state.get("active_agent")

        if not active_agent or active_agent not in sessions:
            await bot.send_message(chat_id=chat_id, text="No active session. Use /agents to start one.")
            return

        session_data = sessions[active_agent]
        session_id = session_data.get("session_id")
        mode = session_data.get("mode", "build")
        title = session_data.get("title", "Untitled")

        if not session_id:
            await bot.send_message(chat_id=chat_id, text="Session expired. Use /agents to select a worker")
            return

        asyncio.create_task(
            send_message_to_agent(bot, chat_id, active_agent, session_id, mode, title, text, conversation_state)
        )

        await bot.send_message(
            chat_id=chat_id,
            text=f"📤 Message sent to {get_agent_display_name(active_agent)} ('{title}')"
        )
        return

    await bot.send_message(
        chat_id=chat_id,
        text="I don't know which worker to send this to. Use /agents to select one."
    )


async def send_message_to_agent(
    bot: Bot,
    chat_id: int,
    agent: str,
    session_id: str,
    mode: str,
    title: str,
    text: str,
    conversation_state: dict,
):
    """Send message to agent with callback for response."""
    # Get folder_name from conversation_state if available
    folder_name = None
    chat_id_str = str(chat_id)
    if chat_id_str in conversation_state:
        agent_sessions = conversation_state[chat_id_str].get("sessions", {})
        folder_name = agent_sessions.get(agent, {}).get("folder_name")

    # Log sent message with mode
    log_to_file(session_id, "SEND", text, mode, folder_name)

    async def send_request():
        agent_url_base = await get_agent_url(agent)
        if not agent_url_base:
            raise ValueError(f"Agent URL not found for: {agent}")
        agent_url = f"{agent_url_base}/session/{session_id}/message"
        request_body = {"agent": mode, "parts": [{"type": "text", "text": text}]}
        logger.info(f"Request to {agent}: {request_body}")
        async with httpx.AsyncClient() as client:
            response = await client.post(
                agent_url,
                json=request_body,
                timeout=43200.0
            )
            return response

    async def handle_response(task: asyncio.Task):
        try:
            response = task.result()
            if response.status_code == 200:
                data = response.json()
                parts = data.get("parts", [])
                reply = "\n".join(p.get("text", "") for p in parts if p.get("type") == "text")
                if reply:
                    # Log received response with mode
                    log_to_file(session_id, "RECV", reply, mode, folder_name)

                    # Check if title was updated by agent (only if current title starts with "New session")
                    if title and title.startswith("New session"):
                        sessions = await AgentClient.get_agent_sessions(agent)
                        for s in sessions:
                            if s.get("id") == session_id:
                                new_title = s.get("title", "")
                                if new_title and not new_title.startswith("New session"):
                                    # Update conversation_state
                                    chat_id_str = str(chat_id)
                                    if chat_id_str in conversation_state:
                                        if agent in conversation_state[chat_id_str].get("sessions", {}):
                                            conversation_state[chat_id_str]["sessions"][agent]["title"] = new_title

                                    # Update metadata.json using centralized function
                                    update_title(session_id, new_title)
                                break

                    # Check if this agent is active
                    chat_id_str = str(chat_id)
                    is_active = False
                    if chat_id_str in conversation_state:
                        state = conversation_state[chat_id_str]
                        is_active = state.get("active_agent") == agent

                    # Build response with or without join button
                    if is_active:
                        asyncio.create_task(
                            bot.send_message(chat_id=chat_id, text=f"[{get_agent_display_name(agent)}] {reply[:4000]}")
                        )
                    else:
                        keyboard = []

                        # Join button
                        join_cb = store_callback_data({
                            "action": "session",
                            "agent": agent,
                            "mode": mode,
                            "session_id": session_id,
                        })
                        keyboard.append([InlineKeyboardButton("Join this session", callback_data=join_cb)])

                        # Current active session info
                        chat_id_str = str(chat_id)
                        if chat_id_str in conversation_state:
                            state = conversation_state[chat_id_str]
                            active_agent = state.get("active_agent")
                            if active_agent and active_agent in state.get("sessions", {}):
                                active_session = state["sessions"][active_agent]
                                active_title = active_session.get("title", "Untitled")
                                keyboard.append([InlineKeyboardButton(
                                    f"💬 Current: {get_agent_display_name(active_agent)} - {active_title}",
                                    callback_data="noop"
                                )])

                        asyncio.create_task(
                            bot.send_message(
                                chat_id=chat_id,
                                text=f"[{get_agent_display_name(agent)}] {reply[:4000]}",
                                reply_markup=InlineKeyboardMarkup(keyboard)
                            )
                        )
            else:
                asyncio.create_task(
                    bot.send_message(chat_id=chat_id, text=f"[{get_agent_display_name(agent)}] Error: HTTP {response.status_code}")
                )
        except Exception as e:
            logger.error(f"Error in response callback: {e}")
            asyncio.create_task(
                bot.send_message(chat_id=chat_id, text=f"[{get_agent_display_name(agent)}] Error: {e}")
            )

    task = asyncio.create_task(send_request())

    def done_callback_wrapper(task):
        asyncio.create_task(handle_response(task))

    task.add_done_callback(done_callback_wrapper)


def _is_allowed(username: str | None, allowed_users: set | None) -> bool:
    if allowed_users is None:
        return True
    return username is not None and username in allowed_users
