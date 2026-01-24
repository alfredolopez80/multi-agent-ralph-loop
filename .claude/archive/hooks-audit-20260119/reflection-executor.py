#!/usr/bin/env python3
"""
ReflectionExecutor - Cold Path Memory Processing (v2.49.0)

Background processing of session transcripts to extract:
- Semantic facts (stable knowledge)
- Episodic memories (structured experiences)
- Procedural patterns (behavioral rules)

Runs asynchronously after session ends or on context compaction.

Usage:
    python3 reflection-executor.py extract <transcript_path>
    python3 reflection-executor.py patterns
    python3 reflection-executor.py cleanup
    python3 reflection-executor.py status
"""

import json
import os
import sys
import re
import hashlib
from datetime import datetime, timezone, timedelta
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Any
from collections import Counter

# Paths
RALPH_DIR = Path.home() / ".ralph"
EPISODES_DIR = RALPH_DIR / "episodes"
PROCEDURAL_FILE = RALPH_DIR / "procedural" / "rules.json"
CONFIG_FILE = RALPH_DIR / "config" / "memory-config.json"
REFLECTION_LOG = RALPH_DIR / "logs" / "reflection.log"

# Ensure directories exist
EPISODES_DIR.mkdir(parents=True, exist_ok=True)
(RALPH_DIR / "procedural").mkdir(parents=True, exist_ok=True)
(RALPH_DIR / "logs").mkdir(parents=True, exist_ok=True)


@dataclass
class ExtractedFact:
    """A fact extracted from conversation."""
    content: str
    category: str
    confidence: float
    source: str
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


@dataclass
class ExtractedEpisode:
    """An episode extracted from conversation."""
    episode_id: str
    task: str
    context: str
    reasoning: List[str]
    actions: List[Dict[str, str]]
    outcome: str
    success: bool
    learnings: List[str]
    tags: List[str]
    importance: int
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


@dataclass
class ProceduralRule:
    """A behavioral rule detected from patterns."""
    rule_id: str
    trigger: str
    behavior: str
    rationale: str
    confidence: float
    source_episodes: List[str]
    created: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    last_applied: Optional[str] = None
    apply_count: int = 0


def load_config() -> Dict[str, Any]:
    """Load memory configuration."""
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            return json.load(f)
    return {"cold_path": {"enabled": True, "pattern_detection_threshold": 3}}


def log_reflection(message: str) -> None:
    """Log reflection activity."""
    timestamp = datetime.now(timezone.utc).isoformat()
    with open(REFLECTION_LOG, "a") as f:
        f.write(f"[{timestamp}] {message}\n")


