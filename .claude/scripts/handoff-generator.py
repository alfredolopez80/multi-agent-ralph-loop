#!/usr/bin/env python3
"""
Handoff Generator - Context transfer between sessions.

Creates handoff documents for session continuity across compactions and transfers.
Used by PreCompact hook and manual handoff commands.

Version: 2.84.2
"""

import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


class HandoffGenerator:
    """Generates handoff documents for session continuity."""

    def __init__(self, handoff_dir: Path):
        """Initialize with handoff directory."""
        self.handoff_dir = Path(handoff_dir)
        self.handoff_dir.mkdir(parents=True, exist_ok=True)

    def create(
        self,
        session_id: str,
        trigger: str = "manual",
        recent_changes: Optional[list] = None,
        context_summary: Optional[list] = None,
        pending_tasks: Optional[list] = None,
        next_steps: Optional[list] = None,
        important_files: Optional[list] = None,
        agents_used: Optional[list] = None,
        notes: Optional[str] = None,
        output: Optional[str] = None
    ) -> Path:
        """Create a handoff document."""
        # Create session-specific subdirectory
        safe_id = self._sanitize_session_id(session_id)
        session_dir = self.handoff_dir / safe_id
        session_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")

        # Use output path if provided, otherwise generate default filename
        if output:
            path = Path(output)
            # Ensure parent directory exists
            path.parent.mkdir(parents=True, exist_ok=True)
        else:
            filename = f"handoff-{safe_id}-{timestamp}.md"
            path = session_dir / filename

        # Build handoff content
        content = self._build_handoff_content(
            session_id=session_id,
            trigger=trigger,
            recent_changes=recent_changes or [],
            context_summary=context_summary or [],
            pending_tasks=pending_tasks or [],
            next_steps=next_steps or [],
            important_files=important_files or [],
            agents_used=agents_used or [],
            notes=notes
        )

        # Write with secure permissions
        path.write_text(content)
        os.chmod(path, 0o600)

        return path

    def load(self, session_id: str) -> Optional[str]:
        """Load the latest handoff for a session."""
        safe_id = self._sanitize_session_id(session_id)
        session_dir = self.handoff_dir / safe_id

        if not session_dir.exists():
            # Fallback to old pattern (flat directory)
            pattern = f"handoff-{safe_id}-*.md"
            matches = sorted(self.handoff_dir.glob(pattern), reverse=True)
            if matches:
                return matches[0].read_text()
            return None

        matches = sorted(session_dir.glob("handoff-*.md"), reverse=True)
        if matches:
            return matches[0].read_text()
        return None

    def load_latest(self) -> Optional[str]:
        """Load the most recent handoff across all sessions."""
        all_matches = []

        # Check session subdirectories
        for session_dir in self.handoff_dir.iterdir():
            if session_dir.is_dir():
                matches = list(session_dir.glob("handoff-*.md"))
                all_matches.extend(matches)

        # Also check flat directory for legacy handoffs
        all_matches.extend(self.handoff_dir.glob("handoff-*.md"))

        if all_matches:
            latest = sorted(all_matches, key=lambda p: p.stat().st_mtime, reverse=True)[0]
            return latest.read_text()
        return None

    def list(self, limit: int = 10) -> list:
        """List recent handoffs (returns Path objects for backward compatibility)."""
        all_matches = []

        # Check session subdirectories
        for session_dir in self.handoff_dir.iterdir():
            if session_dir.is_dir():
                matches = list(session_dir.glob("handoff-*.md"))
                all_matches.extend(matches)

        # Also check flat directory for legacy handoffs
        all_matches.extend(self.handoff_dir.glob("handoff-*.md"))

        return sorted(all_matches, key=lambda p: p.stat().st_mtime, reverse=True)[:limit]

    def list_handoffs(self, limit: int = 10) -> list:
        """List recent handoffs with metadata."""
        all_matches = []

        # Check session subdirectories
        for session_dir in self.handoff_dir.iterdir():
            if session_dir.is_dir():
                matches = list(session_dir.glob("handoff-*.md"))
                all_matches.extend(matches)

        # Also check flat directory for legacy handoffs
        all_matches.extend(self.handoff_dir.glob("handoff-*.md"))

        # Sort by modification time
        sorted_matches = sorted(all_matches, key=lambda p: p.stat().st_mtime, reverse=True)

        # Build metadata list
        result = []
        for path in sorted_matches[:limit]:
            stat = path.stat()
            result.append({
                "path": path,
                "name": path.name,
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat()
            })

        return result

    def search(self, query: str) -> list:
        """Search handoffs for content."""
        query_lower = query.lower()
        results = []

        # Check session subdirectories
        for session_dir in self.handoff_dir.iterdir():
            if session_dir.is_dir():
                for path in session_dir.glob("handoff-*.md"):
                    content = path.read_text()
                    if query_lower in content.lower():
                        # Find snippet with context around the match
                        snippet = self._extract_snippet(content, query)
                        results.append({
                            "path": path,
                            "snippet": snippet
                        })

        # Also check flat directory for legacy handoffs
        for path in self.handoff_dir.glob("handoff-*.md"):
            content = path.read_text()
            if query_lower in content.lower():
                snippet = self._extract_snippet(content, query)
                results.append({
                    "path": path,
                    "snippet": snippet
                })

        return sorted(results, key=lambda r: r["path"].stat().st_mtime, reverse=True)

    def _extract_snippet(self, content: str, query: str, context_chars: int = 50) -> str:
        """Extract a snippet around the query match."""
        lower_content = content.lower()
        query_lower = query.lower()
        pos = lower_content.find(query_lower)

        if pos == -1:
            return ""

        start = max(0, pos - context_chars)
        end = min(len(content), pos + len(query) + context_chars)

        snippet = content[start:end]
        if start > 0:
            snippet = "..." + snippet
        if end < len(content):
            snippet = snippet + "..."

        return snippet

    def cleanup(self, max_age_days: int = 30) -> int:
        """Remove handoffs older than max_age_days."""
        cutoff = time.time() - (max_age_days * 86400)
        removed = 0

        # Check session subdirectories
        for session_dir in self.handoff_dir.iterdir():
            if session_dir.is_dir():
                for path in session_dir.glob("handoff-*.md"):
                    if path.stat().st_mtime < cutoff:
                        path.unlink()
                        removed += 1

        # Also check flat directory for legacy handoffs
        for path in self.handoff_dir.glob("handoff-*.md"):
            if path.stat().st_mtime < cutoff:
                path.unlink()
                removed += 1

        return removed

    def cleanup_old(self, days: int = 30, keep_min: int = 3) -> int:
        """Remove handoffs older than specified days, but keep minimum count."""
        cutoff = time.time() - (days * 86400)
        removed = 0

        # Collect all handoffs
        all_handoffs = []

        # Check session subdirectories
        for session_dir in self.handoff_dir.iterdir():
            if session_dir.is_dir():
                for path in session_dir.glob("handoff-*.md"):
                    all_handoffs.append(path)

        # Also check flat directory for legacy handoffs
        for path in self.handoff_dir.glob("handoff-*.md"):
            all_handoffs.append(path)

        # Sort by modification time (newest first)
        sorted_handoffs = sorted(all_handoffs, key=lambda p: p.stat().st_mtime, reverse=True)

        # Keep at least keep_min handoffs
        if len(sorted_handoffs) <= keep_min:
            return 0

        # Check handoffs beyond keep_min for age-based removal
        for path in sorted_handoffs[keep_min:]:
            if path.stat().st_mtime < cutoff:
                path.unlink()
                removed += 1

        return removed

    def get_context_for_injection(self, max_tokens: int = 2000) -> str:
        """Get handoff context formatted for injection."""
        latest = self.load_latest()
        if not latest:
            return "No previous handoff found."

        # Truncate if needed (approximate token to char ratio)
        max_chars = max_tokens * 4
        if len(latest) > max_chars:
            return latest[:max_chars] + "\n\n[... truncated for context limits]"

        return latest

    def _sanitize_session_id(self, session_id: str) -> str:
        """Sanitize session ID for filesystem safety."""
        # Remove path traversal and dangerous characters
        safe = re.sub(r'[^a-zA-Z0-9_-]', '', session_id)
        # Limit length
        return safe[:64]

    def _build_handoff_content(
        self,
        session_id: str,
        trigger: str,
        recent_changes: list,
        context_summary: list,
        pending_tasks: list,
        next_steps: list,
        important_files: list,
        agents_used: list,
        notes: Optional[str]
    ) -> str:
        """Build handoff document content."""
        timestamp = datetime.now(timezone.utc).isoformat()

        lines = [
            "# RALPH HANDOFF",
            f"Session: {session_id}",
            f"Timestamp: {timestamp}",
            f"Trigger: {trigger}",
            "",
        ]

        if recent_changes:
            lines.append("## RECENT CHANGES")
            for change in recent_changes:
                file_path = change.get("file", "unknown")
                change_type = change.get("type", "MODIFIED")
                lines.append(f"- {change_type}: {file_path}")
            lines.append("")

        if context_summary:
            lines.append("## CONTEXT SUMMARY")
            for item in context_summary:
                lines.append(f"- {item}")
            lines.append("")

        if pending_tasks:
            lines.append("## PENDING TASKS")
            for task in pending_tasks:
                lines.append(f"- {task}")
            lines.append("")

        if next_steps:
            lines.append("## NEXT STEPS")
            for step in next_steps:
                lines.append(f"- {step}")
            lines.append("")

        if important_files:
            lines.append("## IMPORTANT FILES")
            for f in important_files:
                lines.append(f"- {f}")
            lines.append("")

        if agents_used:
            lines.append("## AGENTS USED")
            for agent in agents_used:
                name = agent.get("agent", "unknown")
                status = agent.get("status", "?")
                action = agent.get("action", "")
                lines.append(f"- {name}: {status} {action}")
            lines.append("")

        if notes:
            lines.append("## NOTES")
            lines.append(notes)
            lines.append("")

        # Add restore command
        lines.append("## RESTORE COMMAND")
        lines.append(f"```bash")
        lines.append(f"# To restore this context in a new session:")
        lines.append(f"ralph handoff load --session {session_id}")
        lines.append(f"```")
        lines.append("")

        lines.append("---")
        lines.append("Generated by HandoffGenerator v2.84.2")

        return "\n".join(lines)


def main():
    """CLI interface for handoff generator."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Context transfer between sessions - generate handoff documents"
    )
    parser.add_argument("command", choices=["create", "load", "list", "cleanup"])
    parser.add_argument("--session", "--session-id", dest="session", help="Session ID")
    parser.add_argument("--trigger", default="manual", help="Handoff trigger")
    parser.add_argument("--handoff-dir", help="Handoff directory")
    parser.add_argument("--output", "-o", help="Output file path")

    args = parser.parse_args()

    handoff_dir = Path(args.handoff_dir) if args.handoff_dir else Path.home() / ".ralph" / "handoffs"
    generator = HandoffGenerator(handoff_dir)

    if args.command == "create":
        path = generator.create(
            session_id=args.session or "unknown",
            trigger=args.trigger,
            output=args.output
        )
        print(f"Created: {path}")
    elif args.command == "load":
        content = generator.load_latest()
        print(content or "No handoff found")
    elif args.command == "list":
        for item in generator.list_handoffs():
            print(item["name"])
    elif args.command == "cleanup":
        removed = generator.cleanup()
        print(f"Removed {removed} old handoffs")


if __name__ == "__main__":
    main()
