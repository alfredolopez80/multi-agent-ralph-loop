#!/usr/bin/env python3
"""
test_jq_boolean_default_regression.py - Regression tests for BUG-2.

BUG-2: hooks read boolean config with

    ENABLED=$(jq -r '.auto_learn.blocking // true' "$CONFIG_FILE")

jq's `//` is an alternative operator over *falsy* values (null AND false), not
over null alone. So `false // true` evaluates to `true` and an explicit
`{"auto_learn": {"blocking": false}}` can never turn the feature off. For
orchestrator-auto-learn.sh that meant blocking mode was unconditionally on,
which forced the curator (BUG-1) to run synchronously inside a PreToolUse hook.

`// false` is safe (`false // false` is still `false`); only `// true` over a
boolean field is wrong. The correct form is an explicit null test:

    jq -r 'if (.x) == null then true else (.x) end'

Reference: tests/HOOK_FORMAT_REFERENCE.md
"""

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent

SEARCH_DIRS = [".claude/hooks", ".claude/scripts"]

# `// true` closing a single-quoted jq program, e.g. jq -r '.a.b // true'
_BOOLEAN_DEFAULT = re.compile(r"//\s*true'")

requires_jq = pytest.mark.skipif(shutil.which("jq") is None, reason="jq not installed")


def iter_shell_scripts():
    for rel_dir in SEARCH_DIRS:
        directory = REPO_ROOT / rel_dir
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.sh")):
            yield path


def run_jq(program, payload):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(payload, handle)
        config_path = handle.name
    try:
        return subprocess.run(
            ["jq", "-r", program, config_path],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    finally:
        Path(config_path).unlink(missing_ok=True)


class TestJqAlternativeOperatorSemantics:
    """Pin why `// true` is always wrong over a boolean field."""

    @requires_jq
    def test_alternative_operator_swallows_an_explicit_false(self):
        assert run_jq(".auto_learn.blocking // true", {"auto_learn": {"blocking": False}}) == "true", (
            "BUG-2 premise broke: jq's `//` no longer treats false as absent"
        )

    @requires_jq
    @pytest.mark.parametrize(
        "payload,expected",
        [
            ({"auto_learn": {"blocking": False}}, "false"),
            ({"auto_learn": {"blocking": True}}, "true"),
            ({"auto_learn": {}}, "true"),
            ({}, "true"),
        ],
    )
    def test_explicit_null_test_preserves_false_and_defaults_on_absence(self, payload, expected):
        program = "if (.auto_learn.blocking) == null then true else (.auto_learn.blocking) end"
        assert run_jq(program, payload) == expected

    @requires_jq
    def test_false_default_is_safe(self):
        """`// false` needs no change: false // false is still false."""
        assert run_jq(".a // false", {"a": False}) == "false"
        assert run_jq(".a // false", {}) == "false"


class TestNoBooleanDefaultsViaAlternativeOperator:
    """Repo-wide guard: `// true` must not reappear in hooks or scripts."""

    def test_detector_catches_the_original_defect(self):
        original = """    AUTO_LEARN_BLOCKING=$(jq -r '.auto_learn.blocking // true' "$CONFIG_FILE")"""
        assert _BOOLEAN_DEFAULT.search(original), (
            "detector no longer recognises the original BUG-2 line"
        )

    def test_detector_accepts_the_fixed_form(self):
        fixed = (
            """    AUTO_LEARN_BLOCKING=$(jq -r 'if (.auto_learn.blocking) == null """
            """then true else (.auto_learn.blocking) end' "$CONFIG_FILE")"""
        )
        assert not _BOOLEAN_DEFAULT.search(fixed)

    def test_no_hook_or_script_defaults_a_boolean_with_the_alternative_operator(self):
        violations = []
        for path in iter_shell_scripts():
            text = path.read_text(encoding="utf-8", errors="replace")
            for lineno, line in enumerate(text.split("\n"), 1):
                if line.lstrip().startswith("#"):
                    continue
                if _BOOLEAN_DEFAULT.search(line):
                    violations.append(f"{path.relative_to(REPO_ROOT)}:{lineno}: {line.strip()}")

        assert not violations, (
            "BUG-2 REGRESSION: `// true` used as a boolean default in jq. jq's "
            "`//` fires on false as well as null, so an explicit `false` in "
            "config is read as true and the feature can never be disabled.\n"
            + "\n".join(f"  - {v}" for v in violations)
            + "\n\nUse: jq -r 'if (.x) == null then true else (.x) end'"
        )


class TestOrchestratorAutoLearnHonoursBlockingFalse:
    """End-to-end: the hook must read blocking=false out of memory-config.json."""

    HOOK = REPO_ROOT / ".claude/hooks/orchestrator-auto-learn.sh"

    @requires_jq
    def test_blocking_false_is_read_as_false(self, tmp_path):
        if not self.HOOK.exists():
            pytest.skip("orchestrator-auto-learn.sh not present")

        config = tmp_path / "memory-config.json"
        config.write_text(json.dumps({"auto_learn": {"enabled": True, "blocking": False}}))

        # Replay the hook's own config read against a config that says false.
        program = next(
            line.split("jq -r '", 1)[1].rsplit("'", 1)[0]
            for line in self.HOOK.read_text().split("\n")
            if "AUTO_LEARN_BLOCKING=$(jq -r '" in line
        )
        result = subprocess.run(
            ["jq", "-r", program, str(config)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        assert result == "false", (
            "orchestrator-auto-learn.sh still cannot honour "
            f'{{"auto_learn": {{"blocking": false}}}}; it read {result!r}'
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
