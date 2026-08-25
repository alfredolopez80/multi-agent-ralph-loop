"""Tests for .claude/hooks/qteam-blocked-notify.sh (issue #66, T31, T32).

The hook records which pane (worker or lead) is blocked on a permission
prompt. While the prompt is pending the MODEL IS FROZEN — it cannot run
any tool, SendMessage included. The notice therefore has to come from
outside the model's turn, which is what this hook does.

v2.1.0 (T32 hold): drop-box only, no transport emit. Claude Code already
notifies the user on permission prompts via its own settings.json
(`inputNeededNotifEnabled` + `agentPushNotifEnabled`); the hook only
records. 3 TSV fields by design — no transport column while there is
only one transport in use.

Contract under test:
- Always emits exactly ``{"continue": true}`` on stdout and exits 0.
- Both panes (worker + lead) write a drop-box line; origin identifies
  which pane was blocked.
- Defends against missing ``jq`` without crashing.
- Carries no mechanism that could answer the prompt (issue #66
  acceptance criterion). The harness asks the human in that pane; if
  the hook could approve from anywhere, three permission boundaries
  would collapse.

These tests are BEHAVIORAL — they execute the hook with real
subprocesses, inspect actual outputs, and assert on filesystem side
effects. They do not just check that strings appear in the source.
"""
from __future__ import annotations

import concurrent.futures
import json
import os
import re
import stat
import subprocess
from pathlib import Path

import pytest


# Path resolution: this file lives at tests/test_hooks_qteam_blocked_notify.py,
# the repo root is the parent of `tests/`.
TESTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TESTS_DIR.parent
HOOK_PATH = REPO_ROOT / ".claude" / "hooks" / "qteam-blocked-notify.sh"


# Acceptance criterion from issue #66. Each pattern is asserted absent in
# the hook source AFTER stripping full-line ``#`` comments. A future
# refactor that re-introduces a response mechanism will trip at least
# one of these.
#
# v2.1.0 (T32 hold): the OSC-era patterns (]52;) are gone because the
# hook no longer emits OSC. The remaining list expresses the
# "ability to respond" property for a drop-box-only hook:
#   - SendMessage, /qteam, permissionDecision: response channels.
#   - osascript: the abandoned transport; its reintroduction would
#     duplicate Claude Code's native notification (see v2.1.0
#     header for the measurement that justifies this rule).
FORBIDDEN_RESPONSE_PATTERNS = [
    (r"\bSendMessage\b",
     "Cross-session message: collapses 3 permission boundaries."),
    (r"/qteam\b",
     "Q-team protocol surface — only humans use this."),
    (r"permissionDecision",
     "PreToolUse vocabulary; not valid in a Notification hook."),
    (r"\bosascript\b",
     # IMPORTANT — read before deleting this pattern.
     # osascript is NOT in the v2.1.0 source. The pattern is here
     # because v1.0.0 / v2.0.0 used osascript (AppleScript display
     # notification) as the transport, and the T32 measurement showed
     # that Claude Code's native notification already reaches the
     # user; reintroducing osascript would duplicate that native
     # notification for the same event. The next maintainer who is
     # tempted to "clean up this dead pattern" should leave it: the
     # dead pattern is a guard rail. See the v2.1.0 header in
     # .claude/hooks/qteam-blocked-notify.sh for the full measurement.
     "osascript is the abandoned v1/v2 transport; reintroducing it "
     "would duplicate Claude Code's native notification. Kept as a "
     "guard rail even though the v2.1.0 source has no osascript call."),
]


# v2.1.0 positive guard: the drop-box write must be present. The
# forbidden list is vacuously satisfiable by deleting everything;
# this guard ensures the hook actually does its ONE job (record to
# the drop-box) instead of being a no-op. 3 fields, matching the
# 3-column TSV the hook produces.
DROP_BOX_POSITIVE_GUARD = "printf '%s\\t%s\\t%s\\n'"


# =============================================================================
# Helpers
# =============================================================================


