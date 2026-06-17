"""Regression tests for the PreToolUse `permissionDecision` enum.

ROOT CAUSE (fixed 2026-06-18)
----------------------------
PreToolUse guard hooks emitted, on their block path:

    {"hookSpecificOutput": {"permissionDecision": "block", ...}}

But Claude Code's PreToolUse `permissionDecision` field only accepts the enum
`allow | deny | ask` (verified against /anthropics/claude-code hook-development
docs). The value "block" belongs to the *Stop* hook `decision` field ONLY.
Emitting "block" made Claude Code reject the whole object at the discriminated
union root:

    Hook JSON output validation failed — (root): Invalid input

This module is the regression net. It has two layers:

1. STATIC  — every `"permissionDecision": "<value>"` emit-site across all hooks
             must use allow/deny/ask. Deterministic; mirrors the pre-commit
             gate scripts/check-pretooluse-permission-decision.sh.
2. DYNAMIC — the guard hooks' deny branch, exercised end-to-end, must emit a
             schema-valid `deny` (never `block`).

Reference: tests/HOOK_FORMAT_REFERENCE.md rule #4.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOKS_DIR = REPO_ROOT / ".claude" / "hooks"
CHECK_SCRIPT = REPO_ROOT / "scripts" / "check-pretooluse-permission-decision.sh"

VALID_DECISIONS = {"allow", "deny", "ask"}

# Matches the EMIT form  "permissionDecision": "value"
# (the detector form  .permissionDecision == "value"  is intentionally excluded
#  — it reads a decision, it does not emit one).
EMIT_RE = re.compile(r'"permissionDecision"\s*:\s*"([A-Za-z]+)"')


def _hook_files() -> list[Path]:
    return sorted(p for p in HOOKS_DIR.glob("*") if p.suffix in {".sh", ".py"})


def _make_payload(command: str, cwd: str | None = None) -> str:
    return json.dumps(
        {
            "session_id": "test",
            "cwd": cwd or str(REPO_ROOT),
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": command, "description": "test"},
        }
    )


def _run_hook(hook: str, payload: str) -> dict:
    """Run a hook with a payload on stdin; return parsed JSON stdout (or {})."""
    path = HOOKS_DIR / hook
    runner = ["python3", str(path)] if path.suffix == ".py" else [str(path)]
    proc = subprocess.run(
        runner,
        input=payload,
        capture_output=True,
        text=True,
        timeout=30,
        cwd=str(REPO_ROOT),
    )
    out = proc.stdout.strip()
    if not out:
        return {}
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {}


# ---------------------------------------------------------------------------
# STATIC layer
# ---------------------------------------------------------------------------
class TestStaticPermissionDecisionEnum:
    def test_no_hook_emits_invalid_permission_decision(self):
        """No hook may emit a permissionDecision outside allow/deny/ask."""
        violations: list[str] = []
        for hook in _hook_files():
            text = hook.read_text(encoding="utf-8", errors="replace")
            for lineno, line in enumerate(text.splitlines(), start=1):
                for value in EMIT_RE.findall(line):
                    if value not in VALID_DECISIONS:
                        violations.append(f"{hook.name}:{lineno}: permissionDecision={value!r}")
        assert not violations, (
            "PreToolUse permissionDecision must be allow/deny/ask "
            '("block" is a Stop-hook decision value). Offenders:\n  '
            + "\n  ".join(violations)
        )

    def test_no_hook_emits_block_permission_decision(self):
        """Explicit guard against the exact regression: permissionDecision=block."""
        offenders = []
        for hook in _hook_files():
            text = hook.read_text(encoding="utf-8", errors="replace")
            if re.search(r'"permissionDecision"\s*:\s*"block"', text):
                offenders.append(hook.name)
        assert not offenders, (
            'permissionDecision: "block" is invalid for PreToolUse → causes '
            '"(root): Invalid input". Use "deny". Offenders: ' + ", ".join(offenders)
        )


# ---------------------------------------------------------------------------
# DYNAMIC layer — exercise the deny branch that was failing
# ---------------------------------------------------------------------------
class TestDynamicDenyBranch:
    @pytest.mark.parametrize(
        "hook,command",
        [
            ("git-safety-guard.py", "git reset --hard HEAD"),
            ("git-safety-guard.py", "rm -rf ~/some-target"),
            ("permission-guard.sh", "git reset --hard HEAD"),
        ],
    )
    def test_deny_branch_emits_valid_decision(self, hook, command):
        output = _run_hook(hook, _make_payload(command))
        hso = output.get("hookSpecificOutput", output)
        decision = hso.get("permissionDecision")
        assert decision == "deny", (
            f"{hook} deny-branch must emit permissionDecision='deny', got {decision!r}. "
            f"Raw output: {output}"
        )
        # And never the invalid legacy value.
        assert decision != "block"

    def test_allow_branch_still_valid(self):
        output = _run_hook("git-safety-guard.py", _make_payload("ls -la"))
        hso = output.get("hookSpecificOutput", output)
        assert hso.get("permissionDecision") == "allow", output


# ---------------------------------------------------------------------------
# The pre-commit gate itself must pass on the current tree
# ---------------------------------------------------------------------------
class TestCheckerScript:
    def test_checker_script_exists_and_executable(self):
        assert CHECK_SCRIPT.exists(), f"missing {CHECK_SCRIPT}"
        assert CHECK_SCRIPT.stat().st_mode & 0o111, "checker script must be executable"

    def test_checker_script_passes_static(self):
        proc = subprocess.run(
            [str(CHECK_SCRIPT)],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(REPO_ROOT),
        )
        assert proc.returncode == 0, (
            f"checker script failed (exit {proc.returncode}):\n{proc.stdout}\n{proc.stderr}"
        )
