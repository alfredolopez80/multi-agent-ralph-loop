#!/usr/bin/env python3
"""
context-extractor.py - Rich Context Extraction for Ralph v2.44

Extracts context from multiple sources BEFORE compaction to prevent information loss.
Used by pre-compact-handoff.sh to generate rich ledgers.

Sources:
1. Git status - modified files, staged changes, current branch
2. Git log - recent commits for context
3. Transcript analysis - decisions, tools used, progress (if available)
4. Progress file - .claude/progress.md if exists

Output: JSON structured for ledger-manager.py consumption

Part of Ralph v2.44 Context Engineering - GitHub #15021 Workaround
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, List, Any


class ContextExtractor:
    """Extracts rich context from project and session state."""

    def __init__(self, project_dir: Optional[str] = None):
        self.project_dir = Path(project_dir) if project_dir else Path.cwd()
        self.errors: List[str] = []

    def _run_git_command(self, args: List[str]) -> Optional[str]:
        """Run a git command and return output, or None on error."""
        try:
            result = subprocess.run(
                ["git"] + args,
                capture_output=True,
                text=True,
                cwd=self.project_dir,
                timeout=10
            )
            if result.returncode == 0:
                return result.stdout.strip()
            return None
        except (subprocess.TimeoutExpired, FileNotFoundError, Exception) as e:
            self.errors.append(f"Git command failed: {e}")
            return None

    def get_git_info(self) -> Dict[str, Any]:
        """Extract git repository information."""
        git_info = {
            "branch": "",
            "modified_files": [],
            "staged_files": [],
            "untracked_files": [],
            "recent_commits": [],
            "is_git_repo": False
        }

        # Check if git repo
        if not (self.project_dir / ".git").exists():
            git_check = self._run_git_command(["rev-parse", "--is-inside-work-tree"])
            if git_check != "true":
                return git_info

        git_info["is_git_repo"] = True

        # Get current branch
        branch = self._run_git_command(["branch", "--show-current"])
        if branch:
            git_info["branch"] = branch

        # Get modified files (working tree changes)
        status = self._run_git_command(["status", "--porcelain"])
        if status:
            for line in status.split("\n"):
                if not line:
                    continue
                status_code = line[:2]
                file_path = line[3:]

                file_info = {
                    "file": file_path,
                    "status": self._parse_status_code(status_code)
                }

                if status_code[0] in "MADRC":  # Staged
                    git_info["staged_files"].append(file_info)
                if status_code[1] in "MD":  # Modified in working tree
                    git_info["modified_files"].append(file_info)
                if status_code == "??":  # Untracked
                    git_info["untracked_files"].append(file_info)

        # Get recent commits (last 5)
        log = self._run_git_command([
            "log", "--oneline", "-n", "5", "--format=%h %s"
        ])
        if log:
            git_info["recent_commits"] = log.split("\n")

        return git_info

    def _parse_status_code(self, code: str) -> str:
        """Parse git status code to human-readable string."""
        status_map = {
            "M": "modified",
            "A": "added",
            "D": "deleted",
            "R": "renamed",
            "C": "copied",
            "?": "untracked",
            " ": "unchanged"
        }
        idx = code[0] if code[0] in status_map else code[1] if len(code) > 1 else " "
        return status_map.get(idx, "unknown")

    def get_progress_info(self) -> Dict[str, Any]:
        """Extract progress from .claude/progress.md if exists."""
        progress_info = {
            "has_progress_file": False,
            "completed_items": [],
            "pending_items": [],
            "errors_encountered": []
        }

        progress_file = self.project_dir / ".claude" / "progress.md"
        if not progress_file.exists():
            return progress_info

        progress_info["has_progress_file"] = True

        try:
            content = progress_file.read_text(encoding="utf-8")
            current_section = None

            for line in content.split("\n"):
                line = line.strip()

                if line.startswith("## "):
                    current_section = line[3:].lower()
                elif line.startswith("- [x]") and current_section:
                    progress_info["completed_items"].append({
                        "item": line[6:].strip(),
                        "section": current_section
                    })
                elif line.startswith("- [ ]") and current_section:
                    progress_info["pending_items"].append({
                        "item": line[6:].strip(),
                        "section": current_section
                    })
                elif "error" in line.lower() or "failed" in line.lower():
                    progress_info["errors_encountered"].append(line)

        except Exception as e:
            self.errors.append(f"Failed to parse progress.md: {e}")

        return progress_info

    def analyze_transcript(self, transcript_path: Optional[str]) -> Dict[str, Any]:
        """Analyze transcript for decisions and tools used."""
        transcript_info = {
            "has_transcript": False,
            "tools_used": [],
            "decisions": [],
            "file_operations": []
        }

        if not transcript_path:
            return transcript_info

        transcript_file = Path(transcript_path)
        if not transcript_file.exists():
            return transcript_info

        transcript_info["has_transcript"] = True
        tools_seen = set()
        decisions = []
        file_ops = []

        try:
            # Read transcript line by line (JSONL format)
            with open(transcript_file, "r", encoding="utf-8") as f:
                for line in f:
                    try:
                        entry = json.loads(line)

                        # Track tool usage
                        if "tool_use" in entry or entry.get("type") == "tool_use":
                            tool_name = entry.get("name", entry.get("tool", "unknown"))
                            tools_seen.add(tool_name)

                            # Track file operations
                            if tool_name in ["Read", "Write", "Edit"]:
                                file_path = entry.get("input", {}).get("file_path", "")
                                if file_path:
                                    file_ops.append({
                                        "operation": tool_name.lower(),
                                        "file": file_path
                                    })

                        # Look for decision-like statements in assistant messages
                        if entry.get("role") == "assistant":
                            content = entry.get("content", "")
                            if isinstance(content, str):
                                # Simple heuristic for decisions
                                decision_markers = [
                                    "I'll", "I will", "Let's", "We should",
                                    "Decided to", "Choosing", "Using"
                                ]
                                for marker in decision_markers:
                                    if marker in content:
                                        # Extract first sentence with marker
                                        sentences = content.split(".")
                                        for s in sentences[:3]:  # First 3 sentences
                                            if marker in s and len(s) < 200:
                                                decisions.append(s.strip())
                                                break

                    except json.JSONDecodeError:
                        continue

            transcript_info["tools_used"] = list(tools_seen)
            transcript_info["decisions"] = decisions[:10]  # Limit to 10
            transcript_info["file_operations"] = file_ops[-20:]  # Last 20 ops

        except Exception as e:
            self.errors.append(f"Failed to analyze transcript: {e}")

        return transcript_info

    def get_environment_info(self) -> Dict[str, Any]:
        """Get environment information."""
        env_info = {
            "env_type": os.environ.get("RALPH_ENV_TYPE", "unknown"),
            "capabilities": os.environ.get("RALPH_CAPABILITIES", "unknown"),
            "cwd": str(self.project_dir),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        # Try to read from state file
        state_file = Path.home() / ".ralph" / "state" / "current-env"
        if state_file.exists():
            try:
                content = state_file.read_text().strip()
                if ":" in content:
                    parts = content.split(":")
                    env_info["env_type"] = parts[0]
                    env_info["capabilities"] = parts[1]
            except Exception:
                pass

        return env_info

    def extract_full_context(
        self,
        transcript_path: Optional[str] = None,
        goal: str = ""
    ) -> Dict[str, Any]:
        """
        Extract full context from all sources.

        Returns a dict compatible with ledger-manager.py --json input.
        """
        context = {
            "goal": goal or "Session state before compaction (auto-saved)",
            "extraction_timestamp": datetime.now(timezone.utc).isoformat(),
            "errors": [],

            # Git information
            "git": self.get_git_info(),

            # Progress tracking
            "progress": self.get_progress_info(),

            # Transcript analysis
            "transcript": self.analyze_transcript(transcript_path),

            # Environment
            "environment": self.get_environment_info(),

            # Fields for ledger-manager.py compatibility
            "constraints": [],
            "completed_work": [],
            "pending_work": [],
            "decisions": [],
            "agents_used": [],
            "custom_sections": {}
        }

        # Convert to ledger-compatible format
        context = self._convert_to_ledger_format(context)

        # Add any extraction errors
        context["errors"] = self.errors

        return context

    def _convert_to_ledger_format(self, context: Dict) -> Dict:
        """Convert extracted context to ledger-manager.py compatible format."""

        # Completed work from git staged + progress completed
        completed = []
        for f in context["git"]["staged_files"]:
            completed.append({
                "file": f["file"],
                "description": f"Staged ({f['status']})"
            })
        for item in context["progress"]["completed_items"][:10]:
            completed.append({
                "file": item.get("section", "progress"),
                "description": item["item"]
            })
        context["completed_work"] = completed

        # Pending work from git modified + progress pending
        pending = []
        for f in context["git"]["modified_files"]:
            pending.append({
                "file": f["file"],
                "description": f"Modified ({f['status']})"
            })
        for item in context["progress"]["pending_items"][:10]:
            pending.append({
                "file": item.get("section", "progress"),
                "description": item["item"]
            })
        context["pending_work"] = pending

        # Decisions from transcript
        context["decisions"] = context["transcript"]["decisions"][:5]

        # Custom sections for rich context
        custom = {}

        # Git section
        if context["git"]["is_git_repo"]:
            git_lines = [f"Branch: {context['git']['branch']}"]
            if context["git"]["recent_commits"]:
                git_lines.append("\nRecent commits:")
                for c in context["git"]["recent_commits"][:3]:
                    git_lines.append(f"  - {c}")
            custom["Git Status"] = "\n".join(git_lines)

        # Tools used section
        if context["transcript"]["tools_used"]:
            custom["Tools Used"] = ", ".join(sorted(context["transcript"]["tools_used"]))

        # Environment section
        env = context["environment"]
        custom["Environment"] = (
            f"Type: {env['env_type']} | Capabilities: {env['capabilities']}\n"
            f"Project: {env['cwd']}"
        )

        context["custom_sections"] = custom

        return context


def main():
    """CLI interface for context extraction."""
    parser = argparse.ArgumentParser(
        description="Ralph v2.44 Context Extractor - Rich context extraction"
    )

    parser.add_argument(
        "--project", "-p",
        default=".",
        help="Project directory (default: current)"
    )
    parser.add_argument(
        "--transcript", "-t",
        help="Path to transcript JSONL file"
    )
    parser.add_argument(
        "--goal", "-g",
        default="",
        help="Current goal/objective"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output JSON file (default: stdout)"
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output"
    )

    args = parser.parse_args()

    # Extract context
    extractor = ContextExtractor(args.project)
    context = extractor.extract_full_context(
        transcript_path=args.transcript,
        goal=args.goal
    )

    # Output
    if args.pretty:
        output = json.dumps(context, indent=2, ensure_ascii=False)
    else:
        output = json.dumps(context, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"Context saved to: {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