class TranscriptParser:
    """Parse session transcripts for memory extraction."""

    # Patterns for extraction
    DECISION_PATTERNS = [
        r"decided to (.+)",
        r"chose (.+) over",
        r"will use (.+)",
        r"going with (.+)",
        r"selected (.+)",
    ]

    ERROR_PATTERNS = [
        r"error[:\s]+(.+)",
        r"failed[:\s]+(.+)",
        r"bug[:\s]+(.+)",
        r"issue[:\s]+(.+)",
        r"problem[:\s]+(.+)",
    ]

    SUCCESS_PATTERNS = [
        r"successfully (.+)",
        r"completed (.+)",
        r"fixed (.+)",
        r"implemented (.+)",
        r"created (.+)",
    ]

    PREFERENCE_PATTERNS = [
        r"prefer[s]? (.+)",
        r"like[s]? (.+)",
        r"want[s]? (.+)",
        r"always (.+)",
        r"never (.+)",
    ]

    def __init__(self, transcript_path: str):
        self.transcript_path = Path(transcript_path)
        self.content = ""
        if self.transcript_path.exists():
            self.content = self.transcript_path.read_text()

    def extract_decisions(self) -> List[str]:
        """Extract decisions from transcript."""
        decisions = []
        for pattern in self.DECISION_PATTERNS:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            decisions.extend(matches)
        return decisions[:10]  # Limit

    def extract_errors(self) -> List[str]:
        """Extract error occurrences."""
        errors = []
        for pattern in self.ERROR_PATTERNS:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            errors.extend(matches)
        return errors[:10]

    def extract_successes(self) -> List[str]:
        """Extract successful outcomes."""
        successes = []
        for pattern in self.SUCCESS_PATTERNS:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            successes.extend(matches)
        return successes[:10]

    def extract_preferences(self) -> List[str]:
        """Extract user preferences."""
        preferences = []
        for pattern in self.PREFERENCE_PATTERNS:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            preferences.extend(matches)
        return preferences[:10]

    def extract_files_modified(self) -> List[str]:
        """Extract file paths mentioned."""
        # Match common file patterns
        file_patterns = [
            r"(?:created|modified|edited|wrote)\s+(?:to\s+)?[`'\"]?([^\s`'\"]+\.[a-zA-Z]+)",
            r"(?:file|path)[:\s]+[`'\"]?([^\s`'\"]+\.[a-zA-Z]+)",
        ]
        files = []
        for pattern in file_patterns:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            files.extend(matches)
        return list(set(files))[:20]

    def get_task_summary(self) -> str:
        """Extract main task from transcript."""
        # Look for task indicators
        task_patterns = [
            r"task[:\s]+(.+?)(?:\n|$)",
            r"implement[:\s]+(.+?)(?:\n|$)",
            r"create[:\s]+(.+?)(?:\n|$)",
            r"fix[:\s]+(.+?)(?:\n|$)",
        ]
        for pattern in task_patterns:
            match = re.search(pattern, self.content[:2000], re.IGNORECASE)
            if match:
                return match.group(1).strip()[:200]
        # Fallback: first line
        first_line = self.content.split('\n')[0] if self.content else "Unknown task"
        return first_line[:200]

    def estimate_success(self) -> bool:
        """Estimate if the session was successful."""
        success_indicators = len(self.extract_successes())
        error_indicators = len(self.extract_errors())
        # More successes than errors = likely successful
        return success_indicators >= error_indicators

    def extract_tags(self) -> List[str]:
        """Extract relevant tags from content."""
        # Technology keywords
        tech_keywords = [
            "python", "typescript", "javascript", "react", "node",
            "docker", "kubernetes", "aws", "git", "api", "database",
            "test", "security", "auth", "jwt", "oauth", "hooks",
            "memory", "cache", "performance", "async", "websocket"
        ]
        content_lower = self.content.lower()
        tags = [kw for kw in tech_keywords if kw in content_lower]
        return tags[:10]


