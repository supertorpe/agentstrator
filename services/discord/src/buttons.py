import logging
from datetime import datetime
from typing import Optional, List, Dict, Any

import discord
from discord import ui

from config import get_all_agents, get_agent_by_name
from client import AgentClient
from session_log import SESSIONS_DIR, list_sessions

logger = logging.getLogger(__name__)

def get_agent_display_name(agent: str) -> str:
    """Get display name for an agent."""
    return agent


class AgentSelectView(ui.View):
    """View for selecting an agent."""

    def __init__(self, bridge, agents: List[Dict[str, Any]]):
        super().__init__(timeout=300)
        self.bridge = bridge
        select = ui.Select(
            placeholder="Select an agent",
            options=[
                discord.SelectOption(
                    label=f"{a.get('display_name', a['name'])}",
                    value=a["name"],
                )
                for a in agents
            ]
        )
        select.callback = self.agent_selected
        self.add_item(select)

    async def agent_selected(self, interaction: discord.Interaction):
        agent_name = self.children[0].values[0]
        modes = await AgentClient.get_agent_modes(agent_name)
        await show_mode_selection(interaction, agent_name, modes, self.bridge)


class ModeSelectView(ui.View):
    """View for selecting a mode."""

    def __init__(self, bridge, agent: str, modes: List[Dict[str, Any]]):
        super().__init__(timeout=300)
        self.bridge = bridge
        self.agent = agent
        select = ui.Select(
            placeholder=f"Select mode for {agent}",
            options=[
                discord.SelectOption(label=m["name"], value=m["name"])
                for m in modes
            ]
        )
        select.callback = self.mode_selected
        self.add_item(select)

    async def mode_selected(self, interaction: discord.Interaction):
        mode_name = self.children[0].values[0]
        await show_session_selection(interaction, self.agent, mode_name, self.bridge)


class SessionSelectView(ui.View):
    """View for selecting or creating a session."""

    def __init__(self, bridge, agent: str, mode: str, sessions: List[Dict[str, Any]]):
        super().__init__(timeout=300)
        self.bridge = bridge
        self.agent = agent
        self.mode = mode

        if sessions:
            select = ui.Select(
                placeholder=f"Select a session for {agent}",
                options=[
                    discord.SelectOption(label=s.get("title", s["id"]), value=s["id"])
                    for s in sessions
                ]
            )
            select.callback = self.session_selected
            self.add_item(select)
        else:
            self.add_item(ui.Select(
                placeholder="No sessions yet — create a new one below",
                options=[discord.SelectOption(label="No sessions available", value="_none", disabled=True)],
            ))

    async def session_selected(self, interaction: discord.Interaction):
        select = interaction.data["values"][0]
        if select == "_none":
            await interaction.response.send_message("Create a new session first.", ephemeral=True)
            return
        await join_session(interaction, self.agent, self.mode, select, self.bridge)

    @ui.button(label="➕ New Session", style=discord.ButtonStyle.primary)
    async def new_session(self, interaction: discord.Interaction, button: ui.Button):
        session_id = await AgentClient.create_session(self.agent)
        if session_id:
            await join_session(interaction, self.agent, self.mode, session_id, self.bridge)
        else:
            await interaction.response.send_message("Failed to create session.", ephemeral=True)


class SessionOverviewView(ui.View):
    """View showing all sessions across all agents."""

    def __init__(self, bridge, conversation_state: dict, user_id: str):
        super().__init__(timeout=300)
        self.bridge = bridge
        self.conversation_state = conversation_state
        self.user_id = user_id

    def _get_active_info(self):
        state = self.conversation_state.get(self.user_id)
        if not state:
            return None, {}
        return state.get("active_agent"), state.get("sessions", {})

    @ui.button(label="🔄 Refresh", style=discord.ButtonStyle.secondary)
    async def refresh(self, interaction: discord.Interaction, button: ui.Button):
        from config import refresh_agents_cache
        await refresh_agents_cache()
        embed = await build_sessions_embed(self.conversation_state, self.user_id)
        await interaction.response.edit_message(embed=embed, view=self)


class ModeSwitchView(ui.View):
    """View for switching between modes."""

    def __init__(self, bridge, current_mode: str, modes: List[Dict[str, Any]]):
        super().__init__(timeout=300)
        self.bridge = bridge
        self.current_mode = current_mode
        for mode in modes:
            mode_name = mode.get("name", "")
            is_active = current_mode == mode_name
            style = discord.ButtonStyle.primary if is_active else discord.ButtonStyle.secondary
            label = f"📋 {mode_name}" + (" [ACTIVE]" if is_active else "")
            self.add_item(ui.Button(
                label=label,
                style=style,
                custom_id="noop" if is_active else f"switchmode:{mode_name}",
                disabled=is_active,
            ))


