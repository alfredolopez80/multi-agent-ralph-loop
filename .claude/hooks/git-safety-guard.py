#!/usr/bin/env python3
# VERSION: 2.69.0
# Trigger: PreToolUse (Bash)
# v2.69.0: CRIT-002 FIX - Always output JSON for PreToolUse compliance
# v2.66.8: HIGH-003 version sync (fail-closed error handling already implemented)
"""
git-safety-guard.py - Blocks destructive git and filesystem commands

This hook intercepts Bash commands before execution and blocks potentially
destructive operations that could cause data loss.

Based on: https://github.com/Dicklesworthstone/misc_coding_agent_tips_and_scripts

BLOCKED COMMANDS:
  - git checkout -- <files>     (discards uncommitted changes)
  - git restore <files>         (overwrites working tree)
  - git reset --hard            (destroys uncommitted changes)
  - git reset --merge           (can lose uncommitted changes)
  - git clean -f                (removes untracked files permanently)
  - git push --force / -f       (destroys remote history)
  - git push origin +branch     (force push variant)
  - git branch -D               (force-deletes without merge check)
  - git stash drop              (permanently deletes stash)
  - git stash clear             (deletes ALL stashes)
  - rm -rf (non-temp dirs)      (recursive deletion)

ALLOWED SAFE PATTERNS:
  - git checkout -b <branch>    (creates new branch)
  - git checkout --orphan       (creates orphan branch)
  - git restore --staged        (unstages only)
  - git clean -n / --dry-run    (preview mode)
  - rm -rf /tmp/... or $TMPDIR  (ephemeral directories)

EXIT CODES:
  0 = Allow command (silent)
  Non-zero with JSON = Block command

INSTALLATION:
  User level:  ~/.claude/hooks/git-safety-guard.py
  Project:     .claude/hooks/git-safety-guard.py

  Add to settings.json:
  {
    "hooks": {
      "PreToolUse": [{
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/git-safety-guard.py"
        }]
      }]
    }
  }
"""

import json
import os
import re
import sys


def normalize_command(command: str) -> str:
    """
    Normalize command for consistent pattern matching.
    Prevents regex bypass via whitespace, quotes, and path variations.
    """
    # Expand environment variables in paths
    command = os.path.expandvars(command)

    # Normalize multiple spaces to single space
    command = re.sub(r"\s+", " ", command.strip())

    # Remove common quote variations around paths
    # e.g., rm -rf "/tmp/foo" -> rm -rf /tmp/foo for pattern matching
    command = re.sub(r'["\']([^"\']+)["\']', r"\1", command)

    return command


def log_security_event(event_type: str, command: str, reason: str = ""):
    """Log security events to file (NOT stderr - causes Claude Code hook errors)."""
    import datetime
    import os

    # v2.69.0: Write to file instead of stderr to avoid Claude Code hook error warnings
    log_file = os.path.expanduser("~/.ralph/logs/git-safety-guard.log")
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    timestamp = datetime.datetime.now().isoformat()
    log_msg = f"[{timestamp}] git-safety-guard: {event_type}"
    if reason:
        log_msg += f" - {reason}"
    log_msg += f" | cmd: {command[:100]}"

    try:
        with open(log_file, "a") as f:
            f.write(log_msg + "\n")
    except Exception:
        pass  # Silently fail logging - don't break hook execution


# Patterns that are ALWAYS safe (checked first)
SAFE_PATTERNS = [
    # Git branching (safe)
    r"git\s+checkout\s+(-b|--orphan)\s+",
    r"git\s+switch\s+(-c|--create)\s+",
    # Git restore staged only (doesn't discard working tree)
    r"git\s+restore\s+--staged\s+",
    # Git clean dry-run (preview only)
    r"git\s+clean\s+.*(-n|--dry-run)",
    # rm in temp directories (ephemeral)
    r"rm\s+(-rf|-fr|--recursive)\s+(/tmp/|/var/tmp/|\$TMPDIR/|/private/tmp/)",
    r"rm\s+(-rf|-fr|--recursive)\s+['\"]?/tmp/",
    r"rm\s+(-rf|-fr|--recursive)\s+['\"]?/var/tmp/",
    # Git status/log/diff (read-only)
    r"git\s+(status|log|diff|show|branch|remote|fetch)\b",
    # Git add/commit (safe write operations)
    r"git\s+(add|commit|pull|stash\s+push|stash\s+save)\b",
]

