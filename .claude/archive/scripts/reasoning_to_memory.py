#!/usr/bin/env python3
"""
GLM-5 Reasoning to Memory Integration
Stores GLM-5 reasoning in agent memory for future reference (project-scoped)
Version: 2.84.0
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime


def get_project_root() -> Path:
    """Get project root from environment or git."""
    if 'CLAUDE_PROJECT_DIR' in os.environ:
        return Path(os.environ['CLAUDE_PROJECT_DIR'])

    # Fallback to git root
    import subprocess
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return Path(result.stdout.strip())
    except Exception:
        pass

    return Path('.')


def store_reasoning(agent_id: str, reasoning: str, task_id: str) -> bool:
    """
    Store GLM-5 reasoning in agent memory.

    Args:
        agent_id: Agent identifier (e.g., 'glm5-coder')
        reasoning: Reasoning content from GLM-5
        task_id: Task identifier

    Returns:
        True if successful, False otherwise
    """
    try:
        project_root = get_project_root()
        memory_dir = project_root / ".ralph" / "agent-memory" / agent_id / "episodic"
        memory_dir.mkdir(parents=True, exist_ok=True)

        entry = {
            "type": "reasoning",
            "task_id": task_id,
            "project": str(project_root),
            "content": reasoning,
            "char_count": len(reasoning),
            "timestamp": datetime.now().isoformat()
        }

        episodes_file = memory_dir / "episodes.jsonl"
        with open(episodes_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

        # Log to memory log
        log_dir = project_root / ".ralph" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / "memory.log"

        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now().isoformat()}] [ReasoningMemory] [{agent_id}] "
                   f"Stored reasoning for task {task_id} ({len(reasoning)} chars)\n")

        return True

    except Exception as e:
        print(f"Error storing reasoning: {e}", file=sys.stderr)
        return False


def get_recent_reasoning(agent_id: str, limit: int = 10) -> list:
    """
    Get recent reasoning entries for an agent.

    Args:
        agent_id: Agent identifier
        limit: Maximum number of entries to return

    Returns:
        List of reasoning entries (newest first)
    """
    try:
        project_root = get_project_root()
        episodes_file = project_root / ".ralph" / "agent-memory" / agent_id / "episodic" / "episodes.jsonl"

        if not episodes_file.exists():
            return []

        entries = []
        with open(episodes_file, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    entry = json.loads(line)
                    if entry.get("type") == "reasoning":
                        entries.append(entry)

        # Return newest first
        entries.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
        return entries[:limit]

    except Exception as e:
        print(f"Error reading reasoning: {e}", file=sys.stderr)
        return []


def main():
    if len(sys.argv) < 4:
        print("Usage: reasoning_to_memory.py <agent_id> <reasoning> <task_id>")
        print("       reasoning_to_memory.py <agent_id> --recent [limit]")
        sys.exit(1)

    agent_id = sys.argv[1]

    if sys.argv[2] == "--recent":
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 10
        entries = get_recent_reasoning(agent_id, limit)
        print(json.dumps(entries, indent=2, ensure_ascii=False))
    else:
        reasoning = sys.argv[2]
        task_id = sys.argv[3]

        if store_reasoning(agent_id, reasoning, task_id):
            print(f"✅ Reasoning stored for {agent_id} (task: {task_id})")
        else:
            print("❌ Failed to store reasoning")
            sys.exit(1)


if __name__ == "__main__":
    main()
