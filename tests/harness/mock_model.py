"""
mock_model.py — Scripted event sequences for deterministic harness testing.

Yields predefined events to simulate multi-agent failure modes:
- Subagent spawn failures (connection errors, timeouts)
- Worktree creation failures (disk full, git errors)
- Teammate TTL timeouts
- Merge conflicts between parallel coders

Usage in tests:
    from tests.harness.mock_model import MockModel, EventSequence

    model = MockModel(EventSequence.spawn_failure(max_retries=3))
    for event in model.events():
        # process event deterministically
        ...
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Generator, Optional


class EventType(Enum):
    """Types of events in the multi-agent lifecycle."""
    SPAWN_REQUEST = "spawn_request"
    SPAWN_SUCCESS = "spawn_success"
    SPAWN_FAILURE = "spawn_failure"
    WORKTREE_CREATE = "worktree_create"
    WORKTREE_SUCCESS = "worktree_success"
    WORKTREE_FAILURE = "worktree_failure"
    HEARTBEAT = "heartbeat"
    TIMEOUT = "timeout"
    COMMIT = "commit"
    MERGE_ATTEMPT = "merge_attempt"
    MERGE_CONFLICT = "merge_conflict"
    MERGE_CLEAN = "merge_clean"
    RETRY = "retry"
    ESCALATE = "escalate"
    ABORT = "abort"
    CLEANUP = "cleanup"


@dataclass
class Event:
    """A single event in the agent lifecycle."""
    type: EventType
    agent: str = ""
    detail: str = ""
    data: dict[str, Any] = field(default_factory=dict)
    timestamp: float = field(default_factory=time.time)

    def to_json(self) -> str:
        return json.dumps({
            "type": self.type.value,
            "agent": self.agent,
            "detail": self.detail,
            "data": self.data,
            "timestamp": self.timestamp,
        })

    @classmethod
    def from_json(cls, raw: str) -> "Event":
        d = json.loads(raw)
        return cls(
            type=EventType(d["type"]),
            agent=d.get("agent", ""),
            detail=d.get("detail", ""),
            data=d.get("data", {}),
            timestamp=d.get("timestamp", time.time()),
        )


class EventSequence:
    """Factory for common failure-mode event sequences."""

    @staticmethod
    def spawn_failure(
        agent: str = "ralph-coder",
        max_retries: int = 3,
        error_type: str = "connection_error",
    ) -> list[Event]:
        """Subagent spawn fails repeatedly → retry 3x → escalate.

        Simulates: connection refused, timeout, API error.
        """
        events = [Event(EventType.SPAWN_REQUEST, agent=agent, detail="spawn requested")]

        for attempt in range(1, max_retries + 1):
            events.append(Event(
                EventType.SPAWN_FAILURE,
                agent=agent,
                detail=f"spawn failed (attempt {attempt}/{max_retries})",
                data={"attempt": attempt, "error": error_type},
            ))
            if attempt < max_retries:
                events.append(Event(
                    EventType.RETRY,
                    agent=agent,
                    detail=f"retrying in {2 ** attempt}s",
                    data={"backoff_seconds": 2 ** attempt},
                ))

        events.append(Event(
            EventType.ESCALATE,
            agent=agent,
            detail=f"spawn failed {max_retries}x, escalating to user",
            data={"max_retries": max_retries, "final_error": error_type},
        ))
        return events

    @staticmethod
    def spawn_success_after_retry(
        agent: str = "ralph-coder",
        fail_count: int = 1,
    ) -> list[Event]:
        """Spawn fails N times then succeeds on retry."""
        events = [Event(EventType.SPAWN_REQUEST, agent=agent)]

        for i in range(1, fail_count + 1):
            events.append(Event(EventType.SPAWN_FAILURE, agent=agent,
                                detail=f"attempt {i}", data={"attempt": i}))
            events.append(Event(EventType.RETRY, agent=agent,
                                detail=f"backoff {2**i}s", data={"backoff_seconds": 2**i}))

        events.append(Event(EventType.SPAWN_SUCCESS, agent=agent,
                            detail="spawned successfully",
                            data={"attempts": fail_count + 1}))
        return events

    @staticmethod
    def worktree_failure(
        agent: str = "ralph-coder",
        error: str = "disk_full",
    ) -> list[Event]:
        """Worktree creation fails → abort cascade.

        Simulates: disk full, git error, permission denied.
        """
        return [
            Event(EventType.SPAWN_SUCCESS, agent=agent),
            Event(EventType.WORKTREE_CREATE, agent=agent,
                  detail="creating worktree", data={"slug": f"wt-{agent}"}),
            Event(EventType.WORKTREE_FAILURE, agent=agent,
                  detail=f"worktree creation failed: {error}",
                  data={"error": error}),
            Event(EventType.ABORT, agent=agent,
                  detail="aborting agent due to worktree failure",
                  data={"reason": error}),
            Event(EventType.CLEANUP, agent=agent,
                  detail="cleaning up partial worktree artifacts"),
        ]

    @staticmethod
    def worktree_success(
        agent: str = "ralph-coder",
        slug: str = "wt-coder-alpha",
    ) -> list[Event]:
        """Worktree created successfully."""
        return [
            Event(EventType.SPAWN_SUCCESS, agent=agent),
            Event(EventType.WORKTREE_CREATE, agent=agent, detail="creating worktree",
                  data={"slug": slug}),
            Event(EventType.WORKTREE_SUCCESS, agent=agent, detail="worktree ready",
                  data={"path": f"/tmp/worktrees/{slug}", "branch": f"worktree-{slug}"}),
        ]

    @staticmethod
    def teammate_timeout(
        agent: str = "ralph-coder",
        ttl_minutes: int = 30,
    ) -> list[Event]:
        """Teammate TTL exceeded → timeout → abort → cleanup."""
        heartbeat_count = ttl_minutes // 5
        events = [Event(EventType.SPAWN_SUCCESS, agent=agent)]

        for i in range(heartbeat_count):
            events.append(Event(
                EventType.HEARTBEAT, agent=agent,
                detail=f"heartbeat {i+1}/{heartbeat_count}",
                data={"elapsed_minutes": (i + 1) * 5},
            ))

        events.extend([
            Event(EventType.TIMEOUT, agent=agent,
                  detail=f"TTL exceeded ({ttl_minutes}min)",
                  data={"ttl_minutes": ttl_minutes}),
            Event(EventType.ABORT, agent=agent,
                  detail="aborting timed-out teammate"),
            Event(EventType.CLEANUP, agent=agent,
                  detail="cleaning up worktree and branch",
                  data={"remove_branch": True}),
        ])
        return events

    @staticmethod
    def merge_conflict(
        agent_a: str = "ralph-coder-alpha",
        agent_b: str = "ralph-coder-beta",
        conflicting_file: str = "src/main.py",
    ) -> list[Event]:
        """Two coders produce merge conflict → detection works."""
        return [
            Event(EventType.SPAWN_SUCCESS, agent=agent_a),
            Event(EventType.SPAWN_SUCCESS, agent=agent_b),
            Event(EventType.WORKTREE_SUCCESS, agent=agent_a,
                  data={"path": f"/tmp/wt-{agent_a}"}),
            Event(EventType.WORKTREE_SUCCESS, agent=agent_b,
                  data={"path": f"/tmp/wt-{agent_b}"}),
            Event(EventType.COMMIT, agent=agent_a,
                  detail="committed changes",
                  data={"files": [conflicting_file], "branch": f"wt-{agent_a}"}),
            Event(EventType.COMMIT, agent=agent_b,
                  detail="committed changes",
                  data={"files": [conflicting_file], "branch": f"wt-{agent_b}"}),
            Event(EventType.MERGE_ATTEMPT, agent=agent_a,
                  detail=f"merging {agent_b} into main"),
            Event(EventType.MERGE_CONFLICT, agent=agent_a,
                  detail=f"conflict in {conflicting_file}",
                  data={"conflicting_files": [conflicting_file],
                        "source_branch": f"wt-{agent_b}"}),
        ]

    @staticmethod
    def merge_clean(
        agent_a: str = "ralph-coder-alpha",
        agent_b: str = "ralph-coder-beta",
    ) -> list[Event]:
        """Two coders work on different files → clean merge."""
        return [
            Event(EventType.SPAWN_SUCCESS, agent=agent_a),
            Event(EventType.SPAWN_SUCCESS, agent=agent_b),
            Event(EventType.COMMIT, agent=agent_a,
                  detail="committed changes",
                  data={"files": ["src/auth.py"], "branch": f"wt-{agent_a}"}),
            Event(EventType.COMMIT, agent=agent_b,
                  detail="committed changes",
                  data={"files": ["src/api.py"], "branch": f"wt-{agent_b}"}),
            Event(EventType.MERGE_ATTEMPT, agent=agent_a,
                  detail=f"merging {agent_b}"),
            Event(EventType.MERGE_CLEAN, agent=agent_a,
                  detail="merge successful, no conflicts"),
        ]


class MockModel:
    """Deterministic model that replays scripted event sequences.

    Usage:
        model = MockModel(events)
        for event in model.events():
            assert event.type == EventType.SPAWN_FAILURE
    """

    def __init__(self, events: list[Event]):
        self._events = events
        self._cursor = 0

    def events(self) -> Generator[Event, None, None]:
        """Yield events one at a time."""
        for event in self._events:
            self._cursor += 1
            yield event

    @property
    def cursor(self) -> int:
        return self._cursor

    @property
    def total(self) -> int:
        return len(self._events)

    def event_at(self, index: int) -> Event:
        """Get event at specific index."""
        return self._events[index]

    def events_of_type(self, event_type: EventType) -> list[Event]:
        """Filter events by type."""
        return [e for e in self._events if e.type == event_type]

    def has_event(self, event_type: EventType) -> bool:
        """Check if sequence contains a specific event type."""
        return any(e.type == event_type for e in self._events)

    def first(self, event_type: EventType) -> Optional[Event]:
        """Get first event of a given type, or None."""
        for e in self._events:
            if e.type == event_type:
                return e
        return None

    def count(self, event_type: EventType) -> int:
        """Count occurrences of an event type."""
        return sum(1 for e in self._events if e.type == event_type)

    def to_json(self) -> str:
        """Serialize entire sequence to JSON."""
        return json.dumps([{
            "type": e.type.value,
            "agent": e.agent,
            "detail": e.detail,
            "data": e.data,
        } for e in self._events])

    @classmethod
    def from_json(cls, raw: str) -> "MockModel":
        """Deserialize from JSON."""
        items = json.loads(raw)
        events = [Event(
            type=EventType(i["type"]),
            agent=i.get("agent", ""),
            detail=i.get("detail", ""),
            data=i.get("data", {}),
        ) for i in items]
        return cls(events)