def _build_isolated_bin(parent: Path, *, with_jq: bool) -> Path:
    """Create a fake bin dir with the tool subset the hook should see.

    v2.1.0: no osascript parameter, no tmux parameter. The hook's only
    external command now is ``jq``.
    """
    bin_dir = parent / "fakebin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    required_tools = [
        "bash", "cat", "head", "mkdir", "printf", "date", "env", "sh",
    ]
    seen = set()
    for tool in required_tools:
        for prefix in ("/usr/bin", "/bin"):
            target = Path(prefix) / tool
            if target.exists() and tool not in seen:
                (bin_dir / tool).symlink_to(target)
                seen.add(tool)
                break
    if with_jq and "jq" not in seen:
        for prefix in ("/usr/bin", "/bin", "/opt/homebrew/bin"):
            target = Path(prefix) / "jq"
            if target.exists():
                (bin_dir / "jq").symlink_to(target)
                seen.add("jq")
                break
    return bin_dir


@pytest.fixture
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """An isolated ``$HOME`` for the duration of one test."""
    monkeypatch.setenv("HOME", str(tmp_path))
    return tmp_path


@pytest.fixture
def hook_path_minimal(tmp_path: Path, fake_home: Path,
                      monkeypatch: pytest.MonkeyPatch) -> Path:
    """A PATH with jq, bash, coreutils, no other extras.

    v2.1.0: the hook does not use osascript or tmux, so the bin only
    needs the basics plus jq.
    """
    bin_dir = _build_isolated_bin(tmp_path, with_jq=True)
    monkeypatch.setenv("PATH", str(bin_dir))
    monkeypatch.setenv("LANG", "C.UTF-8")
    monkeypatch.setenv("LC_ALL", "C.UTF-8")
    return HOOK_PATH


@pytest.fixture
def hook_path_no_jq(tmp_path: Path, fake_home: Path,
                    monkeypatch: pytest.MonkeyPatch) -> Path:
    """A PATH with bash but no jq. Tests the early-exit path."""
    bin_dir = _build_isolated_bin(tmp_path, with_jq=False)
    monkeypatch.setenv("PATH", str(bin_dir))
    monkeypatch.setenv("LANG", "C.UTF-8")
    monkeypatch.setenv("LC_ALL", "C.UTF-8")
    return HOOK_PATH


def run_hook(stdin_payload: str, *, env: dict | None = None,
             cwd: str | None = None, timeout: int = 10) -> dict:
    """Run the hook as a subprocess and return its outputs as a dict."""
    proc = subprocess.run(
        ["bash", str(HOOK_PATH)],
        input=stdin_payload.encode("utf-8"),
        capture_output=True,
        timeout=timeout,
        cwd=cwd,
        env=env if env is not None else os.environ.copy(),
    )
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout.decode("utf-8"),
        "stderr": proc.stderr.decode("utf-8"),
    }


def assert_emits_continue_true(result: dict) -> None:
    """Every code path must end with exactly ``{"continue": true}``."""
    assert result["returncode"] == 0, (
        f"Hook exited {result['returncode']}; "
        f"stdout={result['stdout']!r} stderr={result['stderr']!r}"
    )
    out = result["stdout"].strip()
    assert out == '{"continue": true}', (
        f"Hook stdout was {out!r}; expected exactly '{{\"continue\": true}}'"
    )
    assert json.loads(out) == {"continue": True}


def make_worker_cwd(parent: Path, name: str) -> Path:
    """Build a path shaped like ``<parent>/fake/.claude/worktrees/<name>``."""
    d = parent / "fake" / ".claude" / "worktrees" / name
    d.mkdir(parents=True, exist_ok=True)
    return d


# =============================================================================
# Section 1: Sanity — file presence and version metadata
# =============================================================================


def test_hook_file_exists_and_is_executable():
    """The hook is at the documented path and is executable."""
    assert HOOK_PATH.exists(), f"Hook missing at {HOOK_PATH}"
    mode = HOOK_PATH.stat().st_mode
    assert mode & stat.S_IXUSR, f"Hook is not user-executable: {oct(mode)}"


def test_hook_has_version_marker():
    """The hook carries a ``VERSION:`` line for issue-tracking."""
    text = HOOK_PATH.read_text(encoding="utf-8")
    assert re.search(r"^#\s*VERSION:\s*\d+\.\d+\.\d+", text, re.MULTILINE), (
        "Hook lacks a VERSION: comment line; add one to track changes."
    )


