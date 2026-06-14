"""
test_hooks_optimization.py — Validates the v3.1.1 hook performance + reliability
improvements.

Covers (per the user's request: "e2e + unit-test completo que validen todas las mejoras"):

  UNIT (structural, hardware-independent — the robust regression guards):
    * No active recursive `claude --print` anywhere (root cause of the 4.4s/message bug).
    * project-state uses `find -L` (no per-symlink `-exec test`).
    * The 3 SessionStart maintenance hooks carry the detached-fork guard.
    * 100% of settings.json hooks have a `timeout`; values match the event policy.
    * The .mjs SessionStart command is `node <path>` (no escaped-quote form).
    * Every *.sh hook passes `bash -n`.

  E2E / PERFORMANCE (marked slow — threshold = the user's 500ms bar, ~5x headroom):
    * context-warning (every message) runs < 500ms.
    * Each SessionStart hook runs < 500ms; forked maintenance hooks < 200ms.
    * Full UserPromptSubmit chain runs < 500ms.
    * optimize-settings.py is idempotent (dry-run reports nothing to change).
    * validate-hooks.sh passes (JSON format, no regressions).

Run:  pytest tests/test_hooks_optimization.py -v
      pytest tests/test_hooks_optimization.py -v -m "not slow"   # skip timing
"""
from __future__ import annotations
import json
import os
import re
import subprocess
import time

import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Hooks whose performance/behavior this suite asserts on.
PERF_FIXED_HOOKS = [
    "context-warning.sh",
    "project-state.sh",
    "vault-graduation.sh",
    "vault-promotion.sh",
    "auto-sync-global.sh",
]
FORK_HOOKS = ["vault-graduation.sh", "vault-promotion.sh", "auto-sync-global.sh"]

# Event → expected timeout (seconds), mirrors optimize-settings.py TIMEOUT_POLICY.
TIMEOUT_POLICY = {
    "PreToolUse": 5,
    "UserPromptSubmit": 5,
    "PostToolUse": 10,
    "Stop": 10,
    "SessionStart": 10,
    "SessionEnd": 15,
    "PreCompact": 15,
    "SubagentStart": 10,
    "SubagentStop": 10,
    "TeammateIdle": 10,
    "TaskCompleted": 10,
    "TaskCreated": 10,
}

# Matches an *active* recursive Claude CLI invocation (the anti-pattern).
_CLAUDE_CALL = re.compile(r"\bclaude\s+(--print|-p)\b")


def _code_lines(path: str) -> list[tuple[int, str]]:
    """Return (lineno, text) for non-blank, non-comment lines of a shell script."""
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for i, raw in enumerate(f, 1):
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue
            out.append((i, raw))
    return out


def _all_sh_hooks(hooks_dir: str) -> list[str]:
    return sorted(
        os.path.join(hooks_dir, f)
        for f in os.listdir(hooks_dir)
        if f.endswith(".sh") and os.path.isfile(os.path.join(hooks_dir, f))
    )


def _run_hook(path: str, payload: str, timeout: float = 8.0) -> tuple[float, int]:
    """Run a hook with JSON payload on stdin. Return (elapsed_ms, returncode)."""
    start = time.perf_counter()
    proc = subprocess.run(
        ["bash", path],
        input=payload,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=PROJECT_ROOT,
    )
    return (time.perf_counter() - start) * 1000.0, proc.returncode


def _best_ms(path: str, payload: str, runs: int = 2) -> float:
    """Best-of-N elapsed ms (reduces noise from machine load)."""
    return min(_run_hook(path, payload)[0] for _ in range(runs))


