import asyncio
import logging

from telegram import Bot
from telegram import InputFile

from keyboards import (
    get_agent_display_name,
    build_mode_keyboard,
    build_mode_switch_keyboard,
    build_session_selection_keyboard,
    build_sessions_keyboard,
    build_agent_selection_keyboard,
    retrieve_callback_data,
)
from client import AgentClient
from config import get_all_agents, get_agent_by_name, SESSIONS_DIR
from models import SessionInfo, ConversationState
from handlers.message import save_session_metadata

logger = logging.getLogger(__name__)


async def create_and_join_session(bot, chat_id, message_id, callback_id, agent, mode, conversation_state, model=None):
    """Create a new session and join it."""
    await bot.answer_callback_query(callback_id, text=f"Creating session on {agent}...")

    session_id = await AgentClient.create_session(agent)
    if not session_id:
        await bot.edit_message_text(chat_id=chat_id, message_id=message_id, text="❌ Failed to create session")
        return

    sessions = await AgentClient.get_agent_sessions(agent)
    title = "Untitled"
    for s in sessions:
        if s.get("id") == session_id:
            title = s.get("title", "Untitled")
            break

    chat_id_str = str(chat_id)
    if chat_id_str not in conversation_state:
        conversation_state[chat_id_str] = ConversationState(
            active_agent=agent,
            sessions={}
        ).__dict__

    conversation_state[chat_id_str]["sessions"][agent] = SessionInfo(
        session_id=session_id,
        mode=mode,
        model=model,
        title=title,
        last_message_id=None
    ).__dict__
    conversation_state[chat_id_str]["active_agent"] = agent

    folder_name = save_session_metadata(session_id, agent, title, mode)
    if folder_name:
        conversation_state[chat_id_str]["sessions"][agent]["folder_name"] = folder_name

    model_info = f" (model: {model})" if model else ""
    await bot.edit_message_text(
        chat_id=chat_id,
        message_id=message_id,
        text=f"✅ Connected to {get_agent_display_name(agent)} ({mode.capitalize()} mode{model_info})\n\nWhat would you like to tell them?"
    )


