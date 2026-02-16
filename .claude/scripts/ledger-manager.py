#!/usr/bin/env python3
"""
ledger-manager.py - Core CRUD for Ralph v2.35 Ledger System
Manages CONTINUITY_RALPH-<session>.md files for context preservation

Part of Ralph v2.35 Context Engineering Optimization
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, List, Any

# Configuration
LEDGER_DIR = Path.home() / ".ralph" / "ledgers"
DEFAULT_LEDGER_NAME = "CONTINUITY_RALPH"


class LedgerManager:
    """Manages ledger files for context preservation across sessions."""

    def __init__(self, ledger_dir: Optional[Path] = None):
        self.ledger_dir = ledger_dir or LEDGER_DIR
        self.ledger_dir.mkdir(parents=True, exist_ok=True)

    def _get_ledger_path(self, session_id: str) -> Path:
        """Get the path for a ledger file."""
        safe_session = "".join(c for c in session_id if c.isalnum() or c in "-_")
        return self.ledger_dir / f"{DEFAULT_LEDGER_NAME}-{safe_session}.md"

    def _get_latest_ledger(self) -> Optional[Path]:
        """Get the most recently modified ledger file."""
        ledgers = sorted(
            self.ledger_dir.glob(f"{DEFAULT_LEDGER_NAME}-*.md"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )
        return ledgers[0] if ledgers else None

    def save(
        self,
        session_id: str,
        goal: str = "",
        constraints: List[str] = None,
        completed_work: List[Dict[str, str]] = None,
        pending_work: List[Dict[str, str]] = None,
        decisions: List[str] = None,
        agents_used: List[Dict[str, str]] = None,
        custom_sections: Dict[str, str] = None,
        output_path: Optional[str] = None
    ) -> Path:
        """
        Save a ledger file with the current session state.

        Args:
            session_id: Unique session identifier
            goal: Current task/goal description
            constraints: List of constraints/requirements
            completed_work: List of {file, lines, description} dicts
            pending_work: List of {file, description} dicts
            decisions: List of key decisions made
            agents_used: List of {agent, status, action} dicts
            custom_sections: Additional markdown sections
            output_path: Override output path

        Returns:
            Path to the saved ledger file
        """
        now = datetime.now(timezone.utc)

        # Build ledger content
        lines = [
            f"# {DEFAULT_LEDGER_NAME}: {session_id}",
            f"Generated: {now.isoformat()}",
            f"Last Updated: {now.isoformat()}",
            "",
        ]

        # Goal section
        if goal:
            lines.extend([
                "## CURRENT GOAL",
                goal,
                "",
            ])

        # Constraints section
        if constraints:
            lines.extend(["## CONSTRAINTS"])
            for c in constraints:
                lines.append(f"- {c}")
            lines.append("")

        # Completed work section
        if completed_work:
            lines.extend(["## COMPLETED WORK"])
            for item in completed_work:
                file_ref = item.get("file", "unknown")
                line_ref = item.get("lines", "")
                desc = item.get("description", "")
                if line_ref:
                    lines.append(f"- [x] {file_ref}:{line_ref} - {desc}")
                else:
                    lines.append(f"- [x] {file_ref} - {desc}")
            lines.append("")

        # Pending work section
        if pending_work:
            lines.extend(["## PENDING WORK"])
            for item in pending_work:
                file_ref = item.get("file", "unknown")
                desc = item.get("description", "")
                lines.append(f"- [ ] {file_ref} - {desc}")
            lines.append("")

        # Key decisions section
        if decisions:
            lines.extend(["## KEY DECISIONS"])
            for i, d in enumerate(decisions, 1):
                lines.append(f"{i}. {d}")
            lines.append("")

        # Agents used section
        if agents_used:
            lines.extend([
                "## AGENTS USED",
                "| Agent | Status | Action |",
                "|-------|--------|--------|",
            ])
            for agent in agents_used:
                name = agent.get("agent", "unknown")
                status = agent.get("status", "")
                action = agent.get("action", "")
                lines.append(f"| {name} | {status} | {action} |")
            lines.append("")

        # Custom sections
        if custom_sections:
            for title, content in custom_sections.items():
                lines.extend([
                    f"## {title}",
                    content,
                    "",
                ])

        # Determine output path
        if output_path:
            ledger_path = Path(output_path)
        else:
            ledger_path = self._get_ledger_path(session_id)

        # Ensure parent directory exists
        ledger_path.parent.mkdir(parents=True, exist_ok=True)

        # Write the ledger file
        content = "\n".join(lines)
        ledger_path.write_text(content, encoding="utf-8")

        # Set secure permissions (user-only)
        os.chmod(ledger_path, 0o600)

        return ledger_path

    def load(self, session_id: Optional[str] = None) -> Optional[str]:
        """
        Load a ledger file content.

        Args:
            session_id: Specific session to load, or None for latest

        Returns:
            Ledger content as string, or None if not found
        """
        if session_id:
            ledger_path = self._get_ledger_path(session_id)
        else:
            ledger_path = self._get_latest_ledger()

        if ledger_path and ledger_path.exists():
            return ledger_path.read_text(encoding="utf-8")
        return None

    def list_ledgers(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        List available ledgers with metadata.

        Args:
            limit: Maximum number of ledgers to return

        Returns:
            List of ledger metadata dicts
        """
        ledgers = sorted(
            self.ledger_dir.glob(f"{DEFAULT_LEDGER_NAME}-*.md"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )[:limit]

        result = []
        for ledger in ledgers:
            stat = ledger.stat()
            # Extract session ID from filename
            name = ledger.stem
            session_id = name.replace(f"{DEFAULT_LEDGER_NAME}-", "")

            result.append({
                "session_id": session_id,
                "path": str(ledger),
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
                "created": datetime.fromtimestamp(stat.st_ctime, timezone.utc).isoformat(),
            })

        return result

    def delete(self, session_id: str) -> bool:
        """
        Delete a ledger file.

        Args:
            session_id: Session ID of the ledger to delete

        Returns:
            True if deleted, False if not found
        """
        ledger_path = self._get_ledger_path(session_id)
        if ledger_path.exists():
            ledger_path.unlink()
            return True
        return False

    def update_field(self, session_id: str, field: str, value: Any) -> bool:
        """
        Update a specific field in an existing ledger.

        Args:
            session_id: Session ID of the ledger
            field: Field to update (goal, constraints, etc.)
            value: New value for the field

        Returns:
            True if updated, False if ledger not found
        """
        content = self.load(session_id)
        if not content:
            return False

        # Parse existing content and update
        # For now, just update the Last Updated timestamp
        now = datetime.now(timezone.utc)
        lines = content.split("\n")

        for i, line in enumerate(lines):
            if line.startswith("Last Updated:"):
                lines[i] = f"Last Updated: {now.isoformat()}"
                break

        # Write back
        ledger_path = self._get_ledger_path(session_id)
        ledger_path.write_text("\n".join(lines), encoding="utf-8")
        return True

    def get_context_for_injection(self, max_tokens: int = 500) -> str:
        """
        Get ledger content formatted for context injection.
        Truncates if necessary to stay within token budget.

        Args:
            max_tokens: Approximate max tokens (chars / 4)

        Returns:
            Formatted context string
        """
        content = self.load()
        if not content:
            return ""

        max_chars = max_tokens * 4  # Rough approximation

        if len(content) <= max_chars:
            return content

        # Truncate intelligently - keep header and first sections
        lines = content.split("\n")
        result = []
        char_count = 0

        for line in lines:
            if char_count + len(line) + 1 > max_chars:
                result.append("\n[... truncated for context limits ...]")
                break
            result.append(line)
            char_count += len(line) + 1

        return "\n".join(result)


def main():
    """CLI interface for ledger management."""
    parser = argparse.ArgumentParser(
        description="Ralph v2.35 Ledger Manager - Context preservation across sessions"
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Save command
    save_parser = subparsers.add_parser("save", help="Save a new ledger")
    save_parser.add_argument("--session", "-s", required=True, help="Session ID")
    save_parser.add_argument("--goal", "-g", default="", help="Current goal")
    save_parser.add_argument("--output", "-o", help="Output path override")
    save_parser.add_argument("--json", "-j", help="JSON file with full ledger data")

    # Load command
    load_parser = subparsers.add_parser("load", help="Load a ledger")
    load_parser.add_argument("--session", "-s", help="Session ID (latest if omitted)")

    # List command
    list_parser = subparsers.add_parser("list", help="List available ledgers")
    list_parser.add_argument("--limit", "-n", type=int, default=10, help="Max results")
    list_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Delete a ledger")
    delete_parser.add_argument("--session", "-s", required=True, help="Session ID")

    # Show command (alias for load with formatting)
    show_parser = subparsers.add_parser("show", help="Show current ledger")
    show_parser.add_argument("--session", "-s", help="Session ID (latest if omitted)")

    # Context command (for hook injection)
    context_parser = subparsers.add_parser("context", help="Get context for injection")
    context_parser.add_argument("--max-tokens", type=int, default=500, help="Max tokens")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    manager = LedgerManager()

    if args.command == "save":
        # Load from JSON if provided
        if args.json:
            try:
                with open(args.json, "r") as f:
                    data = json.load(f)
            except json.JSONDecodeError as e:
                print(f"Error: Invalid JSON in {args.json}: {e}", file=sys.stderr)
                sys.exit(1)
            except FileNotFoundError as e:
                print(f"Error: File not found: {args.json}", file=sys.stderr)
                sys.exit(1)
            except Exception as e:
                print(f"Error: Unexpected error reading {args.json}: {e}", file=sys.stderr)
                sys.exit(1)
            path = manager.save(
                session_id=args.session,
                goal=data.get("goal", args.goal),
                constraints=data.get("constraints"),
                completed_work=data.get("completed_work"),
                pending_work=data.get("pending_work"),
                decisions=data.get("decisions"),
                agents_used=data.get("agents_used"),
                custom_sections=data.get("custom_sections"),
                output_path=args.output
            )
        else:
            path = manager.save(
                session_id=args.session,
                goal=args.goal,
                output_path=args.output
            )
        print(f"Ledger saved: {path}")

    elif args.command == "load":
        content = manager.load(args.session)
        if content:
            print(content)
        else:
            print("No ledger found", file=sys.stderr)
            sys.exit(1)

    elif args.command == "show":
        content = manager.load(args.session)
        if content:
            print(content)
        else:
            print("No ledger found", file=sys.stderr)
            sys.exit(1)

    elif args.command == "list":
        ledgers = manager.list_ledgers(args.limit)
        if args.json:
            print(json.dumps(ledgers, indent=2))
        else:
            if not ledgers:
                print("No ledgers found")
            else:
                print(f"{'Session ID':<40} {'Modified':<25} {'Size':>8}")
                print("-" * 75)
                for l in ledgers:
                    print(f"{l['session_id']:<40} {l['modified']:<25} {l['size']:>8}")

    elif args.command == "delete":
        if manager.delete(args.session):
            print(f"Ledger deleted: {args.session}")
        else:
            print(f"Ledger not found: {args.session}", file=sys.stderr)
            sys.exit(1)

    elif args.command == "context":
        content = manager.get_context_for_injection(args.max_tokens)
        if content:
            print(content)
        # No error for empty - graceful degradation


if __name__ == "__main__":
    main()