# Patterns that REQUIRE USER CONFIRMATION (risky but allowed with consent)
CONFIRMATION_PATTERNS = [
    # Force push - risky but sometimes needed
    (
        r"git\s+push\s+.*--force",
        "Force push will overwrite remote history. This can cause issues for collaborators.",
    ),
    (
        r"git\s+push\s+.*-f\b",
        "Force push will overwrite remote history. This can cause issues for collaborators.",
    ),
    (
        r"git\s+push\s+\S+\s+\+",
        "Force push via + prefix will overwrite remote history.",
    ),
]

# Patterns that are BLOCKED (destructive - no confirmation option)
BLOCKED_PATTERNS = [
    # Discard uncommitted changes
    (r"git\s+checkout\s+--\s+", "discards uncommitted changes permanently"),
    # Restore without --staged overwrites working tree
    (
        r"git\s+restore\s+(?!--staged).*\S+",
        "overwrites working tree changes without stash",
    ),
    # Hard reset destroys changes
    (r"git\s+reset\s+--hard", "destroys all uncommitted changes permanently"),
    # Merge reset can lose changes
    (r"git\s+reset\s+--merge", "can lose uncommitted changes during merge resolution"),
    # Clean force removes untracked files
    (
        r"git\s+clean\s+.*-f(?!.*(-n|--dry-run))",
        "removes untracked files permanently (use -n first to preview)",
    ),
    # Force delete branch without merge check
    (r"git\s+branch\s+-D\s+", "force-deletes branch without checking if merged"),
    # Stash drop/clear permanently deletes
    (r"git\s+stash\s+drop", "permanently deletes stashed changes"),
    (r"git\s+stash\s+clear", "permanently deletes ALL stashed changes"),
    # VULN-003 FIX: Improved rm -rf protection patterns
    # Block ALL recursive deletes except explicitly allowed temp dirs
    (
        r"rm\s+(-rf|-fr|--recursive)\s+(?!(/tmp/|/var/tmp/|\$TMPDIR/|/private/tmp/))\S",
        "recursive deletion not in safe temp directory",
    ),
    # Block deletion of current directory (extremely dangerous)
    (
        r"rm\s+(-rf|-fr|--recursive)\s+\.\s*$",
        "deletion of current directory is destructive",
    ),
    (
        r"rm\s+(-rf|-fr|--recursive)\s+\.$",
        "deletion of current directory is destructive",
    ),
    # Block relative path deletion with ../
    (
        r"rm\s+(-rf|-fr|--recursive)\s+\.\./",
        "relative path deletion with ../ is unsafe",
    ),
    # Rebase on shared branches (ISSUE-011: removed extra \s+ before branch name)
    (
        r"git\s+rebase\s+.*(main|master|develop)\b",
        "rebasing shared branches can cause issues for collaborators",
    ),
]


def is_safe_pattern(command: str) -> bool:
    """Check if command matches a known safe pattern."""
    for pattern in SAFE_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return True
    return False


def check_confirmation_pattern(command: str) -> tuple[bool, str]:
    """Check if command requires user confirmation. Returns (needs_confirm, reason)."""
    for pattern, reason in CONFIRMATION_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return True, reason
    return False, ""


def check_blocked_pattern(command: str) -> tuple[bool, str]:
    """Check if command matches a blocked pattern. Returns (blocked, reason)."""
    for pattern, reason in BLOCKED_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return True, reason
    return False, ""


def split_chained_commands(command: str) -> list[str]:
    """Split a command string by shell chaining operators (&&, ||, ;, |).

    SEC-1.6: Detects command chaining to prevent bypass of safety checks
    via patterns like 'echo safe && rm -rf /' or 'ls ; git reset --hard'.
    """
    # Split by &&, ||, ;, | (but not ||= or &&= which are not shell operators)
    # Use regex to split on these operators while preserving quoted strings
    # Simple approach: split on operators outside of quotes
    parts = re.split(r'\s*(?:&&|\|\||[;|])\s*', command)
    return [p.strip() for p in parts if p.strip()]


def allow_and_exit():
    """CRIT-002 FIX: Always output JSON for PreToolUse compliance."""
    print('{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}')
    sys.exit(0)