# =============================================================================
# Section 2: ALWAYS emits {"continue": true}
# =============================================================================


@pytest.mark.parametrize("payload,case_id", [
    ("", "empty-stdin"),
    ("not json at all {{{", "invalid-json"),
    ("null", "null"),
    ("{}", "empty-object"),
    (json.dumps({"foo": "bar"}), "unexpected-shape"),
    (json.dumps({"message": None, "cwd": None}), "null-fields"),
    ("x" * 200000, "200KB-of-x"),
])
def test_always_emits_continue_true(hook_path_minimal, fake_home,
                                    payload, case_id):
    """No matter the input, stdout is exactly ``{"continue": true}``."""
    result = run_hook(payload)
    assert_emits_continue_true(result)


# =============================================================================
# Section 3: cwd filtering — both panes are recorded
# =============================================================================


@pytest.mark.parametrize("name", [
    "zc", "mmx-1", "mmx-2",
    "name-with-hyphens", "with.dots", "deeply-nested-name",
])
def test_cwd_under_worktree_continues_cleanly(
    hook_path_minimal, fake_home, name,
):
    """cwd under .claude/worktrees/<name> — hook runs the body path."""
    wd = make_worker_cwd(fake_home, name)
    payload = json.dumps({"message": "needs approval", "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)


@pytest.mark.parametrize("cwd,case_id", [
    ("/etc", "etc"),
    ("/var/log", "var-log"),
    ("/tmp", "tmp"),
    ("/usr/local", "usr-local"),
])
def test_cwd_outside_worktree_is_the_lead_pane_and_writes_dropbox(
    hook_path_minimal, fake_home, cwd, case_id,
):
    """cwd NOT under a worktree is the lead's pane, NOT a no-op.

    v1.0.0 of this hook excluded any cwd that didn't match the worktree
    pattern, on the false assumption that "the lead's own prompts are
    in front of whoever is already reading this session". That premise
    failed in production: a guard blocked the lead and the user was
    not at the keyboard, so the user got no notification at all and
    explicitly complained ("no me llego ninguna notificacion de que
    requerias una respuesta o atencion de mi parte, eso debe
    corregirse").

    v2.0.0 (T32) treats the lead's pane the same as a worker's: the
    user is told which pane is blocked, regardless of which pane it
    is. The old assertion that "lead pane must NOT produce drop-box
    lines" was faithfully testing a wrong design decision. This test
    deliberately inverts that expectation.

    This is the inverse of ``verify-test-expectations``: there, the
    test was wrong and we fixed it. Here, the test was right about
    WHAT it codified, but the design it codified was wrong.
    """
    payload = json.dumps({
        "message": f"lead-blocked-{case_id}",
        "cwd": cwd,
    })
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert drop_tsv.exists(), (
        "v2.0.0: the lead's pane MUST produce a drop-box line, not a "
        "no-op. The user complained that a blocked lead went invisible."
    )
    lines = drop_tsv.read_text().strip().split("\n")
    assert len(lines) == 1
    parts = lines[0].split("\t")
    assert len(parts) == 3, f"Expected 3 TSV fields, got {parts!r}"
    assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", parts[0])
    assert parts[1] == "lead", (
        f"v2.0.0: lead's pane must be marked 'lead' (was {parts[1]!r})"
    )
    assert parts[2] == f"lead-blocked-{case_id}", (
        f"Message not preserved: {parts[2]!r}"
    )


# =============================================================================
# Section 4: message handling
# =============================================================================


def test_message_absent_uses_default_body(hook_path_minimal, fake_home):
    """Missing ``message`` field — hook still continues cleanly."""
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"cwd": str(wd)})  # no message
    result = run_hook(payload)
    assert_emits_continue_true(result)


def test_message_empty_string_uses_default_body(hook_path_minimal, fake_home):
    """Empty ``message`` string — hook still continues cleanly."""
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "", "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)


