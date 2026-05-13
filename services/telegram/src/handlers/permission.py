import logging

from telegram import InlineKeyboardButton, InlineKeyboardMarkup

from keyboards import store_callback_data

logger = logging.getLogger(__name__)


async def show_permission_prompt(
    bot,
    chat_id: int,
    agent_name: str,
    request_id: str,
    permission: str,
    patterns: str,
    is_active: bool,
):
    """Show a permission prompt in a Telegram chat."""
    text = (
        f"\U0001F512 *{agent_name}* needs permission: `{permission}`\n"
        f"Path: `{patterns}`"
    )

    if is_active:
        text += "\n\nHow do you want to handle this?"
        keyboard = [
            [InlineKeyboardButton(
                "\U00002705 Allow Once",
                callback_data=store_callback_data({
                    "action": "permission_reply",
                    "agent": agent_name,
                    "request_id": request_id,
                    "reply": "once",
                }),
            )],
            [InlineKeyboardButton(
                "\U0001F501 Always Allow",
                callback_data=store_callback_data({
                    "action": "permission_reply",
                    "agent": agent_name,
                    "request_id": request_id,
                    "reply": "always",
                }),
            )],
            [InlineKeyboardButton(
                "\U0000274C Deny",
                callback_data=store_callback_data({
                    "action": "permission_reply",
                    "agent": agent_name,
                    "request_id": request_id,
                    "reply": "reject",
                }),
            )],
        ]
        await bot.send_message(
            chat_id=chat_id,
            text=text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown",
        )
    else:
        text += (
            "\n\nThis is not your active agent. "
            f"Use /agents to switch to *{agent_name}* to respond."
        )
        await bot.send_message(
            chat_id=chat_id,
            text=text,
            parse_mode="Markdown",
        )
