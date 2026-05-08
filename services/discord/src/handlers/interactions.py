import logging

import discord
from discord import ui

from config import SESSIONS_DIR, get_all_agents
from client import AgentClient
from buttons import (
    show_mode_selection,
    show_session_selection,
    join_session,
    _get_state_key,
)

logger = logging.getLogger(__name__)


def setup_interactions(bridge):
    """Register button/interaction handlers."""

    @bridge.bot.tree.error
    async def on_interaction_error(interaction: discord.Interaction, error):
        logger.error(f"Interaction error: {error}", exc_info=True)
        if interaction.response.is_done():
            await interaction.followup.send("An error occurred.", ephemeral=True)
        else:
            await interaction.response.send_message("An error occurred.", ephemeral=True)

    async def handle_callback(interaction: discord.Interaction, callback_data: str):
        """Route callback to appropriate handler."""
        parts = callback_data.split(":")
        prefix = parts[0]

        if prefix == "noop":
            await interaction.response.send_message("No action needed.", ephemeral=True)

        elif prefix == "select":
            agent_name = parts[1]
            modes = await AgentClient.get_agent_modes(agent_name)
            await show_mode_selection(interaction, agent_name, modes, bridge)

        elif prefix == "mode":
            agent_name = parts[1]
            mode_name = parts[2]
            await show_session_selection(interaction, agent_name, mode_name, bridge)

        elif prefix == "session":
            agent_name = parts[1]
            mode_name = parts[2]
            session_id = parts[3]
            await join_session(interaction, agent_name, mode_name, session_id, bridge)

        elif prefix == "new_session":
            agent_name = parts[1]
            mode_name = parts[2]
            await interaction.response.defer(ephemeral=True)
            session_id = await AgentClient.create_session(agent_name)
            if session_id:
                await join_session(interaction, agent_name, mode_name, session_id, bridge)
            else:
                await interaction.followup.send("Failed to create session.", ephemeral=True)

        elif prefix == "delete_session":
            agent_name = parts[1]
            session_id = parts[2]
            await interaction.response.defer(ephemeral=True)
            success = await AgentClient.delete_agent_session(agent_name, session_id)
            if success:
                key = _get_state_key(interaction)
                state = bridge.conversation_state.get(key)
                if state and state.sessions.get(agent_name, {}).get("session_id") == session_id:
                    del state.sessions[agent_name]
                await interaction.followup.send("Session deleted.", ephemeral=True)
            else:
                await interaction.followup.send("Failed to delete session.", ephemeral=True)

        elif prefix == "switchmode":
            mode_name = parts[1]
            key = _get_state_key(interaction)
            state = bridge.conversation_state.get(key)
            if state and state.active_agent:
                session_info = state.sessions.get(state.active_agent)
                if session_info:
                    session_info.mode = mode_name
                    await interaction.response.send_message(
                        f"Switched to mode: **{mode_name}**",
                        ephemeral=True,
                    )
                    return
            await interaction.response.send_message("No active session to switch mode.", ephemeral=True)

        elif prefix == "viewlog":
            session_id = ":".join(parts[1:])
            await interaction.response.defer(ephemeral=True)
            log_path = SESSIONS_DIR / session_id / "conversation.log"
            if log_path.exists():
                await interaction.followup.send(
                    file=discord.File(str(log_path), filename=f"{session_id}.log"),
                    ephemeral=True,
                )
            else:
                await interaction.followup.send("Log file not found.", ephemeral=True)

        elif prefix == "refresh_agents":
            await interaction.response.defer(ephemeral=True)
            await get_all_agents(force_refresh=True)
            await interaction.followup.send("Agent cache refreshed.", ephemeral=True)

        else:
            await interaction.response.send_message(f"Unknown action: {prefix}", ephemeral=True)

    @bridge.bot.event
    async def on_interaction(interaction: discord.Interaction):
        if interaction.type in (discord.InteractionType.component, discord.InteractionType.modal_submit):
            custom_id = interaction.data.get("custom_id", "")
            if custom_id and ":" in custom_id:
                await handle_callback(interaction, custom_id)