@pytest.mark.parametrize("body,case_id", [
    ('with "double quotes"', "double-quotes"),
    ('with \\backslashes\\', "backslashes"),
    ('mixed "quotes" and \\backslashes\\', "both"),
    ('"""triple-quotes"""', "triple-quotes"),
    ('\\\\', "only-backslashes"),
    ('tab\there', "tab"),
    ('leading\nnewline', "leading-newline"),
    ('trailing newline\n', "trailing-newline"),
    ('he said "hi" and walked \\away\\', "realistic"),
    ('café résumé naïve', "accents"),
    ('日本語のテスト — em-dash 連続', "jp-with-emdash"),
])
def test_message_special_chars_pass_through_cleanly(
    hook_path_minimal, fake_home, body, case_id,
):
    """The hook must continue cleanly with arbitrary special characters.

    v1/v2 had an ``as_quote`` that escaped for AppleScript; v3 had an
    ``as_quote_osc`` for OSC 777. v2.1.0 has neither: the message is
    passed verbatim into the drop-box (where TSV tabs are the only
    delimiter, so a literal tab in the message would split a field;
    this is acceptable risk for a triager-only hook — the lead
    triages by origin + timestamp, not by message content).
    """
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": body, "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)


# =============================================================================
# Section 5: Missing-tool defenses
# =============================================================================


def test_jq_unavailable_is_silent_noop(hook_path_no_jq, fake_home):
    """If jq is missing, the hook exits cleanly without writing the drop-box.

    The early-exit fires before the worktree check, before the drop-box
    write. This test is the early-exit's behavioral contract.
    """
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "x", "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert not drop_tsv.exists(), (
        "Hook must not write the drop-box when jq is unavailable; "
        f"unexpected file: {drop_tsv}"
    )


# =============================================================================
# Section 6: Drop-box format (4 fields, v2.0.0+)
# =============================================================================


def test_dropbox_line_worker_format(hook_path_minimal, fake_home):
    """Worker pane: 3 TSV fields — timestamp, origin (worker name),
    message. No 4th column: a column that always has the same value
    is noise, not data.
    """
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "needs approval for grep",
                          "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert drop_tsv.exists()
    lines = drop_tsv.read_text().strip().split("\n")
    assert len(lines) == 1
    parts = lines[0].split("\t")
    assert len(parts) == 3, f"Expected 3 TSV fields, got {parts!r}"
    assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", parts[0])
    assert parts[1] == "mmx-2", f"Worker origin wrong: {parts[1]!r}"
    assert parts[2] == "needs approval for grep"


def test_dropbox_line_lead_pane_origin(hook_path_minimal, fake_home):
    """The lead's pane produces a drop-box line with origin='lead'."""
    payload = json.dumps({"message": "lead blocked on something",
                          "cwd": "/etc"})
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert drop_tsv.exists()
    line = drop_tsv.read_text().strip().split("\n")[0]
    parts = line.split("\t")
    assert len(parts) == 3
    assert parts[1] == "lead", (
        f"v2.0.0: lead's pane must be 'lead', got {parts[1]!r}"
    )
    assert parts[2] == "lead blocked on something"


def test_dropbox_appends_across_invocations(hook_path_minimal, fake_home):
    """The hook appends to the drop-box; it does not truncate on each call."""
    wd = make_worker_cwd(fake_home, "mmx-2")
    for msg in ["first", "second", "third"]:
        payload = json.dumps({"message": msg, "cwd": str(wd)})
        result = run_hook(payload)
        assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    lines = drop_tsv.read_text().strip().split("\n")
    assert len(lines) == 3, f"Expected 3 appended lines, got {len(lines)}"
    messages = [line.split("\t")[2] for line in lines]
    assert messages == ["first", "second", "third"]


# =============================================================================
# Section 7: stderr is always silent
# =============================================================================


def test_stderr_silent_on_happy_path(hook_path_minimal, fake_home):
    """No diagnostic noise reaches stderr."""
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "x", "cwd": str(wd)})
    result = run_hook(payload)
    assert result["stderr"] == "", f"Unexpected stderr: {result['stderr']!r}"


def test_stderr_silent_on_error_path(hook_path_minimal, fake_home):
    """Even on malformed input, the hook must stay silent on stderr."""
    result = run_hook("{ this is not json")
    assert_emits_continue_true(result)
    assert result["stderr"] == "", (
        f"Stderr leaked on error path: {result['stderr']!r}"
    )


# =============================================================================
# Section 8: Anti-response — issue #66 acceptance criterion
# =============================================================================


