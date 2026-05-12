import logging

import discord

from config import get_all_agents
from client import AgentClient
from models import ConversationState, SessionInfo
from buttons import _get_state_key
from session_log import log_conversation, save_metadata

logger = logging.getLogger(__name__)


def setup_message_handler(bridge):
    """Register the on_message event handler."""

    @bridge.bot.listen()
    async def on_message(message: discord.Message):
        logger.info(f"on_message: author={message.author.name}, content='{message.content[:50]}'")

        if message.author == bridge.bot.user:
            return

        if message.author.bot:
            return

        if not message.content or not message.content.strip():
            return

        logger.info(f"Processing message from {message.author.name} in channel {message.channel.id}, guild={message.guild}")

        # Check if bot is mentioned
        bot_mentioned = bridge.bot.user in message.mentions
        mention_str = f"<@{bridge.bot.user.id}>"
        mention_str_alt = f"<@!{bridge.bot.user.id}>"
        mention_in_content = mention_str in message.content or mention_str_alt in message.content

        logger.info(f"Mentions check: bot_mentioned={bot_mentioned}, mention_in_content={mention_in_content}")

        if message.guild and (bot_mentioned or mention_in_content):
            logger.info(f"Bot mentioned - routing to agent")
            mention_to_remove = mention_str if mention_str in message.content else mention_str_alt
            content = message.content.replace(mention_to_remove, "").strip()
            if not content:
                await message.channel.send(
                    f"Hi! Use `/agents` to select an agent, then mention me to start chatting."
                )
                return

            key = f"channel:{message.channel.id}"
            state = bridge.conversation_state.get(key)
            if state and state.active_agent:
                agent_name = state.active_agent
                session_info = state.sessions.get(agent_name)
                if session_info:
                    logger.info(f"Routing to {agent_name}")
                    bridge.bot.loop.create_task(
                        _send_to_agent(bridge, message, key, agent_name, session_info, content)
                    )
                    return
            else:
                await message.channel.send(
                    f"No active agent in this channel. Use `/agents` to select one, then mention {bridge.bot.user.mention} to chat."
                )
                return

        # Regular channel/DM routing
        if message.guild:
            key = f"channel:{message.channel.id}"
        else:
            key = f"dm:{message.author.id}"

        logger.debug(f"Message received: author={message.author.name}, guild={message.guild}, key={key}, content={message.content[:50]}")

        if not _is_allowed(message, bridge.allowed_users):
            logger.debug(f"User {message.author.name} not in allowed users")
            return

        state = bridge.conversation_state.get(key)
        logger.debug(f"Conversation state for key={key}: {state}")
        if not state or not state.active_agent:
            if message.guild:
                await message.channel.send(
                    f"No active agent in this channel. Mention {bridge.bot.user.mention} with a session active, or use `/agents` to start."
                )
            else:
                await message.channel.send(
                    f"Start a session with an agent first. Use `/agents` to get started."
                )
            return

        agent_name = state.active_agent
        session_info = state.sessions.get(agent_name)
        if not session_info:
            logger.debug(f"No session info for agent={agent_name}")
            return

        logger.info(f"Routing message to agent={agent_name}, session={session_info.session_id}")
        bridge.bot.loop.create_task(
            _send_to_agent(bridge, message, key, agent_name, session_info, message.content)
        )

    async def _send_to_agent(bridge, message, key, agent_name, session_info, text):
        """Send message to agent and respond."""
        log_conversation(session_info.session_id, "SEND", text, session_info.mode)

        try:
            response = await AgentClient.send_message(
                agent_name,
                session_info.session_id,
                session_info.mode,
                text,
                model=session_info.model,
            )

            if response.status_code == 200:
                data = response.json()
                parts = data.get("parts", [])
                response_text = ""
                for part in parts:
                    if part.get("type") == "text":
                        response_text += part.get("text", "")

                if not response_text:
                    response_text = "_Agent responded with no text output._"

                log_conversation(session_info.session_id, "RECV", response_text, session_info.mode)

                title = data.get("title")
                if title and title != session_info.title:
                    session_info.title = title
                    save_metadata(session_info.session_id, agent_name, title, session_info.mode)

                if len(response_text) > 2000:
                    chunks = [response_text[i:i+1900] for i in range(0, len(response_text), 1900)]
                    for chunk in chunks:
                        await message.channel.send(chunk)
                else:
                    await message.channel.send(response_text)
            else:
                await message.channel.send(
                    f"Error from agent: HTTP {response.status_code}"
                )

        except Exception as e:
            logger.error(f"Error sending message to agent: {e}", exc_info=True)
            await message.channel.send("Error communicating with agent.")

    def _is_allowed(message: discord.Message, allowed_users: set | None) -> bool:
        """Check if the user is allowed."""
        if allowed_users is None:
            return True
        user_id = str(message.author.id)
        username = message.author.name
        return user_id in allowed_users or username in allowed_users
