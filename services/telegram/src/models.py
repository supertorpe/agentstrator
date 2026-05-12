from typing import Optional, Dict, Any
from dataclasses import dataclass, field


@dataclass
class SessionInfo:
    session_id: str
    mode: str
    title: str
    model: Optional[str] = None
    last_message_id: Optional[str] = None


@dataclass
class ConversationState:
    active_agent: Optional[str] = None
    sessions: Dict[str, SessionInfo] = field(default_factory=dict)


@dataclass
class AgentSession:
    id: str
    title: str
    slug: Optional[str] = None
    project_id: Optional[str] = None
    directory: Optional[str] = None
    version: Optional[str] = None
    summary: Optional[Dict[str, Any]] = None
    time: Optional[Dict[str, Any]] = None