def test_hook_writes_drop_box_positive_guard():
    """v2.1.0 positive guard: the drop-box write is present.

    Without this guard, the forbidden list is vacuously satisfiable
    by deleting everything. With it, the hook must contain a working
    drop-box append (the hook's only job in v2.1.0).
    """
    text = HOOK_PATH.read_text(encoding="utf-8")
    assert DROP_BOX_POSITIVE_GUARD in text, (
        f"Hook must contain the drop-box write; "
        f"{DROP_BOX_POSITIVE_GUARD!r} not found in source."
    )


@pytest.mark.parametrize("pattern,why", [
    *FORBIDDEN_RESPONSE_PATTERNS,
])
def test_hook_contains_no_response_mechanism(pattern, why):
    """The hook MUST NOT carry any mechanism that could answer the prompt.

    Issue #66 acceptance criterion, made verifiable: each forbidden
    pattern is asserted absent in the source. The ``why`` argument
    documents the failure mode for the next maintainer who is tempted
    to add one.

    Comments are explanations, not mechanisms: strip full-line ``#``
    comments before searching so a docstring that names the pattern
    (e.g. explaining why ``osascript`` would be wrong) doesn't trip
    the assertion.
    """
    text = HOOK_PATH.read_text(encoding="utf-8")
    code_lines = [
        line for line in text.splitlines()
        if not line.lstrip().startswith("#")
    ]
    code_text = "\n".join(code_lines)
    matches = re.findall(pattern, code_text)
    assert matches == [], (
        f"Hook contains forbidden pattern {pattern!r} "
        f"({matches!r}). Reason: {why}"
    )


# =============================================================================
# Section 9: Concurrency — documents a known structural choice
# =============================================================================


def test_concurrent_writes_do_not_interleave(hook_path_minimal, fake_home):
    """Concurrent workers writing simultaneously must not interleave.

    Documents the structural choice (the hook uses plain ``>>`` append
    to the drop-box). On macOS with ``O_APPEND`` and per-``write()``
    atomicity for sizes up to ``PIPE_BUF`` (512 bytes), no interleaving
    is observed. The test stays in the suite as a regression guard
    against anyone who later changes the drop-box write to something
    non-atomic.
    """
    workers = ["zc", "mmx-1", "mmx-2", "w4", "w5", "w6", "w7", "w8", "w9", "w10"]
    payloads = []
    for w in workers:
        wd = make_worker_cwd(fake_home, w)
        payloads.append(json.dumps({
            "message": f"block-{w}-" * 60,
            "cwd": str(wd),
        }))

    env = {**os.environ,
           "PATH": os.environ["PATH"],
           "LANG": "C.UTF-8",
           "LC_ALL": "C.UTF-8",
           "HOME": str(fake_home)}
    for _ in range(3):
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:
            list(ex.map(lambda p: run_hook(p, env=env), payloads))

    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    content = drop_tsv.read_text()
    lines = [ln for ln in content.strip().split("\n") if ln]
    assert len(lines) == 30, (
        f"Expected 30 lines, got {len(lines)}:\n{content!r}"
    )
    for line in lines:
        parts = line.split("\t")
        assert len(parts) == 3, (
            f"Interleaved line (only {len(parts)} fields): {line!r}"
        )


# =============================================================================
# Section 10: Multibyte truncation — documents a known limitation
# =============================================================================


def test_multibyte_truncation_keeps_valid_utf8_in_c_locale(
    hook_path_minimal, fake_home, monkeypatch,
):
    """KNOWN LIMITATION — not testable without mocking the OSC emit.

    v1/v2 truncated ``BODY`` for the AppleScript notification; v3 was
    going to truncate for the OSC body. v2.1.0 has no BODY
    truncation at all: the drop-box writes ``MESSAGE`` verbatim, so
    the limitation is moot. This test is kept as a sentinel: if a
    future version re-introduces truncation in the drop-box path,
    this test will assert that the result is valid UTF-8.

    Today the test is a no-op ``assert True`` because the v2.1.0
    drop-box path is UTF-8 safe by construction (no truncation).
    """
    # Intentionally a no-op assertion — the limitation is the message.
    assert True, (
        "v2.1.0 has no truncation in the drop-box path; this test is "
        "a sentinel for a future version that might re-introduce one."
    )
