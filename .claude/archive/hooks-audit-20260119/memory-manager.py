#!/usr/bin/env python3
"""
Memory Manager v2.49.0 - Unified Memory System for Ralph

Implements:
- Hot Path: Real-time memory operations
- Cold Path: Background reflection
- Semantic, Episodic, and Procedural memory stores

Based on @rohit4verse "Stop building Goldfish AI" and LangMem framework.
"""

import json
import os
import sys
import uuid
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any, Literal
from dataclasses import dataclass, asdict, field

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

RALPH_DIR = Path(os.environ.get("RALPH_DIR", Path.home() / ".ralph"))
CONFIG_PATH = RALPH_DIR / "config" / "memory-config.json"
EPISODES_DIR = RALPH_DIR / "episodes"
PROCEDURAL_PATH = RALPH_DIR / "procedural" / "rules.json"
SEMANTIC_PATH = RALPH_DIR / "memory" / "semantic.json"

def load_config() -> Dict[str, Any]:
    """Load memory configuration."""
    if CONFIG_PATH.exists():
        return json.loads(CONFIG_PATH.read_text())
    return {"version": "2.49.0"}

CONFIG = load_config()

# ═══════════════════════════════════════════════════════════════════════════════
# Data Models
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class SemanticFact:
    """A stable piece of knowledge."""
    fact_id: str
    content: str
    category: str  # user_pref, project_fact, tech_decision, team_knowledge
    source: str  # session_id or "imported"
    confidence: float = 1.0
    importance: int = 5
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    ttl_days: Optional[int] = None
    tags: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SemanticFact":
        return cls(**data)


@dataclass
class EpisodeAction:
    """An action taken during an episode."""
    action_type: str  # create, modify, delete, execute, research
    target: str
    description: str
    success: bool = True
    error: Optional[str] = None


@dataclass
class Episode:
    """A complete experience with context."""
    episode_id: str
    timestamp: str
    session_id: str
    project: str

    # Situation
    task: str
    context: str
    constraints: List[str] = field(default_factory=list)

    # Reasoning
    approach: str = ""
    alternatives_considered: List[Dict[str, str]] = field(default_factory=list)
    decision_factors: List[str] = field(default_factory=list)

    # Actions
    actions: List[Dict[str, Any]] = field(default_factory=list)

    # Outcome
    success: bool = True
    tests_passed: Optional[int] = None
    user_satisfaction: Optional[str] = None
    artifacts_created: List[str] = field(default_factory=list)

    # Learnings
    learnings: List[str] = field(default_factory=list)

    # Metadata
    tags: List[str] = field(default_factory=list)
    importance: int = 5
    duration_minutes: Optional[int] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Episode":
        return cls(**data)

    def get_storage_path(self) -> Path:
        """Get the file path for this episode."""
        date_prefix = self.timestamp[:7]  # YYYY-MM
        return EPISODES_DIR / date_prefix / f"{self.episode_id}.json"


