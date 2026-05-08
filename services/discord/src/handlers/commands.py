import logging
import discord

from config import get_all_agents, refresh_agents_cache
from client import AgentClient
from buttons import (
    AgentSelectView,
    SessionOverviewView,
    ModeSwitchView,
    LogSelectView,
    build_sessions_embed,
    _get_state_key,
)

logger = logging.getLogger(__name__)


def setup_commands(bridge):
    """Register slash commands with the bot."""

    @bridge.bot.tree.command(name="help", description="Show available commands")
    async def help_command(interaction: discord.Interaction):
        embed = discord.Embed(
            title="Agentstrator Commands",
            color=discord.Color.blue(),
            description=(
                "**/agents** - Select an agent to interact with\n"
                "**/sessions** - View and manage your sessions\n"
                "**/mode** - Switch the active session mode\n"
                "**/log** - View session conversation logs\n"
                "**/help** - Show this help message\n"
                "\n*Tip: Once a session is active, mention the bot with @ to send messages.*"
            )
        )
        await interaction.response.send_message(embed=embed, ephemeral=True)

    @bridge.bot.tree.command(name="agents", description="Select an agent to interact with")
    async def agents_command(interaction: discord.Interaction):
        if not _is_allowed(interaction, bridge.allowed_users):
            await interaction.response.send_message("You are not authorized to use this bot.", ephemeral=True)
            return

        await interaction.response.defer(ephemeral=True)
        await refresh_agents_cache()
        agents = await get_all_agents()

        if not agents:
            await interaction.followup.send("No agents available. Make sure workers are registered.", ephemeral=True)
            return

        await interaction.followup.send(
            "Select an agent:",
            view=AgentSelectView(bridge, agents),
            ephemeral=True,
        )

    @bridge.bot.tree.command(name="sessions", description="View and manage sessions")
    async def sessions_command(interaction: discord.Interaction):
        if not _is_allowed(interaction, bridge.allowed_users):
            await interaction.response.send_message("You are not authorized to use this bot.", ephemeral=True)
            return

        await interaction.response.defer(ephemeral=True)
        key = _get_state_key(interaction)
        embed = await build_sessions_embed(bridge.conversation_state, key)
        view = SessionOverviewView(bridge, bridge.conversation_state, key)
        await interaction.followup.send(embed=embed, view=view, ephemeral=True)

    @bridge.bot.tree.command(name="mode", description="Switch the active session mode")
    async def mode_command(interaction: discord.Interaction):
        if not _is_allowed(interaction, bridge.allowed_users):
            await interaction.response.send_message("You are not authorized to use this bot.", ephemeral=True)
            return

        key = _get_state_key(interaction)
        state = bridge.conversation_state.get(key)

        if not state or not state.active_agent:
            await interaction.response.send_message(
                "No active session. Use /agents to select an agent first.",
                ephemeral=True,
            )
            return

        agent_name = state.active_agent
        session_info = state.sessions.get(agent_name)
        if not session_info:
            await interaction.response.send_message("No session info found.", ephemeral=True)
            return

        modes = await AgentClient.get_agent_modes(agent_name)
        await interaction.response.send_message(
            f"Switch mode for **{agent_name}** (current: {session_info.mode}):",
            view=ModeSwitchView(bridge, session_info.mode, modes),
            ephemeral=True,
        )

    @bridge.bot.tree.command(name="log", description="View session conversation logs")
    async def log_command(interaction: discord.Interaction):
        if not _is_allowed(interaction, bridge.allowed_users):
            await interaction.response.send_message("You are not authorized to use this bot.", ephemeral=True)
            return

        await interaction.response.send_message(
            "Select a session log:",
            view=LogSelectView(),
            ephemeral=True,
        )


def _is_allowed(interaction: discord.Interaction, allowed_users: set | None) -> bool:
    """Check if the user is allowed to use the bot."""
    if allowed_users is None:
        return True
    user_id = str(interaction.user.id)
    username = interaction.user.name
    return user_id in allowed_users or username in allowed_users
