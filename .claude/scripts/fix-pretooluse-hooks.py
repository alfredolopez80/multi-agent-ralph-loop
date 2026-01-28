#!/usr/bin/env python3
"""
fix-pretooluse-hooks.py

Auto-fix PreToolUse hooks to include hookEventName in JSON output
Required for Claude Code v2.70.0+ hook format validation

Version: 1.0.0
Updated: 2026-01-28
"""

import os
import re
import sys
import json
import shutil
from pathlib import Path
from datetime import datetime

VERSION = "1.0.0"

# ANSI colors
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
RED = "\033[0;31m"
NC = "\033[0m"

# Patterns to fix
PATTERNS = [
    # Pattern 1: {"hookSpecificOutput": {"permissionDecision": "allow"}}
    (
        r'echo\s+[\'"]\{"hookSpecificOutput": \{"permissionDecision": "allow"\}\}[\'"]',
        r'echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\''
    ),
    # Pattern 2: trap with echo
    (
        r'trap\s+-\s+EXIT;\s+echo\s+[\'"]\{"hookSpecificOutput": \{"permissionDecision": "allow"\}\}[\'"]',
        r'trap - EXIT; echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\''
    ),
]


def log_info(msg: str):
    print(f"{BLUE}[INFO]{NC} {msg}")


def log_success(msg: str):
    print(f"{GREEN}[✓]{NC} {msg}")


def log_warning(msg: str):
    print(f"{YELLOW}[!]{NC} {msg}")


def log_error(msg: str):
    print(f"{RED}[✗]{NC} {msg}")


def check_hook_file(filepath: Path) -> tuple[int, int]:
    """Check if hook file has issues. Returns (bad_count, good_count)."""
    try:
        lines = filepath.read_text().splitlines()
    except Exception:
        return 0, 0

    # Filter out comment lines (lines starting with #)
    code_lines = [line for line in lines if not line.strip().startswith("#")]
    code_content = "\n".join(code_lines)

    # Only check PreToolUse hooks (those with permissionDecision)
    if "permissionDecision" not in code_content:
        return 0, 0

    # Count outputs with permissionDecision
    total_outputs = code_content.count("permissionDecision")

    # Count outputs that already have hookEventName
    good_count = code_content.count('"hookEventName": "PreToolUse"')

    # Bad = total - good
    bad_count = max(0, total_outputs - good_count)

    return bad_count, good_count


def fix_hook_file(filepath: Path, dry_run: bool = False) -> int:
    """Fix hook file. Returns number of fixes applied."""
    try:
        content = filepath.read_text()
    except Exception:
        return 0

    original_content = content
    fixes_count = 0

    # Apply patterns
    for pattern, replacement in PATTERNS:
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            fixes_count += matches

    if fixes_count > 0 and not dry_run:
        # Backup
        backup_path = filepath.parent / f"{filepath.name}.backup.{int(datetime.now().timestamp())}"
        shutil.copy2(filepath, backup_path)

        # Write fixed content
        filepath.write_text(content)

    return fixes_count


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Auto-fix PreToolUse hooks to include hookEventName"
    )
    parser.add_argument("--check", action="store_true", help="Check only, don't fix")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be changed")
    parser.add_argument("--version", action="version", version=f"fix-pretooluse-hooks.py v{VERSION}")

    args = parser.parse_args()

    log_info(f"PreToolUse Hook Fixer v{VERSION}")
    print()

    # Find hook directories
    hook_dirs = [
        Path.home() / ".claude" / "hooks",
        Path(".claude") / "hooks"
    ]

    hook_files = []
    for hook_dir in hook_dirs:
        if hook_dir.is_dir():
            hook_files.extend(hook_dir.glob("*.sh"))

    if not hook_files:
        log_warning("No hook files found")
        return 0

    log_info(f"Found {len(hook_files)} hook file(s)")
    print()

    total_issues = 0
    total_fixed = 0

    for hook_file in hook_files:
        bad_count, good_count = check_hook_file(hook_file)

        if bad_count > 0:
            log_warning(f"{hook_file.name}: {bad_count} output(s) need fixing")
            total_issues += bad_count

            if not args.check:
                fixes_count = fix_hook_file(hook_file, dry_run=args.dry_run)
                total_fixed += fixes_count

                if args.dry_run:
                    log_info(f"  [DRY-RUN] Would fix {fixes_count} output(s)")
                elif fixes_count > 0:
                    log_success(f"  Fixed {fixes_count} output(s)")

        elif good_count > 0:
            log_success(f"{hook_file.name}: Already correct ({good_count} outputs)")

    print()
    log_info("Summary:")
    print(f"  Total issues found: {total_issues}")
    print(f"  Total fixed: {total_fixed}")

    if args.check:
        print("  Mode: Check only (no changes made)")
    elif args.dry_run:
        print("  Mode: Dry run (no changes made)")
    elif total_fixed > 0:
        print("  Mode: Fixed")
        log_success("✓ All hooks fixed successfully")

    return 0


if __name__ == "__main__":
    sys.exit(main())
