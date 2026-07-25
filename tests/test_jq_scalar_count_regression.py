#!/usr/bin/env python3
"""
test_jq_scalar_count_regression.py - Regression tests for BUG-1.

BUG-1: curator-discovery.sh read a repository count with

    count=$(echo "$response" | jq '[.items | length] // 0')

`[.items | length]` wraps the count in a *array*, which jq pretty-prints over
three lines, so `count` held the literal string "[\\n  100\\n]". Every later use
(`[ "$count" -eq 0 ]`, `total_results=$((total_results + count))`) then died with
"integer expected" / "syntax error". The `// 0` fallback never fired either,
because a non-empty array is truthy in jq.

The corrected idiom is:

    count=$(printf '%s' "$response" | jq -r '(.items // []) | length')
    case "$count" in ''|*[!0-9]*) count=0 ;; esac

These tests do two things:
1. Pin the behavioural difference between the buggy and the fixed jq expression.
2. Lint every tracked shell script for the buggy idiom so it cannot come back.

Reference: tests/HOOK_FORMAT_REFERENCE.md, tests/HOOK_TESTING_PATTERNS.md
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent

# The exact line that shipped in ~/.ralph/curator/scripts/curator-discovery.sh.
# Kept verbatim so the detector below is proven against the real defect.
BUGGY_LINE = """            count=$(echo "$response" | jq '[.items | length] // 0' 2>/dev/null || echo "0")"""

FIXED_LINES = """            count=$(printf '%s' "$response" | jq -r '(.items // []) | length' 2>/dev/null || echo "0")
            case "$count" in ''|*[!0-9]*) count=0 ;; esac"""

# Matches `VAR=$(... jq [flags] '[ ... ] ...' ...)`, i.e. a jq program whose
# top-level output is an array being captured into a scalar shell variable.
_ARRAY_INTO_SCALAR = re.compile(
    r"""^\s*(?:local\s+)?[A-Za-z_][A-Za-z0-9_]*=\$\(       # VAR=$(
        [^)]*?\bjq\b[^)]*?                                  # ... jq ...
        (['"])\s*\[                                         # opening quote then [
        [^'"]*\|\s*length\s*\]                              # ... | length ]
    """,
    re.VERBOSE,
)


def find_array_wrapped_counts(text: str):
    """Return (line_number, line) for each scalar assignment of a jq array count."""
    hits = []
    for lineno, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("#"):
            continue
        if _ARRAY_INTO_SCALAR.search(line):
            hits.append((lineno, line.strip()))
    return hits


def iter_tracked_shell_scripts():
    """Every tracked *.sh in the repo, excluding archives and test fixtures."""
    result = subprocess.run(
        ["git", "ls-files", "*.sh"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    for rel in result.stdout.split("\n"):
        rel = rel.strip()
        if not rel:
            continue
        # Archived scripts are frozen history, and tests deliberately build
        # arrays (`[.rules[].rule_id] | unique | length`) as real array output.
        if "/archive/" in rel or rel.startswith("tests/"):
            continue
        yield REPO_ROOT / rel


requires_jq = pytest.mark.skipif(shutil.which("jq") is None, reason="jq not installed")


class TestJqCountIdiom:
    """Pin the exact behaviour that made BUG-1 fatal."""

    @requires_jq
    def test_buggy_expression_yields_a_multiline_array_not_an_integer(self):
        out = subprocess.run(
            ["jq", "[.items | length] // 0"],
            input='{"items":[1,2,3]}',
            capture_output=True,
            text=True,
            check=True,
        ).stdout

        assert not out.strip().isdigit(), (
            "BUG-1 premise broke: `[.items | length]` is expected to emit an "
            f"array, got {out!r}"
        )
        assert "\n" in out.strip(), "expected jq to pretty-print the array over several lines"

    @requires_jq
    @pytest.mark.parametrize(
        "response,expected",
        [
            ('{"items":[1,2,3]}', "3"),
            ('{"items":[]}', "0"),
            ("{}", "0"),
        ],
    )
    def test_fixed_expression_yields_a_bare_integer(self, response, expected):
        out = subprocess.run(
            ["jq", "-r", "(.items // []) | length"],
            input=response,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        assert out == expected
        assert out.isdigit(), f"count must be usable in shell arithmetic, got {out!r}"

    def test_fixed_snippet_survives_shell_arithmetic(self):
        """The full corrected snippet must never blow up `[ -eq ]` or `$(( ))`."""
        script = f"""
        set -u
        response="$1"
{FIXED_LINES}
        total=0
        [ "$count" -eq 0 ] || total=$((total + count))
        echo "$count $total"
        """
        for response, expected in [
            ('{"items":[1,2,3]}', "3 3"),
            ('{"items":[]}', "0 0"),
            ("not json", "0 0"),
            ("", "0 0"),
        ]:
            result = subprocess.run(
                ["bash", "-c", script, "bash", response],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"snippet failed on {response!r}: {result.stderr}"
            assert result.stdout.strip() == expected


class TestNoArrayWrappedScalarCounts:
    """Repo-wide guard: the buggy idiom must not reappear."""

    def test_detector_catches_the_original_defect(self):
        """The detector is proven against the exact line that shipped broken."""
        assert find_array_wrapped_counts(BUGGY_LINE), (
            "detector no longer recognises the original BUG-1 line; "
            "it would not catch a regression"
        )

    def test_detector_accepts_the_fixed_form(self):
        assert find_array_wrapped_counts(FIXED_LINES) == []

    def test_no_tracked_shell_script_wraps_a_count_in_an_array(self):
        violations = []
        for path in iter_tracked_shell_scripts():
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for lineno, line in find_array_wrapped_counts(text):
                violations.append(f"{path.relative_to(REPO_ROOT)}:{lineno}: {line}")

        assert not violations, (
            "BUG-1 REGRESSION: jq array-wrapped count assigned to a scalar shell "
            "variable. jq pretty-prints the array over several lines, so the "
            "variable is unusable in `[ -eq ]` and `$(( ))`.\n"
            + "\n".join(f"  - {v}" for v in violations)
            + "\n\nUse: count=$(jq -r '(.items // []) | length') plus a numeric guard."
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
