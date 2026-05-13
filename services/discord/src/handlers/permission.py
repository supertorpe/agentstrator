import logging
from typing import Optional

import discord
from discord import ui

from client import AgentClient

logger = logging.getLogger(__name__)


class PermissionResponseView(ui.View):
    """View for responding to a permission request."""

    def __init__(self, bridge, agent_name: str, request_id: str, permission: str, patterns: str):
        super().__init__(timeout=300)
        self.bridge = bridge
        self.agent_name = agent_name
        self.request_id = request_id
        self.permission = permission
        self.patterns = patterns

    @ui.button(label="\U00002705 Allow Once", style=discord.ButtonStyle.success)
    async def allow_once(self, interaction: discord.Interaction, button: ui.Button):
        success = await AgentClient.reply_permission(self.agent_name, self.request_id, "once")
        if success:
            await interaction.response.edit_message(
                content=f"\U00002705 Allowed {self.permission} access to {self.patterns} (once)",
                view=None,
            )
        else:
            await interaction.response.send_message("\U0000274C Failed to send response", ephemeral=True)

    @ui.button(label="\U0001F501 Always Allow", style=discord.ButtonStyle.primary)
    async def always_allow(self, interaction: discord.Interaction, button: ui.Button):
        success = await AgentClient.reply_permission(self.agent_name, self.request_id, "always")
        if success:
            await interaction.response.edit_message(
                content=f"\U0001F501 Always allowing {self.permission} access to {self.patterns}",
                view=None,
            )
        else:
            await interaction.response.send_message("\U0000274C Failed to send response", ephemeral=True)

    @ui.button(label="\U0000274C Deny", style=discord.ButtonStyle.danger)
    async def deny(self, interaction: discord.Interaction, button: ui.Button):
        success = await AgentClient.reply_permission(self.agent_name, self.request_id, "reject")
        if success:
            await interaction.response.edit_message(
                content=f"\U0000274C Denied {self.permission} access to {self.patterns}",
                view=None,
            )
        else:
            await interaction.response.send_message("\U0000274C Failed to send response", ephemeral=True)


async def show_permission_prompt(
    bridge,
    chat_key: str,
    agent_name: str,
    request_id: str,
    permission: str,
    patterns: str,
    is_active: bool,
):
    """Show a permission prompt in the appropriate Discord channel/DM."""
    if chat_key.startswith("channel:"):
        channel_id = int(chat_key[8:])
        channel = bridge.bot.get_channel(channel_id)
        if not channel:
            try:
                channel = await bridge.bot.fetch_channel(channel_id)
            except Exception as e:
                logger.error(f"Failed to fetch channel {channel_id}: {e}")
                return
    elif chat_key.startswith("dm:"):
        user_id = int(chat_key[3:])
        try:
            user = await bridge.bot.fetch_user(user_id)
            channel = user.dm_channel or await user.create_dm()
        except Exception as e:
            logger.error(f"Failed to fetch user {user_id}: {e}")
            return
    else:
        return

    if is_active:
        text = (
            f"\U0001F512 **{agent_name}** needs permission: `{permission}`\n"
            f"Path: `{patterns}`\n\n"
            f"How do you want to handle this?"
        )
        await channel.send(text, view=PermissionResponseView(bridge, agent_name, request_id, permission, patterns))
    else:
        text = (
            f"\U0001F512 **{agent_name}** needs permission: `{permission}`\n"
            f"Path: `{patterns}`\n\n"
            f"This is not your active agent. Use `/agents` to switch to **{agent_name}** to respond."
        )
        await channel.send(text)