async def handle_callback(
    bot: Bot,
    callback_id: str,
    chat_id: int,
    message_id: int,
    data: str,
    conversation_state: dict,
):
    """Handle callback query."""
    logger.info(f"!!! handle_callback: {data}")

    if data == "noop":
        await bot.answer_callback_query(callback_id)
        return

    # Resolve token to callback data
    cb = retrieve_callback_data(data)
    if cb is None:
        await bot.answer_callback_query(callback_id, text="⚠️ Button expired. Please try again.")
        return

    action = cb.get("action", "")

    if action == "select":
        agent = cb["agent"]
        logger.info(f"Selected agent: {agent}")

        await bot.answer_callback_query(callback_id)
        from keyboards import build_provider_keyboard
        provider_text, provider_keyboard = await build_provider_keyboard(agent)
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Selected: {get_agent_display_name(agent)}\n\n{provider_text}",
            reply_markup=provider_keyboard
        )
        return

    if action == "select_provider":
        agent = cb["agent"]
        provider_id = cb["provider"]
        await bot.answer_callback_query(callback_id)
        from keyboards import build_model_keyboard
        model_text, model_keyboard = await build_model_keyboard(agent, provider_id)
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Provider: {provider_id}\n\n{model_text}",
            reply_markup=model_keyboard
        )
        return

    if action == "select_model":
        agent = cb["agent"]
        provider_id = cb["provider"]
        model_id = cb["model"]
        model_value = f"{provider_id}/{model_id}"

        modes = await AgentClient.get_agent_modes(agent)
        from keyboards import build_mode_keyboard
        mode_text, mode_keyboard = build_mode_keyboard(agent, modes)

        await bot.answer_callback_query(callback_id)
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Selected: {get_agent_display_name(agent)} (model: {model_value})\n\n{mode_text}",
            reply_markup=mode_keyboard
        )
        return

    if action == "mode":
        agent = cb["agent"]
        mode = cb["mode"]
        model = cb.get("model")

        await bot.answer_callback_query(callback_id)

        existing_sessions = await AgentClient.get_agent_sessions(agent)

        if not existing_sessions:
            await bot.edit_message_text(
                chat_id=chat_id,
                message_id=message_id,
                text=f"Connecting to {get_agent_display_name(agent)}..."
            )
            session_id = await AgentClient.create_session(agent)
            if not session_id:
                await bot.edit_message_text(chat_id=chat_id, message_id=message_id, text="❌ Failed to connect")
                return

            sessions = await AgentClient.get_agent_sessions(agent)
            title = "Untitled"
            for s in sessions:
                if s.get("id") == session_id:
                    title = s.get("title", "Untitled")
                    break

            chat_id_str = str(chat_id)
            if chat_id_str not in conversation_state:
                conversation_state[chat_id_str] = ConversationState(
                    active_agent=agent,
                    sessions={}
                ).__dict__

            conversation_state[chat_id_str]["sessions"][agent] = SessionInfo(
                session_id=session_id,
                mode=mode,
                model=model,
                title=title,
                last_message_id=None
            ).__dict__
            conversation_state[chat_id_str]["active_agent"] = agent

            # Save session metadata for logging
            folder_name = save_session_metadata(session_id, agent, title, mode)
            if folder_name:
                conversation_state[chat_id_str]["sessions"][agent]["folder_name"] = folder_name

            model_info = f" (model: {model})" if model else ""
            await bot.edit_message_text(
                chat_id=chat_id,
                message_id=message_id,
                text=f"✅ Connected to {get_agent_display_name(agent)} ({mode.capitalize()} mode{model_info})\n\nWhat would you like to tell them?"
            )
            return

        text = f"Selected: {get_agent_display_name(agent)} ({mode.capitalize()})\n\nChoose a session or create a new one:"
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=text,
            reply_markup=build_session_selection_keyboard(agent, mode, existing_sessions, model)
        )
        return

    if action == "session":
        agent = cb["agent"]
        mode = cb["mode"]
        session_id = cb["session_id"]

        # Check if already active session
        chat_id_str = str(chat_id)
        if chat_id_str in conversation_state:
            state = conversation_state[chat_id_str]
            if state.get("active_agent") == agent:
                current_session = state.get("sessions", {}).get(agent, {})
                if current_session.get("session_id") == session_id:
                    await bot.answer_callback_query(callback_id, text="Already on this session")
                    return

        sessions = await AgentClient.get_agent_sessions(agent)
        title = "Untitled"
        for s in sessions:
            if s.get("id") == session_id:
                title = s.get("title", "Untitled")
                break

        if chat_id_str not in conversation_state:
            conversation_state[chat_id_str] = ConversationState(
                active_agent=agent,
                sessions={}
            ).__dict__

        conversation_state[chat_id_str]["sessions"][agent] = SessionInfo(
            session_id=session_id,
            mode=mode,
            model=cb.get("model"),
            title=title,
            last_message_id=None
        ).__dict__
        conversation_state[chat_id_str]["active_agent"] = agent

        # Save session metadata for logging
        folder_name = save_session_metadata(session_id, agent, title, mode)
        if folder_name:
            conversation_state[chat_id_str]["sessions"][agent]["folder_name"] = folder_name

        await bot.answer_callback_query(callback_id, text=f"Switched to {title}")
        # Don't edit the original message - keep the response visible
        await bot.send_message(
            chat_id=chat_id,
            text=f"✅ Switched to {get_agent_display_name(agent)} - '{title}' ({mode.capitalize()} mode)\n\nWhat would you like to tell them?"
        )
        return

    if action == "new_session":
        agent = cb["agent"]
        mode = cb.get("mode")
        model = cb.get("model")

        # If mode is provided, create session directly
        if mode:
            asyncio.create_task(create_and_join_session(bot, chat_id, message_id, callback_id, agent, mode, conversation_state, model))
            return

        # Otherwise ask for mode
        await bot.answer_callback_query(callback_id)
        modes = await AgentClient.get_agent_modes(agent)
        mode_text, mode_keyboard = build_mode_keyboard(agent, modes)
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Select mode for {get_agent_display_name(agent)}:\n\n{mode_text}",
            reply_markup=mode_keyboard
        )
        return

    if action == "delete_session":
        agent = cb["agent"]
        session_id = cb["session_id"]

        success = await AgentClient.delete_agent_session(agent, session_id)

        chat_id_str = str(chat_id)
        if chat_id_str in conversation_state:
            sessions = conversation_state[chat_id_str].get("sessions", {})
            if agent in sessions:
                if sessions[agent].get("session_id") == session_id:
                    del sessions[agent]
                    state = conversation_state[chat_id_str]
                    if state.get("active_agent") == agent:
                        state["active_agent"] = list(sessions.keys())[0] if sessions else None
                    if not sessions:
                        del conversation_state[chat_id_str]

        if success:
            await bot.answer_callback_query(callback_id, text="Session deleted")
        else:
            await bot.answer_callback_query(callback_id, text="Failed to delete session")

        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text="Choose or create a session:",
            reply_markup=await build_sessions_keyboard(conversation_state, chat_id)
        )
        return

    if action == "switchmode":
        new_mode = cb["mode"]

        chat_id_str = str(chat_id)
        if chat_id_str not in conversation_state:
            await bot.answer_callback_query(callback_id, text="No active session")
            return

        state = conversation_state[chat_id_str]
        active_agent = state.get("active_agent")

        if not active_agent or active_agent not in state.get("sessions", {}):
            await bot.answer_callback_query(callback_id, text="No active session")
            return

        # Update mode
        state["sessions"][active_agent]["mode"] = new_mode

        # Get title for confirmation
        session_info = state["sessions"][active_agent]
        title = session_info.get("title", "Untitled")

        # Update metadata
        session_id = session_info.get("session_id")
        if session_id:
            save_session_metadata(session_id, active_agent, title, new_mode)

        await bot.answer_callback_query(callback_id, text=f"Mode switched to {new_mode}")
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"✅ Mode changed to {new_mode.upper()} for '{title}'\n\nWhat would you like to tell them?"
        )
        return

    if action == "switchmodel_provider":
        agent = cb["agent"]
        provider_id = cb["provider"]
        await bot.answer_callback_query(callback_id)
        from keyboards import build_model_keyboard
        model_text, model_keyboard = await build_model_keyboard(agent, provider_id, switch_mode=True)
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Select model from {provider_id}:",
            reply_markup=model_keyboard
        )
        return

    if action == "switchmodel_model":
        agent = cb["agent"]
        provider_id = cb["provider"]
        model_id = cb["model"]
        model_value = f"{provider_id}/{model_id}"

        chat_id_str = str(chat_id)
        if chat_id_str not in conversation_state:
            await bot.answer_callback_query(callback_id, text="No active session")
            return

        state = conversation_state[chat_id_str]
        active_agent = state.get("active_agent")

        if not active_agent or active_agent not in state.get("sessions", {}):
            await bot.answer_callback_query(callback_id, text="No active session")
            return

        state["sessions"][active_agent]["model"] = model_value
        session_info = state["sessions"][active_agent]
        title = session_info.get("title", "Untitled")

        await bot.answer_callback_query(callback_id, text=f"Model set to {model_value}")
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"✅ Model changed to {model_value} for '{title}'\n\nWhat would you like to tell them?"
        )
        return

    if action == "viewlog":
        session_id = cb["session_id"]

        log_file = SESSIONS_DIR / session_id / "conversation.log"

        if log_file.exists():
            await bot.answer_callback_query(callback_id, text="Sending log file...")
            await bot.send_document(
                chat_id=chat_id,
                document=open(log_file, "rb"),
                filename=f"{session_id}.log"
            )
        else:
            await bot.answer_callback_query(callback_id, text="Log file not found")
        return

    if action == "back_to_main":
        # Show sessions overview
        await bot.answer_callback_query(callback_id)
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text="Your sessions:",
            reply_markup=await build_sessions_keyboard(conversation_state, chat_id)
        )
        return

    if data == "refresh_agents":
        # Refresh agents from registry and show updated list
        from config import refresh_agents_cache
        await refresh_agents_cache()
        agents = await get_all_agents()
        await bot.answer_callback_query(callback_id, text="Agents refreshed")
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text="Select a worker:",
            reply_markup=build_agent_selection_keyboard(agents)
        )
        return

    await bot.answer_callback_query(callback_id)