class ReflectionExecutor:
    """Execute reflection on session transcripts."""

    def __init__(self):
        self.config = load_config()
        self.cold_path_enabled = self.config.get("cold_path", {}).get("enabled", True)
        self.pattern_threshold = self.config.get("cold_path", {}).get("pattern_detection_threshold", 3)

    def generate_episode_id(self) -> str:
        """Generate unique episode ID."""
        timestamp = datetime.now().strftime("%Y-%m-%d")
        suffix = hashlib.md5(str(datetime.now().timestamp()).encode()).hexdigest()[:6]
        return f"ep-{timestamp}-{suffix}"

    def extract_episode(self, transcript_path: str, project: str = "", session_id: str = "") -> ExtractedEpisode:
        """Extract structured episode from transcript."""
        parser = TranscriptParser(transcript_path)

        episode = ExtractedEpisode(
            episode_id=self.generate_episode_id(),
            task=parser.get_task_summary(),
            context=f"Project: {project}" if project else "Unknown project",
            reasoning=parser.extract_decisions(),
            actions=[{"type": "modify", "file": f} for f in parser.extract_files_modified()],
            outcome="Session completed",
            success=parser.estimate_success(),
            learnings=parser.extract_errors() + parser.extract_successes(),
            tags=parser.extract_tags(),
            importance=7 if parser.estimate_success() else 5
        )

        return episode

    def save_episode(self, episode: ExtractedEpisode) -> str:
        """Save episode to disk."""
        # Organize by month
        month_dir = EPISODES_DIR / datetime.now().strftime("%Y-%m")
        month_dir.mkdir(exist_ok=True)

        episode_file = month_dir / f"{episode.episode_id}.json"
        with open(episode_file, "w") as f:
            json.dump(asdict(episode), f, indent=2)

        # Update index
        self._update_episode_index(episode)

        log_reflection(f"Saved episode: {episode.episode_id}")
        return str(episode_file)

    def _update_episode_index(self, episode: ExtractedEpisode) -> None:
        """Update episode index for quick lookup."""
        index_file = EPISODES_DIR / "index.json"

        index = {}
        if index_file.exists():
            with open(index_file) as f:
                index = json.load(f)

        # Add to index
        index[episode.episode_id] = {
            "task": episode.task[:100],
            "tags": episode.tags,
            "success": episode.success,
            "importance": episode.importance,
            "timestamp": episode.timestamp
        }

        # Keep last 1000 entries
        if len(index) > 1000:
            sorted_entries = sorted(index.items(), key=lambda x: x[1].get("timestamp", ""), reverse=True)
            index = dict(sorted_entries[:1000])

        with open(index_file, "w") as f:
            json.dump(index, f, indent=2)

    def detect_patterns(self) -> List[ProceduralRule]:
        """Detect behavioral patterns from recent episodes."""
        index_file = EPISODES_DIR / "index.json"
        if not index_file.exists():
            return []

        with open(index_file) as f:
            raw_index = json.load(f)

        # Handle both old (dict) and new (nested) index formats
        if "episodes" in raw_index:
            episodes = raw_index["episodes"]
        else:
            # Old format: {ep_id: data, ...}
            episodes = [{"episode_id": ep_id, **ep_data}
                        for ep_id, ep_data in raw_index.items()
                        if ep_id.startswith("ep-")]

        # Need at least threshold episodes
        if len(episodes) < self.pattern_threshold:
            log_reflection(f"Not enough episodes for pattern detection ({len(episodes)}/{self.pattern_threshold})")
            return []

        # Analyze tag frequency
        tag_counter = Counter()
        success_tags = Counter()
        failure_tags = Counter()

        for ep_data in episodes:
            tags = ep_data.get("tags", [])
            tag_counter.update(tags)
            if ep_data.get("success"):
                success_tags.update(tags)
            else:
                failure_tags.update(tags)

        # Generate rules from patterns
        rules = []

        # Rule 1: Common success patterns
        for tag, count in success_tags.most_common(3):
            if count >= self.pattern_threshold:
                rule = ProceduralRule(
                    rule_id=f"proc-success-{tag}-{hashlib.md5(tag.encode()).hexdigest()[:4]}",
                    trigger=f"Working on {tag} related task",
                    behavior=f"Apply {tag} best practices from past successful sessions",
                    rationale=f"Pattern detected: {count} successful sessions involving {tag}",
                    confidence=min(0.9, 0.5 + (count * 0.1)),
                    source_episodes=[]
                )
                rules.append(rule)

        # Rule 2: Common failure avoidance
        for tag, count in failure_tags.most_common(2):
            if count >= self.pattern_threshold:
                rule = ProceduralRule(
                    rule_id=f"proc-avoid-{tag}-{hashlib.md5(tag.encode()).hexdigest()[:4]}",
                    trigger=f"Working on {tag} related task",
                    behavior=f"Be extra careful with {tag} - past sessions had issues",
                    rationale=f"Pattern detected: {count} problematic sessions involving {tag}",
                    confidence=min(0.85, 0.4 + (count * 0.1)),
                    source_episodes=[]
                )
                rules.append(rule)

        return rules

    def save_procedural_rules(self, rules: List[ProceduralRule]) -> int:
        """Save or update procedural rules."""
        existing_rules = {}
        if PROCEDURAL_FILE.exists():
            with open(PROCEDURAL_FILE) as f:
                existing_rules = {r["rule_id"]: r for r in json.load(f).get("rules", [])}

        # Merge rules
        for rule in rules:
            rule_dict = asdict(rule)
            if rule.rule_id in existing_rules:
                # Update confidence if higher
                old = existing_rules[rule.rule_id]
                if rule.confidence > old.get("confidence", 0):
                    existing_rules[rule.rule_id] = rule_dict
            else:
                existing_rules[rule.rule_id] = rule_dict

        # Apply confidence decay (weekly)
        config = load_config()
        decay = config.get("procedural", {}).get("confidence_decay_per_week", 0.05)

        for rule_id, rule_data in existing_rules.items():
            created = datetime.fromisoformat(rule_data.get("created", datetime.now(timezone.utc).isoformat()).replace("Z", "+00:00"))
            weeks_old = (datetime.now(timezone.utc) - created).days / 7
            if weeks_old > 0:
                rule_data["confidence"] = max(0.3, rule_data["confidence"] - (decay * weeks_old))

        # Filter by min confidence
        min_conf = config.get("procedural", {}).get("min_confidence", 0.7)
        filtered = {k: v for k, v in existing_rules.items() if v.get("confidence", 0) >= min_conf}

        # Limit to max rules
        max_rules = config.get("procedural", {}).get("max_rules", 50)
        sorted_rules = sorted(filtered.values(), key=lambda x: x.get("confidence", 0), reverse=True)[:max_rules]

        with open(PROCEDURAL_FILE, "w") as f:
            json.dump({"rules": sorted_rules, "updated": datetime.now(timezone.utc).isoformat()}, f, indent=2)

        log_reflection(f"Saved {len(sorted_rules)} procedural rules")
        return len(sorted_rules)

    def cleanup_old_episodes(self) -> int:
        """Remove episodes past TTL."""
        config = load_config()
        ttl_days = config.get("episodic", {}).get("ttl_days", 90)
        min_importance = config.get("episodic", {}).get("min_importance_to_keep", 3)

        cutoff = datetime.now(timezone.utc) - timedelta(days=ttl_days)
        removed = 0

        for month_dir in EPISODES_DIR.glob("20*-*"):
            if not month_dir.is_dir():
                continue
            for ep_file in month_dir.glob("ep-*.json"):
                try:
                    with open(ep_file) as f:
                        ep = json.load(f)
                    ts = datetime.fromisoformat(ep.get("timestamp", "2020-01-01").replace("Z", "+00:00"))
                    importance = ep.get("importance", 5)

                    # Remove if past TTL and not important
                    if ts < cutoff and importance < min_importance:
                        ep_file.unlink()
                        removed += 1
                except Exception:
                    pass

        log_reflection(f"Cleaned up {removed} old episodes")
        return removed

    def get_status(self) -> Dict[str, Any]:
        """Get reflection system status."""
        # Count episodes
        episode_count = 0
        for month_dir in EPISODES_DIR.glob("20*-*"):
            if month_dir.is_dir():
                episode_count += len(list(month_dir.glob("ep-*.json")))

        # Count rules
        rule_count = 0
        if PROCEDURAL_FILE.exists():
            with open(PROCEDURAL_FILE) as f:
                rules = json.load(f).get("rules", [])
                rule_count = len(rules)

        # Recent logs
        recent_logs = []
        if REFLECTION_LOG.exists():
            lines = REFLECTION_LOG.read_text().strip().split("\n")[-10:]
            recent_logs = lines

        return {
            "cold_path_enabled": self.cold_path_enabled,
            "pattern_threshold": self.pattern_threshold,
            "episode_count": episode_count,
            "procedural_rules": rule_count,
            "recent_activity": recent_logs
        }


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]
    executor = ReflectionExecutor()

    if command == "extract":
        if len(sys.argv) < 3:
            print("Usage: reflection-executor.py extract <transcript_path>")
            sys.exit(1)
        transcript_path = sys.argv[2]
        project = os.environ.get("PROJECT", "")
        session_id = os.environ.get("SESSION_ID", "")

        episode = executor.extract_episode(transcript_path, project, session_id)
        saved_path = executor.save_episode(episode)
        print(f"Episode saved: {saved_path}")
        print(f"Task: {episode.task}")
        print(f"Success: {episode.success}")
        print(f"Tags: {', '.join(episode.tags)}")

    elif command == "patterns":
        rules = executor.detect_patterns()
        if rules:
            saved = executor.save_procedural_rules(rules)
            print(f"Detected and saved {saved} procedural rules")
            for rule in rules:
                print(f"  - {rule.rule_id}: {rule.behavior} (confidence: {rule.confidence:.2f})")
        else:
            print("No new patterns detected (need more episodes)")

    elif command == "cleanup":
        removed = executor.cleanup_old_episodes()
        print(f"Removed {removed} old episodes")

    elif command == "status":
        status = executor.get_status()
        print(json.dumps(status, indent=2))

    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
