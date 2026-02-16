#!/usr/bin/env python3
"""
git-guard.py - Protective Guard for Dangerous Git Commands (Standalone CLI)

Blocks dangerous commands like 'rm -rf' while allowing specific safe exceptions.
Only permits: rm -rf .next/ (for Next.js build cleanup)

VERSION: 2.0.1

BUG-012 NOTE: This is a STANDALONE CLI tool (takes command as argument).
The HOOK version is at .claude/hooks/git-safety-guard.py (reads JSON from stdin).
Pattern sets differ intentionally: this tool has .next/ exemption, the hook does not.
See .claude/hooks/git-safety-guard.py for the hook version used by Claude Code.
"""

import os
import re
import sys
from pathlib import Path

# ANSI color codes
RED = '\033[91m'
YELLOW = '\033[93m'
GREEN = '\033[92m'
RESET = '\033[0m'
BOLD = '\033[1m'


class GitGuard:
    """
    Git guard that blocks dangerous commands before execution.

    Protected against:
    - rm -rf with dangerous patterns
    - git commands with dangerous options
    - Chained commands with dangerous operations

    Safe exceptions:
    - rm -rf .next/ (Next.js build cleanup)
    """

    # Patterns that ALWAYS block
    BLOCKED_PATTERNS = [
        # rm -rf variations (except exact .next/ exception)
        r'rm\s+-rf\s+\.',
        r'rm\s+-rf\s+\*',
        r'rm\s+-rf\s+\*\*',
        r'rm\s+-rf\s+node_modules',
        r'rm\s+-rf\s+dist',
        r'rm\s+-rf\s+build',
        r'rm\s+-rf\s+coverage',
        r'rm\s+-rf\.pyc',
        r'rm\s+-rf\s+__pycache__',
        r'rm\s+-rf\s+\.venv',
        r'rm\s+-rf\s+venv',
        r'rm\s+-rf\s+\.git',
        r'rm\s+-rf\s+\.idea',
        r'rm\s+-rf\s+\.vscode',
        r'rm\s+-rf\s+target',
        r'rm\s+-rf\s+cargo',
        r'rm\s+-rf\s+.*\.egg-info',
        r'rm\s+-rf\s+mix\.lock',
        r'rm\s+-rf\s+\_build',
        r'rm\s+-rf\s+deps',
        r'rm\s+-rf\s+priv/static',
        # Other dangerous rm patterns
        r'rm\s+-r[f]?\s+\.',
        r'rm\s+-r[f]?\s+\*',
        r'rm\s+-r[f]?\s+\*\*',
        # git clean dangerous options
        r'git\s+clean\s+-fdx',
        r'git\s+clean\s+-fd',
        r'git\s+clean\s+-f\s+-d\s+-x',
        r'git\s+clean\s+.*-x',
        r'git\s+clean\s+.*force',
        # git reset dangerous options
        r'git\s+reset\s+--hard\s+HEAD',
        r'git\s+reset\s+--hard\s+~',
        r'git\s+reset\s+--hard\s+\^',
        r'git\s+reset\s+--mixed\s+--hard',
        r'git\s+reset\s+--hard\s+--source',
        r'git\s+reset\s+--hard\s+@{u}',
        # Chained commands with rm
        r'&&\s*rm\s+-rf',
        r';\s*rm\s+-rf',
        r'\|\s*rm\s+-rf',
        r'&&\s*rm\s+-r[f]?',
        r';\s*rm\s+-r[f]?',
    ]

    # Exact command that is ALLOWED (case-sensitive)
    ALLOWED_EXACT = "rm -rf .next/"

    # Command prefix that triggers guard
    TRIGGER_PREFIXES = ['rm ', 'rm -rf', 'rm -r', 'git clean', 'git reset']

    def __init__(self, allow_mode: bool = False):
        """
        Initialize the guard.

        Args:
            allow_mode: If True, allow all commands (testing mode)
        """
        self.allow_mode = allow_mode
        self.blocked_count = 0
        self.allowed_count = 0

    def check_command(self, command: str) -> tuple[bool, str]:
        """
        Check if a command is safe to execute.

        Args:
            command: The command string to check

        Returns:
            Tuple of (is_safe, message)
        """
        if self.allow_mode:
            return True, "Allow mode enabled"

        # Normalize command
        normalized = command.strip()

        # Check for trigger prefixes first (fast pre-filter)
        trigger_found = False
        for prefix in self.TRIGGER_PREFIXES:
            if normalized.startswith(prefix):
                trigger_found = True
                break

        if not trigger_found:
            return True, "No dangerous trigger found"

        # Check for ALLOWED EXACT command FIRST
        # This must be an EXACT match (case-sensitive, no extra spaces)
        if normalized == self.ALLOWED_EXACT:
            self.allowed_count += 1
            return True, f"Allowed: {self.ALLOWED_EXACT}"

        # Check for blocked patterns
        for pattern in self.BLOCKED_PATTERNS:
            if re.search(pattern, normalized, re.IGNORECASE):
                self.blocked_count += 1
                return False, f"BLOCKED: Dangerous pattern '{pattern}' detected"

        # If we got here, it starts with a trigger but doesn't match any block pattern
        # This is still suspicious - block it
        self.blocked_count += 1
        return False, f"BLOCKED: Suspicious command pattern detected"

    def guard(self, command: str) -> bool:
        """
        Guard a command, exiting if dangerous.

        Args:
            command: The command to guard

        Returns:
            True if command is safe, exits otherwise
        """
        is_safe, message = self.check_command(command)

        if not is_safe:
            print(f"\n{BOLD}{RED}🚫 DANGEROUS COMMAND BLOCKED {RESET}{BOLD}")
            print(f"{'='*60}")
            print(f"{RED}Command: {command}{RESET}")
            print(f"{RED}Reason: {message}{RESET}")
            print(f"{'='*60}")
            print(f"\n{YELLOW}Safe alternatives:{RESET}")
            print(f"  {GREEN}# Clean Next.js build (ALLOWED):{RESET}")
            print(f"  rm -rf .next/")
            print(f"\n  {GREEN}# Safe cleanup commands:{RESET}")
            print(f"  # Remove specific files instead of directories")
            print(f"  # Use 'git clean -n' to preview what would be deleted")
            print(f"  # Use 'git clean -d -n' for directories preview")
            print(f"\n{BOLD}If you must run this command, run it directly (not through Ralph){RESET}")
            sys.exit(1)

        return True

    def validate_script(self, script_path: Path) -> list[str]:
        """
        Validate all commands in a script file.

        Args:
            script_path: Path to script file

        Returns:
            List of blocked commands (empty if all safe)
        """
        blocked = []

        with open(script_path, 'r') as f:
            content = f.read()

        # Split by newlines and check each non-empty line
        for line in content.split('\n'):
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue

            # Check if line contains a command
            is_safe, _ = self.check_command(stripped)
            if not is_safe:
                blocked.append(stripped)

        return blocked


