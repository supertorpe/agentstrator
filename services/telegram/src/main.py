import os
import logging
import asyncio
from dotenv import load_dotenv

from bridge import TelegramBridge
from config import get_all_agents, refresh_agents_cache

load_dotenv()

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)


async def main():
    bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
    allowed_users_raw = os.getenv("ALLOWED_USERS")

    if not bot_token:
        logger.error("TELEGRAM_BOT_TOKEN not set")
        return

    allowed_users = None
    if allowed_users_raw:
        allowed_users = set(u.strip() for u in allowed_users_raw.split(",") if u.strip())

    logger.info("Starting Telegram Bridge")

    # Refresh agents from registry on startup
    try:
        agents = await get_all_agents()
        logger.info(f"Discovered {len(agents)} agents from registry:")
        for agent in agents:
            logger.info(f"  - {agent.get('name')} ({agent.get('url')})")
    except Exception as e:
        logger.warning(f"Failed to query registry on startup: {e}")

    bridge = TelegramBridge(bot_token, allowed_users)
    await bridge.poll()


if __name__ == "__main__":
    asyncio.run(main())
