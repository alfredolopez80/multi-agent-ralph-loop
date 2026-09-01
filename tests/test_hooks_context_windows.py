"""Tests for context-windows.sh v3.3.0 (T7).

Covers the T7-ctxwindow acceptance criteria that belong to the LIBRARY:
  1. get_context_window returns 1M for every "[1m]" model in use, and the
     correct table window without the suffix.
  2. The "[1m]" suffix is parsed EXPLICITLY: an UNKNOWN model carrying "[1m]"
     still resolves to 1M — this test fails if the parsing is removed and only
     table entries remain.
  3. Current models (glm-5.3, minimax-m3) are in the table; legacy entries kept.

The context-warning.sh hook tests (former criteria 4-6: Method 1.5 regression,
UserPromptSubmit JSON contract, real-data CRITICAL) were removed with the hook
by #69 Slice E (PR9) — native context management is authoritative.
"""
import json
import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / ".claude" / "lib" / "context-windows.sh"

# Environment variables that get_raw_model() consults — stripped for
# deterministic detection, re-added per test when needed.
_MODEL_ENV_KEYS = (
    "INPUT",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_BASE_URL",
    "AI_AGENT",
    "Z_AI_MODEL_DEEP",
    "MINIMAX_MODEL_STANDARD",
)


def _run_bash(script, env=None, stdin=None, timeout=30):
    env_full = {k: v for k, v in os.environ.items() if k not in _MODEL_ENV_KEYS}
    if env:
        env_full.update(env)
    return subprocess.run(
        ["bash", "-c", script],
        input=stdin,
        capture_output=True,
        text=True,
        env=env_full,
        timeout=timeout,
    )


def get_window(model=None, env=None):
    if model is not None:
        script = f'source "{LIB}"; get_context_window "{model}"'
    else:
        script = f'source "{LIB}"; get_context_window'
    result = _run_bash(script, env=env)
    assert result.returncode == 0, f"stderr: {result.stderr}"
    return result.stdout.strip()


class TestOneMillionMarker:
    """Done-when 1+2: '[1m]' is an explicit rule, not a table row."""

    @pytest.mark.parametrize(
        "model",
        [
            "glm-5.3[1m]",
            "MiniMax-M3[1m]",   # case + vendor casing must not matter
            "claude-opus-5[1m]",
            "GLM-9.9-FUTURE[1m]",        # unknown model + marker -> still 1M
            "some-never-seen-model[1m]",  # unknown model + marker -> still 1M
        ],
    )
    def test_1m_marker_yields_1m_window(self, model):
        # If the explicit [1m] parsing is removed and only table entries
        # remain, the two unknown models above fall to the 128K fallback and
        # this assertion FAILS. That is the point.
        assert get_window(model) == "1000000"

    def test_has_1m_context_is_case_insensitive(self):
        result = _run_bash(
            f'source "{LIB}"; has_1m_context "x[1M]" && echo YES'
        )
        assert "YES" in result.stdout

    def test_has_1m_context_rejects_unmarked_ids(self):
        result = _run_bash(
            f'source "{LIB}"; has_1m_context "glm-5.3" && echo YES || echo NO'
        )
        assert result.stdout.strip().endswith("NO")


class TestTableEntries:
    """Done-when 3: current models present, legacy entries preserved."""

    @pytest.mark.parametrize(
        "model, expected",
        [
            ("glm-5.3", "1000000"),      # 1M native (docs.z.ai)
            ("minimax-m3", "512000"),    # guaranteed floor (minimax.io)
            ("claude-opus-5", "950000"),
            ("glm-5.2", "200000"),       # legacy kept
            ("glm-5.1", "256000"),       # legacy kept
            ("minimax-m2.7", "200000"),  # legacy kept
        ],
    )
    def test_table_window_without_suffix(self, model, expected):
        assert get_window(model) == expected

    def test_prefix_match_longest_first(self):
        # glm-5.9 is unknown but prefix-matches glm-5 (128K), not glm-5.3.
        assert get_window("glm-5.9") == "128000"

    def test_unknown_model_fallback(self):
        assert get_window("brand-new-unknown") == "128000"


class TestDetection:
    """The no-arg detection path preserves the [1m] information end to end."""

    def test_detection_from_stdin_model_id(self):
        env = {"INPUT": json.dumps({"model": {"id": "MiniMax-M3[1m]"}})}
        assert get_window(env=env) == "1000000"
        result = _run_bash(
            f'source "{LIB}"; get_detected_model', env=env
        )
        assert result.stdout.strip() == "minimax-m3"

    def test_detection_without_any_signal(self):
        assert get_window() == "128000"  # unknown -> conservative fallback
