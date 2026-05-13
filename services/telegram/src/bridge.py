import asyncio
import logging
from typing import Optional

from telegram import Bot

from sse import SSEManager

from handlers.command import handle_command
from handlers.callback import handle_callback
from handlers.message import handle_message

logger = logging.getLogger(__name__)


class TelegramBridge:
    def __init__(self, bot_token: str, allowed_users: Optional[set] = None):
        self.bot = Bot(token=bot_token)
        self.allowed_users = allowed_users
        self.conversation_state = {}
        self.offset = 0
        self.sse_manager = None

    async def handle_command(self, chat_id: int, username: str, text: str):
        """Handle commands."""
        await handle_command(self.bot, chat_id, username, text, self.allowed_users, self.conversation_state)

    async def handle_callback(self, callback_id: str, chat_id: int, message_id: int, data: str):
        """Handle callback query."""
        await handle_callback(
            self.bot,
            callback_id,
            chat_id,
            message_id,
            data,
            self.conversation_state,
        )

    async def handle_message(self, chat_id: int, username: str, text: str):
        """Handle regular message."""
        await handle_message(
            self.bot,
            chat_id,
            username,
            text,
            self.allowed_users,
            self.conversation_state,
        )

    async def poll(self):
        """Poll for updates."""
        self.sse_manager = SSEManager(self)
        asyncio.create_task(self.sse_manager.start())
        from handlers.message import clean_stale_pending_messages
        asyncio.create_task(clean_stale_pending_messages())

        logger.info("Starting polling...")

        while True:
            try:
                logger.info("Polling...")
                updates = await self.bot.get_updates(
                    offset=self.offset + 1,
                    timeout=10,
                    allowed_updates=["message", "callback_query", "edited_message", "channel_post"]
                )
                logger.info(f"Got {len(updates)} updates")

                for update in updates:
                    self.offset = update.update_id

                    update_type = "unknown"
                    if update.callback_query:
                        update_type = "callback_query"
                    elif update.message:
                        update_type = "message"
                    elif update.edited_message:
                        update_type = "edited_message"
                    elif update.channel_post:
                        update_type = "channel_post"

                    logger.info(f"Processing update #{update.update_id}: type={update_type}")

                    if update.callback_query:
                        cb = update.callback_query
                        logger.info(f"!!! HAS CALLBACK: {cb.data} from chat {cb.message.chat.id if cb.message else 'unknown'}")
                        try:
                            await self.handle_callback(
                                cb.id,
                                cb.message.chat.id if cb.message else 0,
                                cb.message.message_id if cb.message else 0,
                                cb.data
                            )
                            logger.info(f"Callback handled successfully")
                        except Exception as e:
                            logger.error(f"Callback handler error: {e}", exc_info=True)
                        continue

                    if update.message and update.message.text:
                        chat_id = update.message.chat.id
                        username = update.message.from_user.username if update.message.from_user else None
                        text = update.message.text
                        logger.info(f"Message from {username}: {text[:50]}...")

                        if text.startswith("/"):
                            await self.handle_command(chat_id, username, text)
                        else:
                            await self.handle_message(chat_id, username, text)

            except Exception as e:
                logger.error(f"Poll error: {e}", exc_info=True)

            await asyncio.sleep(1)
