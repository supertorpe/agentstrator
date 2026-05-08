"""Centralized conversation logging for telegram-bridge.

Usage:
    from session_log import log_conversation, save_metadata
    log_conversation(session_id, "SEND", "hello", mode="plan")
    save_metadata(session_id, "qwen-proxy", "My Session", "plan")
"""

import logging
import json
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger(__name__)

SESSIONS_DIR = Path("/home/user/sessions")


def log_conversation(session_id: str, direction: str, text: str, mode: str = "") -> None:
    """Append a message to the session's conversation.log.

    Args:
        session_id: Unique session identifier (used as directory name).
        direction: "SEND" for user→agent, "RECV" for agent→user.
        text: Message text to log.
        mode: Session mode (e.g. "plan", "build").
    """
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    log_dir = SESSIONS_DIR / session_id
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "conversation.log"

    try:
        with open(log_file, "a") as f:
            f.write(f"[{timestamp}] [{direction}] ({mode}) {text}\n")
    except IOError as e:
        logger.error(f"Failed to write conversation log for {session_id}: {e}")


def save_metadata(session_id: str, agent: str, title: str, mode: str = "") -> None:
    """Write session metadata to metadata.json.

    Args:
        session_id: Unique session identifier.
        agent: Agent name.
        title: Session title.
        mode: Session mode.
    """
    meta_dir = SESSIONS_DIR / session_id
    meta_dir.mkdir(parents=True, exist_ok=True)

    metadata = {
        "agent": agent,
        "title": title,
        "mode": mode,
        "session_id": session_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        with open(meta_dir / "metadata.json", "w") as f:
            json.dump(metadata, f, indent=2)
    except IOError as e:
        logger.error(f"Failed to write metadata for {session_id}: {e}")


def update_title(session_id: str, title: str) -> None:
    """Update the title in an existing metadata.json without overwriting other fields."""
    meta_file = SESSIONS_DIR / session_id / "metadata.json"
    if meta_file.exists():
        try:
            with open(meta_file, "r") as f:
                metadata = json.load(f)
            metadata["title"] = title
            with open(meta_file, "w") as f:
                json.dump(metadata, f, indent=2)
        except (IOError, json.JSONDecodeError) as e:
            logger.error(f"Failed to update title for {session_id}: {e}")
    else:
        # Create minimal metadata
        save_metadata(session_id, "unknown", title)


def list_sessions() -> list[dict]:
    """List all sessions that have a conversation.log.

    Returns:
        List of dicts with keys: session_id, agent, title, mode, created_at, has_log.
    """
    sessions = []
    if not SESSIONS_DIR.exists():
        return sessions

    for entry in sorted(SESSIONS_DIR.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True):
        if not entry.is_dir():
            continue
        log_file = entry / "conversation.log"
        if not log_file.exists():
            continue

        session_id = entry.name
        metadata = {}
        meta_file = entry / "metadata.json"
        if meta_file.exists():
            try:
                with open(meta_file, "r") as f:
                    metadata = json.load(f)
            except (IOError, json.JSONDecodeError):
                pass

        sessions.append({
            "session_id": session_id,
            "agent": metadata.get("agent", "unknown"),
            "title": metadata.get("title", session_id[:20]),
            "mode": metadata.get("mode", ""),
            "created_at": metadata.get("created_at", ""),
            "has_log": True,
        })

    return sessions
