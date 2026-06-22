#!/usr/bin/env python3
"""
Test Suite: Aristotle Analysis + Anti-Rationalization Gate Hooks
v1.0.0

Validates end-to-end behavior of the Aristotle 5-phase analysis chain
(UserPromptSubmit hooks) and the anti-rationalization Stop hook.

Tests produce detailed logs showing exactly what each hook returns,
making failures easy to diagnose without re-running.
"""
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
LOG_DIR = PROJECT_ROOT / "tests" / "logs"
HOOK_TIMEOUT = 30


# ═══════════════════════════════════════════════════════════════════
# Logging helper
# ═══════════════════════════════════════════════════════════════════

def log_result(test_name: str, hook_name: str, result: Dict[str, Any],
               input_preview: str = "") -> None:
    """Write structured log to tests/logs/ for post-run inspection."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = LOG_DIR / f"{test_name}_{timestamp}.json"

    log_entry = {
        "test": test_name,
        "hook": hook_name,
        "timestamp": timestamp,
        "input_preview": input_preview[:200],
        "returncode": result["returncode"],
        "stdout": result["stdout"][:500] if result["stdout"] else "",
        "stderr": result["stderr"][:500] if result["stderr"] else "",
        "is_valid_json": result["is_valid_json"],
        "parsed_output": result.get("output"),
        "execution_time": result["execution_time"],
    }

    log_file.write_text(json.dumps(log_entry, indent=2, ensure_ascii=False))
    # Also print to stdout for real-time visibility
    status = "PASS" if result["is_valid_json"] and result["returncode"] == 0 else "FAIL"
    print(f"  [{status}] {test_name} → {hook_name} ({result['execution_time']:.2f}s)")
    if result["stdout"]:
        print(f"       stdout: {result['stdout'][:150]}")
    if result["stderr"]:
        print(f"       stderr: {result['stderr'][:150]}")


def run_hook(hook_path: Path, input_data: str,
             timeout: int = HOOK_TIMEOUT, cwd: Path = None) -> Dict[str, Any]:
    """Execute a hook and return structured result.

    ``cwd`` controls the process working directory. It matters for the
    anti-rationalization gate, which resolves its per-project state and patterns
    file from ``$CWD`` (``.cwd`` in JSON input, else ``$(pwd)``). Tests point it
    at the isolated $HOME so the gate reads a clean, seeded
    ``.claude/state/anti-rat-blocks.json`` instead of the developer's repo state.
    """
    import time
    start = time.time()
    try:
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=input_data,
            capture_output=True,
            text=True,
            cwd=str(cwd) if cwd is not None else str(PROJECT_ROOT),
            timeout=timeout,
            env={**os.environ},
        )
        elapsed = time.time() - start

        is_valid = False
        output = None
        try:
            output = json.loads(result.stdout.strip())
            is_valid = True
        except (json.JSONDecodeError, ValueError):
            pass

        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "output": output,
            "is_valid_json": is_valid,
            "execution_time": elapsed,
        }
    except subprocess.TimeoutExpired:
        return {
            "returncode": -1, "stdout": "", "stderr": "TIMEOUT",
            "output": None, "is_valid_json": False,
            "execution_time": timeout,
        }
    except Exception as e:
        return {
            "returncode": -1, "stdout": "", "stderr": str(e),
            "output": None, "is_valid_json": False,
            "execution_time": 0,
        }


# ═══════════════════════════════════════════════════════════════════
# Hook paths
# ═══════════════════════════════════════════════════════════════════

# All hooks resolve to the repo's real, versioned scripts (CI-safe — never the
# developer's global ~/.claude/hooks). The classifier exists in the repo too.
CLASSIFIER_HOOK = (PROJECT_ROOT / ".claude" / "hooks" /
                   "universal-prompt-classifier.sh")
ARISTOTLE_HOOK = (PROJECT_ROOT / ".claude" / "hooks" /
                  "aristotle-analysis-display.sh")
ANTIRAT_HOOK = (PROJECT_ROOT / ".claude" / "hooks" /
                "anti-rationalization-gate.sh")
PATTERNS_FILE = (PROJECT_ROOT / "docs" / "reference" /
                 "anti-rationalization.md")


def state_dir() -> Path:
    """``~/.claude/state`` resolved at call time.

    Under the ``isolated_home`` fixture this is the temp HOME, so the
    classifier (writes ``~/.claude/state/current-complexity.json``) and the
    aristotle hook (reads it) share a clean, isolated state dir. The gate's
    ``$CWD/.claude/state`` is made to match by running it with ``cwd=Path.home()``.
    """
    return Path.home() / ".claude" / "state"


def antirat_state() -> Path:
    return state_dir() / "anti-rat-blocks.json"


def _seed_gate_env(home: Path) -> None:
    """Seed the isolated $HOME so the gate runs fully (real patterns + clean state).

    The gate resolves ``PATTERNS_FILE=$CWD/docs/reference/anti-rationalization.md``;
    symlink the repo's real file in so excuse detection is genuinely exercised.
    """
    state = home / ".claude" / "state"
    state.mkdir(parents=True, exist_ok=True)
    (state / "anti-rat-blocks.json").write_text('{"blocks": 0}')
    ref_dir = home / "docs" / "reference"
    ref_dir.mkdir(parents=True, exist_ok=True)
    link = ref_dir / "anti-rationalization.md"
    if not link.exists():
        link.symlink_to(PATTERNS_FILE)


def run_gate(input_data: str, timeout: int = HOOK_TIMEOUT) -> Dict[str, Any]:
    """Run the anti-rat gate with cwd=isolated $HOME (clean per-project state)."""
    return run_hook(ANTIRAT_HOOK, input_data, timeout=timeout, cwd=Path.home())


# ═══════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════

@pytest.fixture(autouse=True)
def setup_state(isolated_home, requires_tool):
    """Isolate $HOME and seed a clean, repo-backed gate environment per test.

    ``isolated_home`` redirects $HOME and ``Path.home()`` to a temp dir; this
    fixture additionally symlinks the real patterns file and writes a clean
    ``anti-rat-blocks.json`` so the gate exercises real excuse detection against
    isolated state (no cross-test bleed, no developer ~/.claude dependency).
    """
    requires_tool("jq")  # the gate fail-opens without jq — exercise the real path
    _seed_gate_env(isolated_home)
    yield


# ═══════════════════════════════════════════════════════════════════
# 1. PROMPT CLASSIFIER HOOK (UserPromptSubmit)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.skipif(not CLASSIFIER_HOOK.exists(),
                    reason="Classifier hook not installed globally")
class TestPromptClassifier:
    """Tests for universal-prompt-classifier.sh (UserPromptSubmit chain)."""

    def test_returns_continue_true(self):
        """Classifier must always return {"continue": true}."""
        inp = json.dumps({"prompt": "implement authentication"})
        r = run_hook(CLASSIFIER_HOOK, inp)
        log_result("classifier_continue", "universal-prompt-classifier.sh", r, inp)
        assert r["is_valid_json"], f"Invalid JSON: {r['stdout']}"
        assert r["output"]["continue"] is True, f"Expected continue=true: {r['output']}"

    def test_saves_complexity_state(self):
        """Classifier must write complexity score to state file."""
        inp = json.dumps({"prompt": "refactor the entire auth system"})
        run_hook(CLASSIFIER_HOOK, inp)
        state_file = state_dir() / "current-complexity.json"
        assert state_file.exists(), "Complexity state file not created"
        state = json.loads(state_file.read_text())
        assert "complexity" in state, f"Missing complexity key: {state}"
        assert isinstance(state["complexity"], int)
        assert 1 <= state["complexity"] <= 10
        log_result("classifier_state", "universal-prompt-classifier.sh",
                   {"returncode": 0, "stdout": json.dumps(state),
                    "stderr": "", "output": state, "is_valid_json": True,
                    "execution_time": 0},
                   f"complexity={state['complexity']}")

    def test_no_competing_system_message(self):
        """Classifier must NOT output hookSpecificOutput.systemMessage
        (delegated to aristotle hook)."""
        inp = json.dumps({"prompt": "implement auth system"})
        r = run_hook(CLASSIFIER_HOOK, inp)
        log_result("classifier_no_systemmsg", "universal-prompt-classifier.sh",
                   r, inp)
        if r["is_valid_json"] and r["output"]:
            assert "systemMessage" not in str(r["output"]), (
                "Classifier should NOT emit systemMessage — "
                "delegated to aristotle-analysis-display.sh"
            )


# ═══════════════════════════════════════════════════════════════════
# 2. ARISTOTLE ANALYSIS DISPLAY HOOK (UserPromptSubmit)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.skipif(not ARISTOTLE_HOOK.exists(),
                    reason="Aristotle hook not found in repo")
class TestAristotleAnalysis:
    """Tests for aristotle-analysis-display.sh (UserPromptSubmit chain)."""

    def test_returns_continue_true(self):
        """Aristotle hook must always return {"continue": true}."""
        inp = json.dumps({"prompt": "implement auth"})
        r = run_hook(ARISTOTLE_HOOK, inp)
        log_result("aristotle_continue", "aristotle-analysis-display.sh", r, inp)
        assert r["is_valid_json"], f"Invalid JSON: {r['stdout']}"
        assert r["output"]["continue"] is True, f"Expected continue=true: {r['output']}"

    def test_high_complexity_gets_system_message(self):
        """Complexity >= 4 should produce a systemMessage with Aristotle
        5-phase analysis."""
        # First set complexity to 7 via classifier
        state_dir().mkdir(parents=True, exist_ok=True)
        (state_dir() / "current-complexity.json").write_text(
            json.dumps({"complexity": 7, "timestamp": 0})
        )
        inp = json.dumps({"prompt": "redesign the authentication system"})
        r = run_hook(ARISTOTLE_HOOK, inp)
        log_result("aristotle_5phase", "aristotle-analysis-display.sh", r, inp)
        assert r["is_valid_json"], f"Invalid JSON: {r['stdout']}"
        output_str = json.dumps(r["output"])
        # Must contain Aristotle keywords
        assert "Aristotle" in output_str or "aristotle" in output_str, (
            f"Missing Aristotle reference in output: {output_str[:300]}"
        )

    def test_low_complexity_no_system_message(self):
        """Complexity 1-2 should NOT produce systemMessage."""
        state_dir().mkdir(parents=True, exist_ok=True)
        (state_dir() / "current-complexity.json").write_text(
            json.dumps({"complexity": 1, "timestamp": 0})
        )
        inp = json.dumps({"prompt": "fix typo"})
        r = run_hook(ARISTOTLE_HOOK, inp)
        log_result("aristotle_silent", "aristotle-analysis-display.sh", r, inp)
        assert r["is_valid_json"]
        output_str = json.dumps(r["output"])
        assert "Assumption Autopsy" not in output_str, (
            "Low complexity should NOT trigger full 5-phase analysis"
        )


# ═══════════════════════════════════════════════════════════════════
# 3. ANTI-RATIONALIZATION GATE HOOK (Stop)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.skipif(not ANTIRAT_HOOK.exists(),
                    reason="Anti-rationalization hook not found")
class TestAntiRationalizationGate:
    """Tests for anti-rationalization-gate.sh (Stop hook).

    Approve contract: per tests/HOOK_FORMAT_REFERENCE.md, a Stop hook ALLOWS the
    stop with a clean ``exit 0`` and NO ``{"decision": "approve"}`` output
    (``"approve"`` is NOT a valid Claude Code value — it was removed from this
    hook in commit 9ee86dce / v3.1.1 per docs/hooks/AUDIT-REPORT.md). So an
    "approve" is asserted as: returncode == 0 AND output is not a block.
    """

    @staticmethod
    def _assert_approves(r):
        """Stop-hook allow == clean exit 0 with no block decision."""
        assert r["returncode"] == 0, f"Approve must exit 0: {r}"
        if r["is_valid_json"] and isinstance(r["output"], dict):
            assert r["output"].get("decision") != "block", \
                f"Expected approve (allow), got block: {r['output']}"
        else:
            # Documented allow form: empty stdout (clean exit).
            assert r["stdout"].strip() == "", \
                f"Approve must emit no block JSON; got: {r['stdout']!r}"

    def _reset_state(self):
        antirat_state().write_text('{"blocks": 0}')

    def test_clean_stop_approves(self):
        """Genuine completion should be approved (clean exit 0, no block)."""
        self._reset_state()
        r = run_gate("All tasks completed. Tests pass.")
        log_result("antirat_clean_approve", "anti-rationalization-gate.sh", r,
                   "All tasks completed.")
        self._assert_approves(r)

    def test_doc_excuse_blocks(self):
        """Excuses from anti-rationalization.md should be blocked."""
        self._reset_state()
        excuse = '"It\'s faster to do it myself sequentially"'
        r = run_gate(f"I think {excuse}, let me stop here.")
        log_result("antirat_doc_block", "anti-rationalization-gate.sh", r,
                   f"excuse: {excuse}")
        assert r["is_valid_json"], f"Invalid JSON: {r['stdout']}"
        assert r["output"]["decision"] == "block"
        assert "reason" in r["output"], "Block must include reason"
        assert "excuse" in r["output"]["reason"].lower() or \
               "Excuse" in r["output"]["reason"], \
               f"Reason should mention excuse: {r['output']['reason']}"

    def test_parallel_excuse_blocks(self):
        """Parallel-first excuses should be blocked."""
        self._reset_state()
        r = run_gate(
            "Sequential is simpler to implement, I'll just do it one "
            "at a time.")
        log_result("antirat_parallel_block", "anti-rationalization-gate.sh", r,
                   "Sequential is simpler")
        assert r["is_valid_json"]
        assert r["output"]["decision"] == "block"
        assert "parallel-first" in r["output"]["reason"].lower() or \
               "parallel" in r["output"]["reason"].lower(), \
               f"Should reference parallel-first: {r['output']['reason']}"

    def test_max_blocks_circuit_breaker(self):
        """After 3 blocks, hook must auto-approve (circuit breaker)."""
        antirat_state().write_text('{"blocks": 3}')
        r = run_gate("Sequential is simpler")
        log_result("antirat_circuit_breaker", "anti-rationalization-gate.sh", r,
                   "blocks=3, should auto-approve")
        self._assert_approves(r)
        # Verify counter reset
        state = json.loads(antirat_state().read_text())
        assert state["blocks"] == 0, "Counter should reset after circuit breaker"

    def test_state_increments(self):
        """State file must increment on each block."""
        self._reset_state()
        run_gate("coordination overhead is too high")
        state = json.loads(antirat_state().read_text())
        log_result("antirat_state_increment", "anti-rationalization-gate.sh",
                   {"returncode": 0, "stdout": json.dumps(state),
                    "stderr": "", "output": state, "is_valid_json": True,
                    "execution_time": 0},
                   f"blocks after 1 block: {state['blocks']}")
        assert state["blocks"] == 1, f"Expected blocks=1, got {state['blocks']}"

    def test_empty_input_approves(self):
        """Empty input must not crash — approve safely (clean exit 0)."""
        self._reset_state()
        r = run_gate("")
        log_result("antirat_empty_input", "anti-rationalization-gate.sh", r,
                   "(empty)")
        self._assert_approves(r)

    def test_block_includes_rebuttal(self):
        """Block reason must include the rebuttal from the doc."""
        self._reset_state()
        r = run_gate("It's faster to do it myself sequentially")
        log_result("antirat_rebuttal", "anti-rationalization-gate.sh", r,
                   "faster to do it myself")
        assert r["is_valid_json"]
        assert r["output"]["decision"] == "block"
        reason = r["output"]["reason"]
        # Rebuttal should contain actionable advice
        assert any(word in reason.lower() for word in
                   ["parallel", "wall-clock", "faster for you"]), \
               f"Rebuttal missing actionable advice: {reason}"

    def test_multiple_excuses_first_match_wins(self):
        """Only the first matching excuse should trigger a block."""
        self._reset_state()
        r = run_gate("I already know the answer and "
                     "It's faster to do it myself sequentially")
        log_result("antirat_first_match", "anti-rationalization-gate.sh", r,
                   "two excuses, first match wins")
        assert r["is_valid_json"]
        assert r["output"]["decision"] == "block"
        # Should only increment by 1
        state = json.loads(antirat_state().read_text())
        assert state["blocks"] == 1


# ═══════════════════════════════════════════════════════════════════
# 4. PATTERNS FILE VALIDATION
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.skipif(not PATTERNS_FILE.exists(),
                    reason="anti-rationalization.md not found")
class TestPatternsFile:
    """Validate the anti-rationalization patterns source file."""

    def test_patterns_file_has_table_rows(self):
        """Patterns file must contain markdown table with excuse→rebuttal."""
        content = PATTERNS_FILE.read_text()
        lines = [l for l in content.split("\n") if l.startswith("|")]
        # Filter out header and separator
        data_lines = [l for l in lines
                      if "Excuse" not in l and "---" not in l]
        assert len(data_lines) >= 10, (
            f"Expected >= 10 excuse patterns, found {len(data_lines)}"
        )
        log_result("patterns_count", "anti-rationalization.md",
                   {"returncode": 0, "stdout": str(len(data_lines)),
                    "stderr": "", "output": {"count": len(data_lines)},
                    "is_valid_json": True, "execution_time": 0})

    def test_each_row_has_excuse_and_rebuttal(self):
        """Each table row must have at least 3 pipes (4 columns)."""
        content = PATTERNS_FILE.read_text()
        lines = [l for l in content.split("\n")
                 if l.startswith("|") and "Excuse" not in l
                 and "---" not in l]
        for i, line in enumerate(lines):
            pipes = line.count("|")
            assert pipes >= 4, (
                f"Row {i} has only {pipes} pipes (need >= 4): {line[:80]}"
            )


# ═══════════════════════════════════════════════════════════════════
# 5. END-TO-END CHAIN TEST
# ═══════════════════════════════════════════════════════════════════

class TestEndToEndChain:
    """Simulates the full hook chain: classifier → aristotle → stop."""

    def test_full_chain_complex_task(self):
        """Complex task: classifier scores high, aristotle shows analysis,
        stop with excuse gets blocked."""
        # Step 1: Classifier scores complexity
        if CLASSIFIER_HOOK.exists():
            inp = json.dumps({
                "prompt": "redesign the authentication system "
                          "with OAuth2 and JWT tokens"
            })
            r1 = run_hook(CLASSIFIER_HOOK, inp)
            log_result("chain_step1_classifier", "universal-prompt-classifier.sh",
                       r1, inp[:80])
            assert r1["is_valid_json"]
            assert r1["output"]["continue"] is True

            # Read saved complexity
            state = json.loads(
                (state_dir() / "current-complexity.json").read_text())
            complexity = state["complexity"]
            assert complexity >= 3, (
                f"Complex prompt should score >= 3, got {complexity}"
            )
        else:
            complexity = 5  # assume if classifier not available

        # Step 2: Aristotle produces analysis for high complexity
        if ARISTOTLE_HOOK.exists() and complexity >= 4:
            inp = json.dumps({"prompt": "redesign the auth system"})
            r2 = run_hook(ARISTOTLE_HOOK, inp)
            log_result("chain_step2_aristotle", "aristotle-analysis-display.sh",
                       r2, inp[:80])
            assert r2["is_valid_json"]
            output_str = json.dumps(r2["output"])
            assert "Aristotle" in output_str or "Aristotelian" in output_str, \
                   f"High complexity should trigger Aristotle: {output_str[:200]}"

        # Step 3: Anti-rationalization blocks excuse
        if ANTIRAT_HOOK.exists():
            antirat_state().write_text('{"blocks": 0}')
            excuse = "It's faster to do it myself sequentially"
            r3 = run_gate(f"I think {excuse}, stopping here.")
            log_result("chain_step3_antirat_block",
                       "anti-rationalization-gate.sh", r3, excuse)
            assert r3["is_valid_json"]
            assert r3["output"]["decision"] == "block"

    def test_full_chain_simple_task(self):
        """Simple task: classifier scores low, aristotle silent,
        clean stop approves."""
        # Step 1: Classifier
        if CLASSIFIER_HOOK.exists():
            inp = json.dumps({"prompt": "fix typo in readme"})
            r1 = run_hook(CLASSIFIER_HOOK, inp)
            assert r1["is_valid_json"]
            state = json.loads(
                (state_dir() / "current-complexity.json").read_text())
            complexity = state["complexity"]
            log_result("chain_simple_step1", "universal-prompt-classifier.sh",
                       r1, f"complexity={complexity}")
        else:
            complexity = 1

        # Step 2: Aristotle silent for low complexity
        if ARISTOTLE_HOOK.exists():
            state_dir().mkdir(parents=True, exist_ok=True)
            (state_dir() / "current-complexity.json").write_text(
                json.dumps({"complexity": 1, "timestamp": 0})
            )
            inp = json.dumps({"prompt": "fix typo"})
            r2 = run_hook(ARISTOTLE_HOOK, inp)
            log_result("chain_simple_step2", "aristotle-analysis-display.sh",
                       r2, "complexity=1, should be silent")
            assert r2["is_valid_json"]
            output_str = json.dumps(r2["output"])
            assert "Assumption Autopsy" not in output_str

        # Step 3: Clean stop approves (Stop allow == clean exit 0, no block)
        if ANTIRAT_HOOK.exists():
            antirat_state().write_text('{"blocks": 0}')
            r3 = run_gate("Fixed the typo. All tests pass.")
            log_result("chain_simple_step3", "anti-rationalization-gate.sh",
                       r3, "clean stop")
            assert r3["returncode"] == 0, f"Approve must exit 0: {r3}"
            if r3["is_valid_json"] and isinstance(r3["output"], dict):
                assert r3["output"].get("decision") != "block", \
                    f"Expected approve (allow), got block: {r3['output']}"
            else:
                assert r3["stdout"].strip() == "", \
                    f"Approve must emit no block JSON; got: {r3['stdout']!r}"