@dataclass
class ProceduralRule:
    """A learned behavior pattern."""
    rule_id: str
    trigger: str  # When to apply
    behavior: str  # What to do
    rationale: str  # Why this behavior
    source_episodes: List[str] = field(default_factory=list)
    confidence: float = 0.8
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    last_applied: Optional[str] = None
    times_applied: int = 0
    injection_point: str = "PreToolUse"  # When to inject
    prompt_template: str = ""  # Text to inject into prompts
    active: bool = True

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ProceduralRule":
        # Handle missing fields with defaults
        # Support both 'created' (old) and 'created_at' (new) field names
        created_at = data.get("created_at") or data.get("created")
        return cls(
            rule_id=data.get("rule_id", "unknown"),
            trigger=data.get("trigger", ""),
            behavior=data.get("behavior", ""),
            rationale=data.get("rationale", ""),
            confidence=data.get("confidence", 0.5),
            source_episodes=data.get("source_episodes", []),
            created_at=created_at,
            last_applied=data.get("last_applied"),
            times_applied=data.get("times_applied", 0),
            injection_point=data.get("injection_point", "PreToolUse"),
            prompt_template=data.get("prompt_template", ""),
            active=data.get("active", True)
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Memory Stores
# ═══════════════════════════════════════════════════════════════════════════════

class SemanticStore:
    """Store for factual knowledge."""

    def __init__(self, path: Path = SEMANTIC_PATH):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._load()

    def _load(self):
        if self.path.exists():
            data = json.loads(self.path.read_text())
            self.facts = {f["fact_id"]: SemanticFact.from_dict(f) for f in data.get("facts", [])}
        else:
            self.facts = {}

    def _save(self):
        data = {"facts": [f.to_dict() for f in self.facts.values()]}
        self.path.write_text(json.dumps(data, indent=2))

    def write(self, content: str, category: str, source: str,
              importance: int = 5, tags: List[str] = None) -> str:
        """Write a new semantic fact."""
        fact_id = f"sem-{uuid.uuid4().hex[:12]}"
        fact = SemanticFact(
            fact_id=fact_id,
            content=content,
            category=category,
            source=source,
            importance=importance,
            tags=tags or []
        )
        self.facts[fact_id] = fact
        self._save()
        return fact_id

    def search(self, query: str, limit: int = 10) -> List[SemanticFact]:
        """Search facts by content match."""
        query_lower = query.lower()
        results = []
        for fact in self.facts.values():
            if query_lower in fact.content.lower() or \
               any(query_lower in tag.lower() for tag in fact.tags):
                results.append(fact)
        return sorted(results, key=lambda f: f.importance, reverse=True)[:limit]

    def update(self, fact_id: str, content: str = None, importance: int = None) -> bool:
        """Update an existing fact."""
        if fact_id not in self.facts:
            return False
        fact = self.facts[fact_id]
        if content:
            fact.content = content
        if importance:
            fact.importance = importance
        fact.updated_at = datetime.now(timezone.utc).isoformat()
        self._save()
        return True

    def delete(self, fact_id: str) -> bool:
        """Delete a fact."""
        if fact_id in self.facts:
            del self.facts[fact_id]
            self._save()
            return True
        return False


class EpisodicStore:
    """Store for experiential memories."""

    def __init__(self, base_dir: Path = EPISODES_DIR):
        self.base_dir = base_dir
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.index_path = base_dir / "index.json"
        self._load_index()

    def _load_index(self):
        if self.index_path.exists():
            raw = json.loads(self.index_path.read_text())
            # Handle migration from flat structure to nested
            if "episodes" not in raw:
                # Old format: {ep_id: data, ...}
                episodes = []
                for ep_id, ep_data in raw.items():
                    if ep_id.startswith("ep-"):
                        episodes.append({"episode_id": ep_id, **ep_data})
                self.index = {"episodes": episodes, "tags": {}, "projects": {}}
                self._save_index()  # Migrate
            else:
                self.index = raw
        else:
            self.index = {"episodes": [], "tags": {}, "projects": {}}

    def _save_index(self):
        self.index_path.write_text(json.dumps(self.index, indent=2))

    def write(self, episode: Episode) -> str:
        """Save a new episode."""
        # Ensure directory exists
        episode_path = episode.get_storage_path()
        episode_path.parent.mkdir(parents=True, exist_ok=True)

        # Save episode
        episode_path.write_text(json.dumps(episode.to_dict(), indent=2))

        # Update index
        entry = {
            "episode_id": episode.episode_id,
            "timestamp": episode.timestamp,
            "task": episode.task[:100],
            "project": episode.project,
            "success": episode.success,
            "importance": episode.importance,
            "tags": episode.tags
        }
        self.index["episodes"].append(entry)

        # Update tag index
        for tag in episode.tags:
            if tag not in self.index["tags"]:
                self.index["tags"][tag] = []
            self.index["tags"][tag].append(episode.episode_id)

        # Update project index
        if episode.project not in self.index["projects"]:
            self.index["projects"][episode.project] = []
        self.index["projects"][episode.project].append(episode.episode_id)

        self._save_index()
        return episode.episode_id

    def get(self, episode_id: str) -> Optional[Episode]:
        """Load an episode by ID."""
        for entry in self.index["episodes"]:
            if entry["episode_id"] == episode_id:
                # Find and load the file
                date_prefix = entry["timestamp"][:7]
                path = self.base_dir / date_prefix / f"{episode_id}.json"
                if path.exists():
                    return Episode.from_dict(json.loads(path.read_text()))
        return None

    def search(self, query: str = None, tags: List[str] = None,
               project: str = None, limit: int = 10) -> List[Dict[str, Any]]:
        """Search episodes by criteria."""
        results = self.index["episodes"]

        if project:
            project_ids = set(self.index["projects"].get(project, []))
            results = [e for e in results if e["episode_id"] in project_ids]

        if tags:
            tag_ids = set()
            for tag in tags:
                tag_ids.update(self.index["tags"].get(tag, []))
            results = [e for e in results if e["episode_id"] in tag_ids]

        if query:
            query_lower = query.lower()
            results = [e for e in results if query_lower in e["task"].lower()]

        return sorted(results, key=lambda e: e["importance"], reverse=True)[:limit]

    def get_recent(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get most recent episodes."""
        return sorted(self.index["episodes"],
                      key=lambda e: e["timestamp"],
                      reverse=True)[:limit]


class ProceduralStore:
    """Store for learned behaviors."""

    def __init__(self, path: Path = PROCEDURAL_PATH):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._load()

    def _load(self):
        if self.path.exists():
            data = json.loads(self.path.read_text())
            self.rules = {r["rule_id"]: ProceduralRule.from_dict(r) for r in data.get("rules", [])}
        else:
            self.rules = {}

    def _save(self):
        data = {"rules": [r.to_dict() for r in self.rules.values()]}
        self.path.write_text(json.dumps(data, indent=2))

    def write(self, trigger: str, behavior: str, rationale: str,
              source_episodes: List[str] = None, confidence: float = 0.8) -> str:
        """Create a new procedural rule."""
        rule_id = f"proc-{uuid.uuid4().hex[:8]}"
        rule = ProceduralRule(
            rule_id=rule_id,
            trigger=trigger,
            behavior=behavior,
            rationale=rationale,
            source_episodes=source_episodes or [],
            confidence=confidence,
            prompt_template=f"Based on past experience: {behavior}"
        )
        self.rules[rule_id] = rule
        self._save()
        return rule_id

    def get_active_rules(self, context: str = None) -> List[ProceduralRule]:
        """Get active rules, optionally filtered by context."""
        active = [r for r in self.rules.values() if r.active and r.confidence >= 0.5]
        if context:
            context_lower = context.lower()
            active = [r for r in active if context_lower in r.trigger.lower()]
        return sorted(active, key=lambda r: r.confidence, reverse=True)

    def apply_rule(self, rule_id: str) -> bool:
        """Mark a rule as applied."""
        if rule_id in self.rules:
            rule = self.rules[rule_id]
            rule.last_applied = datetime.now(timezone.utc).isoformat()
            rule.times_applied += 1
            self._save()
            return True
        return False

    def decay_confidence(self, decay_rate: float = 0.05):
        """Reduce confidence of unused rules."""
        for rule in self.rules.values():
            if rule.times_applied == 0:
                rule.confidence = max(0.1, rule.confidence - decay_rate)
        self._save()

    def get_prompt_injections(self, injection_point: str) -> List[str]:
        """Get prompt text to inject at given point."""
        injections = []
        for rule in self.get_active_rules():
            if rule.injection_point == injection_point and rule.prompt_template:
                injections.append(rule.prompt_template)
        return injections


# ═══════════════════════════════════════════════════════════════════════════════
# Unified Memory Manager
# ═══════════════════════════════════════════════════════════════════════════════

class MemoryManager:
    """Unified interface for all memory operations."""

    def __init__(self):
        self.semantic = SemanticStore()
        self.episodic = EpisodicStore()
        self.procedural = ProceduralStore()
        self.config = CONFIG

    # Hot Path Operations
    def write_semantic(self, content: str, category: str = "general",
                       source: str = "hot_path", importance: int = 5,
                       tags: List[str] = None) -> Dict[str, Any]:
        """Write semantic fact (Hot Path)."""
        fact_id = self.semantic.write(content, category, source, importance, tags)
        return {"success": True, "fact_id": fact_id, "type": "semantic"}

    def write_episode(self, task: str, context: str, project: str,
                      session_id: str, actions: List[Dict] = None,
                      learnings: List[str] = None, success: bool = True,
                      tags: List[str] = None, importance: int = 5) -> Dict[str, Any]:
        """Write episodic memory (typically Cold Path but can be Hot)."""
        episode = Episode(
            episode_id=f"ep-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}",
            timestamp=datetime.now(timezone.utc).isoformat(),
            session_id=session_id,
            project=project,
            task=task,
            context=context,
            actions=actions or [],
            learnings=learnings or [],
            success=success,
            tags=tags or [],
            importance=importance
        )
        episode_id = self.episodic.write(episode)
        return {"success": True, "episode_id": episode_id, "type": "episodic"}

    def write_procedural(self, trigger: str, behavior: str, rationale: str,
                         confidence: float = 0.8) -> Dict[str, Any]:
        """Write procedural rule (typically Cold Path)."""
        rule_id = self.procedural.write(trigger, behavior, rationale, confidence=confidence)
        return {"success": True, "rule_id": rule_id, "type": "procedural"}

    def search(self, query: str, memory_types: List[str] = None,
               limit: int = 10) -> Dict[str, List]:
        """Search across memory types."""
        types = memory_types or ["semantic", "episodic", "procedural"]
        results = {}

        if "semantic" in types:
            results["semantic"] = [f.to_dict() for f in self.semantic.search(query, limit)]

        if "episodic" in types:
            results["episodic"] = self.episodic.search(query=query, limit=limit)

        if "procedural" in types:
            rules = self.procedural.get_active_rules(query)
            results["procedural"] = [r.to_dict() for r in rules[:limit]]

        return results

    def get_context_for_task(self, task: str, project: str = None) -> Dict[str, Any]:
        """Get relevant context for a task from all memory types."""
        context = {
            "semantic_facts": [],
            "similar_episodes": [],
            "applicable_rules": [],
            "prompt_injections": []
        }

        # Search semantic
        facts = self.semantic.search(task, limit=5)
        context["semantic_facts"] = [f.to_dict() for f in facts]

        # Search episodes
        episodes = self.episodic.search(query=task, project=project, limit=5)
        context["similar_episodes"] = episodes

        # Get applicable rules
        rules = self.procedural.get_active_rules(task)
        context["applicable_rules"] = [r.to_dict() for r in rules]

        # Get prompt injections
        context["prompt_injections"] = self.procedural.get_prompt_injections("PreToolUse")

        return context

    def get_stats(self) -> Dict[str, Any]:
        """Get memory statistics."""
        return {
            "semantic_count": len(self.semantic.facts),
            "episodic_count": len(self.episodic.index["episodes"]),
            "procedural_count": len(self.procedural.rules),
            "active_rules": len(self.procedural.get_active_rules()),
            "tags": list(self.episodic.index["tags"].keys()),
            "projects": list(self.episodic.index["projects"].keys())
        }


# ═══════════════════════════════════════════════════════════════════════════════
# CLI Interface
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Ralph Memory Manager v2.49")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Write command
    write_parser = subparsers.add_parser("write", help="Write to memory")
    write_parser.add_argument("type", choices=["semantic", "episodic", "procedural"])
    write_parser.add_argument("--content", "-c", required=True)
    write_parser.add_argument("--category", default="general")
    write_parser.add_argument("--importance", "-i", type=int, default=5)
    write_parser.add_argument("--tags", "-t", nargs="*", default=[])

    # Search command
    search_parser = subparsers.add_parser("search", help="Search memory")
    search_parser.add_argument("query")
    search_parser.add_argument("--types", nargs="*", default=["semantic", "episodic"])
    search_parser.add_argument("--limit", type=int, default=10)

    # Context command
    context_parser = subparsers.add_parser("context", help="Get context for task")
    context_parser.add_argument("task")
    context_parser.add_argument("--project", "-p")

    # Stats command
    subparsers.add_parser("stats", help="Show memory statistics")

    args = parser.parse_args()

    manager = MemoryManager()

    if args.command == "write":
        if args.type == "semantic":
            result = manager.write_semantic(
                args.content, args.category, "cli", args.importance, args.tags
            )
        elif args.type == "episodic":
            result = manager.write_episode(
                task=args.content,
                context="CLI input",
                project=os.path.basename(os.getcwd()),
                session_id="cli",
                tags=args.tags,
                importance=args.importance
            )
        elif args.type == "procedural":
            result = manager.write_procedural(
                trigger=args.content,
                behavior=args.content,
                rationale="CLI created"
            )
        print(json.dumps(result, indent=2))

    elif args.command == "search":
        results = manager.search(args.query, args.types, args.limit)
        print(json.dumps(results, indent=2))

    elif args.command == "context":
        context = manager.get_context_for_task(args.task, args.project)
        print(json.dumps(context, indent=2))

    elif args.command == "stats":
        stats = manager.get_stats()
        print(json.dumps(stats, indent=2))

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
