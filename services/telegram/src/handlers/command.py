from telegram import Bot
from typing import Optional

from keyboards import build_agent_selection_keyboard, build_sessions_keyboard, build_mode_switch_keyboard, build_log_keyboard
from client import AgentClient
from config import get_agent_by_name


async def handle_command(
    bot: Bot,
    chat_id: int,
    username: str,
    text: str,
    allowed_users: Optional[set],
    conversation_state: dict,
):
    """Handle commands."""
    if not _is_allowed(username, allowed_users):
        await bot.send_message(chat_id=chat_id, text="Access denied.")
        return

    if text == "/start" or text == "/help":
        await bot.send_message(
            chat_id=chat_id,
            text="Available commands:\n/agents - Select a worker and mode\n/sessions - View and manage your sessions\n/mode - Switch between Plan and Build modes\n/log - View session logs"
        )
        return

    if text == "/agents":
        agents = await get_all_agents_for_keyboard()
        await bot.send_message(
            chat_id=chat_id,
            text="Select a worker:",
            reply_markup=build_agent_selection_keyboard(agents)
        )
        return

    if text == "/sessions":
        await bot.send_message(
            chat_id=chat_id,
            text="Choose or create a session:",
            reply_markup=await build_sessions_keyboard(conversation_state, chat_id)
        )
        return

    if text == "/mode":
        chat_id_str = str(chat_id)
        if chat_id_str not in conversation_state:
            await bot.send_message(chat_id=chat_id, text="No active session. Use /agents to start one.")
            return

        state = conversation_state[chat_id_str]
        active_agent = state.get("active_agent")

        if not active_agent:
            await bot.send_message(chat_id=chat_id, text="No active session. Use /agents to start one.")
            return

        current_mode = state.get("sessions", {}).get(active_agent, {}).get("mode", "build")

        modes = await AgentClient.get_agent_modes(active_agent)

        await bot.send_message(
            chat_id=chat_id,
            text=f"Current mode: {current_mode.upper()}",
            reply_markup=build_mode_switch_keyboard(current_mode, modes)
        )
        return

    if text == "/log":
        await bot.send_message(
            chat_id=chat_id,
            text="Select a session log to download:",
            reply_markup=build_log_keyboard()
        )
        return


async def get_all_agents_for_keyboard():
    """Get all agents formatted for keyboard display."""
    from config import get_all_agents
    return await get_all_agents()


def _is_allowed(username: str | None, allowed_users: set | None) -> bool:
    if allowed_users is None:
        return True
    return username is not None and username in allowed_users