def main():
    original_command = ""
    try:
        # Read hook input from stdin
        input_data = sys.stdin.read()
        if not input_data.strip():
            allow_and_exit()  # No input, allow

        hook_input = json.loads(input_data)

        # Only process Bash tool calls
        tool_name = hook_input.get("tool_name", "")
        if tool_name != "Bash":
            allow_and_exit()  # Not Bash, allow

        # Extract the command
        tool_input = hook_input.get("tool_input", {})
        original_command = tool_input.get("command", "")

        if not original_command:
            allow_and_exit()  # No command, allow

        # SECURITY: Normalize command to prevent regex bypass
        command = normalize_command(original_command)

        # BUG-007 FIX: Detect command substitution patterns ($(...) and backticks)
        # These can hide destructive commands inside seemingly safe ones
        if re.search(r'\$\(.*(?:rm\s|git\s+reset|git\s+clean|git\s+checkout\s+--)', command) or \
           re.search(r'`.*(?:rm\s|git\s+reset|git\s+clean|git\s+checkout\s+--)', command):
            log_security_event("BLOCKED", original_command, "Command substitution with destructive command detected")
            response = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "block",
                    "permissionDecisionReason": f"BLOCKED by git-safety-guard: Command substitution detected with destructive command. "
                    f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                    f"Remove the $() or backtick wrapper and run the inner command separately.",
                }
            }
            print(json.dumps(response))
            sys.exit(1)

        # SEC-1.6: Split by chaining operators and check EACH subcommand
        subcommands = split_chained_commands(command)

        # If there are multiple subcommands, check each one individually
        # A chained command is only safe if ALL subcommands are safe
        for subcmd in subcommands:
            subcmd_normalized = normalize_command(subcmd)

            # Check safe patterns first (skip to next subcommand if safe)
            if is_safe_pattern(subcmd_normalized):
                continue

            # Check if user already confirmed (via env var)
            if os.environ.get("GIT_FORCE_PUSH_CONFIRMED") == "1":
                log_security_event(
                    "ALLOWED_CONFIRMED", original_command, "User confirmed force push"
                )
                continue

            # Check confirmation patterns (require user consent)
            needs_confirm, confirm_reason = check_confirmation_pattern(subcmd_normalized)

            if needs_confirm:
                log_security_event("NEEDS_CONFIRMATION", original_command, f"Chained command contains: {confirm_reason}")
                response = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "block",
                        "permissionDecisionReason": f"BLOCKED by git-safety-guard: Command chaining detected. "
                        f"Dangerous subcommand found: {subcmd_normalized[:80]}. "
                        f"Reason: {confirm_reason}. "
                        f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                        f"Split into separate commands for safety.",
                    }
                }
                print(json.dumps(response))
                sys.exit(1)

            # Check blocked patterns (never allow)
            blocked, reason = check_blocked_pattern(subcmd_normalized)

            if blocked:
                log_security_event("BLOCKED", original_command, f"Chained command contains: {reason}")
                response = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "block",
                        "permissionDecisionReason": f"BLOCKED by git-safety-guard: Command chaining detected. "
                        f"Dangerous subcommand found: {subcmd_normalized[:80]}. "
                        f"Reason: {reason}. "
                        f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                        f"If truly needed, ask the user to run it manually.",
                    }
                }
                print(json.dumps(response))
                sys.exit(1)

        # All subcommands passed - allow (CRIT-002: output JSON for compliance)
        allow_and_exit()

    except json.JSONDecodeError as e:
        # SECURITY: Fail-closed on invalid JSON (could be injection attempt)
        log_security_event(
            "BLOCKED", original_command or "<unknown>", f"Invalid JSON input: {e}"
        )
        response = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "block",
                "permissionDecisionReason": "git-safety-guard: Invalid input format. Command blocked for safety.",
            }
        }
        print(json.dumps(response))
        sys.exit(1)
    except Exception as e:
        # SECURITY: Fail-closed on unexpected errors (safer default)
        log_security_event(
            "BLOCKED", original_command or "<unknown>", f"Unexpected error: {e}"
        )
        response = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "block",
                "permissionDecisionReason": f"git-safety-guard: Internal error, command blocked for safety. Error: {e}",
            }
        }
        print(json.dumps(response))
        sys.exit(1)


if __name__ == "__main__":
    main()