class LogSelectView(ui.View):
    """View for selecting a session log."""

    def __init__(self):
        super().__init__(timeout=300)

        sessions = list_sessions()
        for session in sessions[:25]:
            session_id = session["session_id"]
            label = _format_log_label(session)
            self.add_item(ui.Button(label=label, style=discord.ButtonStyle.secondary, custom_id=f"viewlog:{session_id}"))


def _format_log_label(session: dict) -> str:
    """Format a log entry label from session metadata dict."""
    agent = session.get("agent", "unknown")
    title = session.get("title", "Untitled")
    display_name = get_agent_display_name(agent)
    created_at = session.get("created_at", "")

    if created_at:
        try:
            dt = datetime.fromisoformat(created_at)
            formatted_time = dt.strftime("%m-%d %H:%M")
            return f"{formatted_time} - {display_name} - {title[:25]}"
        except (ValueError, TypeError):
            pass

    return f"{display_name} - {title[:25]}"


async def build_sessions_embed(conversation_state: dict, user_id: str) -> discord.Embed:
    """Build an embed showing all agent sessions."""
    embed = discord.Embed(title="Sessions Overview", color=discord.Color.blue())
    agents = await get_all_agents()

    if not agents:
        embed.description = "Use /agents to start"
        return embed

    active_agent, active_sessions = None, {}
    state = conversation_state.get(user_id)
    if state:
        active_agent = state.get("active_agent")
        active_sessions = state.get("sessions", {})

    for agent in agents:
        agent_name = agent.get("name", "")
        display_name = agent.get("display_name", agent_name)

        sessions = await AgentClient.get_agent_sessions(agent_name)
        field_value = ""
        for session in sessions:
            session_id = session.get("id", "")
            title = session.get("title", "Unknown")
            is_active = active_agent == agent_name and active_sessions.get(agent_name, {}).get("session_id") == session_id
            marker = " [ACTIVE]" if is_active else ""
            field_value += f"• {title}{marker}\n"

        if not field_value:
            field_value = "No sessions"

        embed.add_field(name=f"{display_name}", value=field_value, inline=False)

    return embed


async def show_mode_selection(interaction, agent_name: str, modes: List[Dict[str, Any]], bridge):
    """Show mode selection for an agent."""
    text_lines = ["Available modes:\n"]
    for mode in modes:
        mode_name = mode.get("name", "")
        mode_desc = mode.get("description", "")
        text_lines.append(f"• {mode_name}")
        if mode_desc:
            text_lines.append(f"  {mode_desc}")
        text_lines.append("")

    await interaction.response.send_message(
        f"**{get_agent_display_name(agent_name)}**\n" + "\n".join(text_lines),
        view=ModeSelectView(bridge, agent_name, modes),
        ephemeral=True,
    )


async def show_session_selection(interaction, agent_name: str, mode: str, bridge):
    """Show session selection for an agent and mode."""
    sessions = await AgentClient.get_agent_sessions(agent_name)
    await interaction.response.send_message(
        f"**{get_agent_display_name(agent_name)}** - Mode: **{mode}**",
        view=SessionSelectView(bridge, agent_name, mode, sessions),
        ephemeral=True,
    )


async def join_session(interaction, agent_name: str, mode: str, session_id: str, bridge):
    """Join a session and update conversation state."""
    from models import ConversationState, SessionInfo

    key = _get_state_key(interaction)
    if key not in bridge.conversation_state:
        bridge.conversation_state[key] = ConversationState()

    state = bridge.conversation_state[key]
    state.active_agent = agent_name
    state.sessions[agent_name] = SessionInfo(
        session_id=session_id,
        mode=mode,
        title=f"Session {session_id[:8]}",
    )

    await interaction.response.send_message(
        f"Joined session in **{get_agent_display_name(agent_name)}** (mode: {mode}).\nYou can now send messages.",
        ephemeral=True,
    )


def _get_state_key(interaction) -> str:
    """Get the conversation state key based on channel or DM."""
    if interaction.guild_id:
        return f"channel:{interaction.channel_id}"
    return f"dm:{interaction.user.id}"
