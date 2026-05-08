import logging
from typing import Optional

import discord
from discord.ext import commands

from handlers.commands import setup_commands
from handlers.interactions import setup_interactions
from handlers.messages import setup_message_handler

logger = logging.getLogger(__name__)


class DiscordBridge:
    def __init__(self, bot_token: str, allowed_users: Optional[set] = None):
        self.bot = None
        self.allowed_users = allowed_users
        self.conversation_state = {}
        self.token = bot_token
        self._message_content_enabled = True

    def _create_bot(self, message_content: bool = True):
        intents = discord.Intents.all()
        intents.guilds = True
        intents.guild_messages = True
        intents.dm_messages = True
        intents.message_content = message_content
        intents.messages = True
        intents.members = True
        intents.typing = False
        intents.voice_states = False
        intents.webhooks = False
        intents.presences = False
        bot = commands.Bot(command_prefix="!", intents=intents)
        logger.info(f"Created commands.Bot with intents")
        return bot

    async def start_bridge(self):
        logger.info("Creating bot...")
        self.bot = self._create_bot(self._message_content_enabled)
        logger.info(f"Bot created, setting up handlers")

        setup_commands(self)
        setup_interactions(self)
        setup_message_handler(self)
        logger.info("Handlers setup complete")

        @self.bot.event
        async def on_ready():
            logger.info(f"Discord Bridge logged in as {self.bot.user}")
            logger.info(f"Intents: message_content={self._message_content_enabled}")
            try:
                synced = await self.bot.tree.sync()
                logger.info(f"Synced {len(synced)} slash commands")
            except Exception as e:
                logger.error(f"Failed to sync commands: {e}", exc_info=True)

        try:
            await self.bot.start(self.token)
        except discord.errors.PrivilegedIntentsRequired:
            logger.warning("PrivilegedIntentsRequired")
            if self._message_content_enabled:
                self._message_content_enabled = False
                self.bot = self._create_bot(False)
                setup_commands(self)
                setup_interactions(self)
                setup_message_handler(self)

                @self.bot.event
                async def on_ready():
                    logger.info(f"Discord Bridge logged in as {self.bot.user} (fallback)")
                    try:
                        synced = await self.bot.tree.sync()
                        logger.info(f"Synced {len(synced)} slash commands")
                    except Exception as e:
                        logger.error(f"Failed to sync: {e}", exc_info=True)

                await self.bot.start(self.token)
            else:
                raise
