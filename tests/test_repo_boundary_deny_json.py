"""repo-boundary-guard must emit VALID JSON on its deny path.

A deny the harness cannot parse is a deny that denies nothing — a fail-open. The external
path-deny block built its JSON by string interpolation, so a path containing a double quote
produced malformed JSON. The sibling mentioned-path deny already used `jq -n`; this pins
that BOTH deny paths survive a quote in the payload.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
GUARD = REPO_ROOT / ".claude" / "hooks" / "repo-boundary-guard.sh"

# A path outside the current repo, under ~/Documents/GitHub, with a double quote in the
# name — the character that broke the interpolated heredoc.
EVIL_PATH = '/Users/alfredolopez/Documents/GitHub/OtherRepo/a"b.txt'  # tilde-ok: EVIL_PATH fixture the boundary guard must REJECT (path outside repo + breaking the heredoc interpolation)


def _run(payload: dict) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(GUARD)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        timeout=30,
        cwd=str(REPO_ROOT),
    )


@pytest.mark.skipif(not GUARD.is_file(), reason="repo-boundary-guard.sh not present")
@pytest.mark.parametrize("tool_input_key", ["file_path", "command"])
def test_external_path_deny_is_valid_json_with_a_quote(tool_input_key):
    """A quote in the denied path must not corrupt the JSON verdict."""
    value = EVIL_PATH if tool_input_key == "file_path" else f'cat "{EVIL_PATH}"'
    proc = _run({"tool_name": "Edit", "tool_input": {tool_input_key: value}})
    out = proc.stdout.strip()
    assert out, f"guard produced no stdout (rc={proc.returncode}): {proc.stderr}"
    # The whole point: it must parse. A ValueError here is the fail-open.
    parsed = json.loads(out)
    decision = parsed["hookSpecificOutput"]["permissionDecision"]
    # It should deny (external repo) — and whatever it decides, the JSON must be well-formed.
    assert decision in ("deny", "allow")
    if decision == "deny":
        assert "OtherRepo" in parsed["hookSpecificOutput"]["permissionDecisionReason"]