def main():
    """Main entry point for git-guard."""
    import argparse

    parser = argparse.ArgumentParser(
        description='git-guard: Protect against dangerous git commands',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Examples:
  {GREEN}# Guard a single command{RESET}
  git-guard "rm -rf node_modules"

  {GREEN}# Guard a script file{RESET}
  git-guard --script install.sh

  {GREEN}# Allow mode (for testing){RESET}
  git-guard --allow "rm -rf .next/"

  {YELLOW}# ALLOWED command (only this exact form):{RESET}
  git-guard "rm -rf .next/"

{BOLD}Protected Commands:{RESET}
  • rm -rf (except exact 'rm -rf .next/')
  • git clean -fdx, -fd
  • git reset --hard with destructive arguments
  • Chained commands with rm -rf
        """
    )

    parser.add_argument('command', nargs='?', help='Command to check')
    parser.add_argument('--script', '-s', type=Path,
                        help='Script file to validate')
    parser.add_argument('--allow', '-a', action='store_true',
                        help='Allow mode (no blocking)')
    parser.add_argument('--quiet', '-q', action='store_true',
                        help='Quiet mode')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Verbose output')

    args = parser.parse_args()

    guard = GitGuard(allow_mode=args.allow)

    if args.script:
        # Validate script file
        if not args.script.exists():
            print(f"{RED}Error: Script file not found: {args.script}{RESET}")
            sys.exit(1)

        blocked = guard.validate_script(args.script)

        if blocked:
            print(f"\n{BOLD}{RED}🚫 BLOCKED {len(blocked)} dangerous commands in script{RESET}")
            print(f"{'='*60}")
            for cmd in blocked:
                print(f"  {RED}{cmd}{RESET}")
            print(f"{'='*60}")
            sys.exit(1)
        else:
            if not args.quiet:
                print(f"{GREEN}✅ Script validation passed{RESET}")
            sys.exit(0)

    if args.command:
        # Guard single command
        guard.guard(args.command)
        if not args.quiet and args.verbose:
            print(f"{GREEN}✅ Command passed safety check{RESET}")
        sys.exit(0)

    # No command or script provided - show help
    parser.print_help()
    sys.exit(0)


if __name__ == '__main__':
    main()