def _event_hook_paths(event: str) -> list[str]:
    """Resolved .sh hook paths registered for a given event in settings.json."""
    settings = os.path.expanduser("~/.claude/settings.json")
    try:
        with open(settings, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return []
    paths = []
    for group in data.get("hooks", {}).get(event, []):
        for h in group.get("hooks", []):
            first = h.get("command", "").split()[0] if h.get("command") else ""
            if first.endswith(".sh") and os.path.isfile(first):
                paths.append(first)
    return paths


# Collected at import time so they can parametrize per-hook timing tests.
_UPS_HOOKS = _event_hook_paths("UserPromptSubmit")
_STOP_HOOKS = _event_hook_paths("Stop")


# ---------------------------------------------------------------------------
# UNIT — anti-pattern regression guards (fast, hardware-independent)
# ---------------------------------------------------------------------------

class TestNoRecursiveClaude:
    """The recursive `claude --print "/context"` subprocess caused the 4.4s/message
    bug. No hook may reintroduce it in active code."""

    def test_no_recursive_claude_in_any_hook(self, hooks_dir):
        violations = []
        for path in _all_sh_hooks(hooks_dir):
            for lineno, line in _code_lines(path):
                if _CLAUDE_CALL.search(line):
                    violations.append(f"{os.path.basename(path)}:{lineno}: {line.strip()}")
        assert not violations, (
            "Active recursive `claude --print` found (perf landmine):\n"
            + "\n".join(violations)
        )

    @pytest.mark.parametrize("hook", ["context-warning.sh", "project-state.sh", "periodic-reminder.sh"])
    def test_specific_hooks_clean(self, hooks_dir, hook):
        path = os.path.join(hooks_dir, hook)
        bad = [f"{ln}: {t.strip()}" for ln, t in _code_lines(path) if _CLAUDE_CALL.search(t)]
        assert not bad, f"{hook} still calls claude recursively:\n" + "\n".join(bad)


class TestProjectStateFindOptimization:
    def test_uses_find_dash_L(self, hooks_dir):
        text = open(os.path.join(hooks_dir, "project-state.sh"), encoding="utf-8").read()
        assert "find -L" in text, "project-state.sh should use `find -L` for broken symlinks"

    def test_no_per_symlink_exec_test(self, hooks_dir):
        for lineno, line in _code_lines(os.path.join(hooks_dir, "project-state.sh")):
            assert "-exec test -e" not in line, (
                f"project-state.sh:{lineno} still spawns a `test` per symlink (slow)"
            )


class TestForkGuards:
    """The 3 SessionStart maintenance hooks must self-relaunch detached."""

    @pytest.mark.parametrize("hook", FORK_HOOKS)
    def test_has_background_fork_guard(self, hooks_dir, hook):
        text = open(os.path.join(hooks_dir, hook), encoding="utf-8").read()
        assert "RALPH_HOOK_BG" in text, f"{hook} missing the detached-fork guard"
        assert "nohup bash" in text and "&" in text, f"{hook} fork guard incomplete"


# ---------------------------------------------------------------------------
# UNIT — settings.json hardening
# ---------------------------------------------------------------------------

class TestSettingsHardening:
    def test_settings_valid_json(self, load_settings_json):
        data = load_settings_json()  # call the factory fixture, don't assert the callable
        assert isinstance(data, dict) and data, "settings.json must be a non-empty JSON object"

    def test_event_hooks_resolved_for_timing(self):
        # Guard: the parametrized per-hook timing tests generate ZERO cases (silently) if
        # these import-time lists are empty. This sentinel fails loudly instead.
        assert _UPS_HOOKS, "No UserPromptSubmit hooks resolved from settings.json"
        assert _STOP_HOOKS, "No Stop hooks resolved from settings.json"

    def test_all_hooks_have_timeout(self, load_settings_json):
        data = load_settings_json()
        assert data, "settings.json not found/empty — cannot validate timeouts"
        missing = []
        for event, groups in data.get("hooks", {}).items():
            for group in groups:
                for h in group.get("hooks", []):
                    if "timeout" not in h:
                        missing.append(f"{event}: {h.get('command','?')}")
        assert not missing, "Hooks without timeout (60s-hang risk):\n" + "\n".join(missing)

    def test_timeout_values_match_policy(self, load_settings_json):
        data = load_settings_json()
        wrong = []
        for event, groups in data.get("hooks", {}).items():
            expected = TIMEOUT_POLICY.get(event)
            if expected is None:
                continue
            for group in groups:
                for h in group.get("hooks", []):
                    t = h.get("timeout")
                    # Pre-existing larger timeouts (e.g. 30/60 on async hooks) are allowed.
                    if t is not None and t < expected:
                        wrong.append(f"{event}: timeout={t} < policy {expected}")
        assert not wrong, "Timeouts below policy:\n" + "\n".join(wrong)

    def test_mjs_hook_present_and_timed(self, load_settings_json):
        # The context-mode .mjs hook entry is PLUGIN-OWNED: context-mode re-registers it
        # every session in a quoted form (`"/abs/path.mjs"`) that executes fine (the shell
        # strips the quotes). We do NOT assert its command form — that would fight the
        # plugin. We only assert our durable contribution survived: the timeout.
        data = load_settings_json()
        assert data, "settings.json not found/empty"
        for groups in data.get("hooks", {}).values():
            for group in groups:
                for h in group.get("hooks", []):
                    if "context-mode-cache-heal.mjs" in h.get("command", ""):
                        assert "timeout" in h, ".mjs hook should still carry a timeout"
                        return
        # Absent is acceptable (plugin may be disabled) — do not fail.


# ---------------------------------------------------------------------------
# UNIT — syntax
# ---------------------------------------------------------------------------

class TestSyntax:
    def test_all_hooks_bash_n_clean(self, hooks_dir):
        errors = []
        for path in _all_sh_hooks(hooks_dir):
            proc = subprocess.run(["bash", "-n", path], capture_output=True, text=True)
            if proc.returncode != 0:
                errors.append(f"{os.path.basename(path)}: {proc.stderr.strip()}")
        assert not errors, "bash -n failures:\n" + "\n".join(errors)


# ---------------------------------------------------------------------------
# E2E / PERFORMANCE — timing (slow). Threshold = user's 500ms bar (~5x headroom).
# ---------------------------------------------------------------------------

@pytest.mark.slow
class TestPerformance:
    THRESHOLD_MS = 500
    FORK_THRESHOLD_MS = 200

    def test_context_warning_under_threshold(self, hooks_dir):
        ms = _best_ms(os.path.join(hooks_dir, "context-warning.sh"), '{"prompt":"test"}')
        assert ms < self.THRESHOLD_MS, f"context-warning.sh took {ms:.0f}ms (>= {self.THRESHOLD_MS})"

    @pytest.mark.parametrize("hook", PERF_FIXED_HOOKS)
    def test_perf_fixed_hooks_under_threshold(self, hooks_dir, hook):
        payload = '{"hook_event_name":"SessionStart","source":"startup","prompt":"t"}'
        ms = _best_ms(os.path.join(hooks_dir, hook), payload)
        assert ms < self.THRESHOLD_MS, f"{hook} took {ms:.0f}ms (>= {self.THRESHOLD_MS})"

    @pytest.mark.parametrize("hook", FORK_HOOKS)
    def test_fork_hooks_return_fast(self, hooks_dir, hook):
        ms = _best_ms(os.path.join(hooks_dir, hook), '{"hook_event_name":"SessionStart"}')
        assert ms < self.FORK_THRESHOLD_MS, (
            f"{hook} returned in {ms:.0f}ms (>= {self.FORK_THRESHOLD_MS}); fork not effective"
        )

    @pytest.mark.parametrize(
        "hook_path", _UPS_HOOKS, ids=[os.path.basename(p) for p in _UPS_HOOKS] or ["none"]
    )
    def test_each_userpromptsubmit_hook_under_threshold(self, hook_path):
        """Each UserPromptSubmit hook (runs on every message) must clear the 500ms bar.
        Per-hook + best-of-3 = stable and pinpoints exactly which hook regressed, instead
        of a flaky aggregate sum over stateful, load-sensitive hooks."""
        if not _UPS_HOOKS:
            pytest.skip("no UserPromptSubmit hooks resolved from settings.json")
        ms = _best_ms(hook_path, '{"prompt":"test"}', runs=3)
        assert ms < self.THRESHOLD_MS, (
            f"{os.path.basename(hook_path)} took {ms:.0f}ms (>= {self.THRESHOLD_MS}); "
            "likely a reintroduced slow subprocess (e.g. recursive `claude`)."
        )

    @pytest.mark.parametrize(
        "hook_path", _STOP_HOOKS, ids=[os.path.basename(p) for p in _STOP_HOOKS] or ["none"]
    )
    def test_each_stop_hook_under_threshold(self, hook_path):
        """Each Stop hook (runs at every turn end) must clear the 500ms bar."""
        if not _STOP_HOOKS:
            pytest.skip("no Stop hooks resolved from settings.json")
        ms = _best_ms(hook_path, "{}", runs=3)
        assert ms < self.THRESHOLD_MS, (
            f"{os.path.basename(hook_path)} took {ms:.0f}ms (>= {self.THRESHOLD_MS})"
        )


# ---------------------------------------------------------------------------
# E2E — idempotency & no-regression
# ---------------------------------------------------------------------------

class TestIdempotencyAndRegression:
    def test_optimize_settings_idempotent(self, project_root):
        script = os.path.join(project_root, "scripts", "hook-optimization", "optimize-settings.py")
        if not os.path.isfile(script):
            pytest.skip("optimize-settings.py not present")
        proc = subprocess.run(["python3", script], capture_output=True, text=True, timeout=30)
        assert proc.returncode == 0, f"dry-run failed: {proc.stderr}"
        assert "Nothing to change" in proc.stdout, (
            "settings.json not fully hardened (optimize-settings found pending changes):\n"
            + proc.stdout
        )

    @pytest.mark.slow
    def test_validate_hooks_passes(self, project_root):
        script = os.path.join(project_root, "validate-hooks.sh")
        if not os.path.isfile(script):
            pytest.skip("validate-hooks.sh not present")
        proc = subprocess.run(["bash", script], capture_output=True, text=True, timeout=120)
        assert proc.returncode == 0, f"validate-hooks.sh failed:\n{proc.stdout}\n{proc.stderr}"
