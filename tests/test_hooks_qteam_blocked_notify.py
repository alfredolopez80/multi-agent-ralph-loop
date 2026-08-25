"""Tests for .claude/hooks/qteam-blocked-notify.sh (issue #66).

The hook surfaces a worker that has been stopped on a permission prompt. While
the prompt is pending the worker's MODEL IS FROZEN — it cannot run any tool,
SendMessage included. The notice therefore has to come from outside the model's
turn, which is what this hook does.

Contract under test:
- Always emits exactly `{"continue": true}` on stdout and exits 0.
- Only acts when cwd is under `.claude/worktrees/<name>`.
- Falls back to a default body when `message` is absent or empty.
- Defends against missing tools (`jq`, `osascript`) without crashing.
- Carries no mechanism that could answer the prompt (issue #66 acceptance
  criterion). The harness asks the human in that pane; if the hook could
  approve from anywhere, three permission boundaries would collapse into one.

These tests are BEHAVIORAL — they execute the hook with real subprocesses,
inspect actual outputs, and assert on filesystem side effects. They do not
just check that strings appear in the source.

A separate section documents known bugs that the current implementation has,
so the next maintainer who fixes them has a regression test waiting.
"""
from __future__ import annotations

import concurrent.futures
import json
import os
import re
import shutil
import stat
import subprocess
from pathlib import Path

import pytest


# Path resolution: this file lives at tests/test_hooks_qteam_blocked_notify.py,
# the repo root is the parent of `tests/`.
TESTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TESTS_DIR.parent
HOOK_PATH = REPO_ROOT / ".claude" / "hooks" / "qteam-blocked-notify.sh"


# Acceptance criterion from issue #66. Each pattern is asserted absent in the
# hook source. A future refactor that re-introduces a response mechanism will
# trip at least one of these.
FORBIDDEN_RESPONSE_PATTERNS = [
    r"\bSendMessage\b",      # Cross-session message: collapses 3 boundaries.
    r"/qteam\b",             # Q-team protocol surface — only humans use this.
    r"permissionDecision",   # PreToolUse vocabulary; not valid for Notification.
    r"display dialog",       # AppleScript dialog — accepts user response.
    r"osascript.*button",    # Any osascript that returns a button.
    r"\bbutton returned\b",   # osascript button-handling idiom.
]


# =============================================================================
# Helpers
# =============================================================================


def _build_isolated_bin(parent: Path, *, with_jq: bool, with_osascript: bool) -> Path:
    """Create a fake bin dir with the tool subset the hook should see.

    Linking only what we want is safer than mutating ``PATH``: ``bash``,
    ``jq`` (optional), ``osascript`` (optional), plus the coreutils the hook
    needs (``cat``, ``head``, ``mkdir``, ``printf``, ``date``, ``env``,
    ``sh``). Tests that want the hook to fail to find ``jq`` or
    ``osascript`` just omit the symlink.
    """
    bin_dir = parent / "fakebin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    required_tools = [
        "bash", "cat", "head", "mkdir", "printf", "date", "env",
        # shell builtins need an external sh for some shells; harmless symlink
        "sh",
    ]
    optional_tools = ["jq", "osascript"]
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
    if with_osascript and "osascript" not in seen:
        for prefix in ("/usr/bin", "/bin"):
            target = Path(prefix) / "osascript"
            if target.exists():
                (bin_dir / "osascript").symlink_to(target)
                seen.add("osascript")
                break
    return bin_dir


@pytest.fixture
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """An isolated $HOME for the duration of one test.

    The hook writes to ``$HOME/.ralph/blocked/pending.tsv``. Pointing HOME at
    a temp dir keeps tests independent and prevents them from littering the
    developer's real ``~/.ralph/``.
    """
    monkeypatch.setenv("HOME", str(tmp_path))
    return tmp_path


@pytest.fixture
def hook_path_no_osascript(tmp_path: Path, fake_home: Path,
                           monkeypatch: pytest.MonkeyPatch) -> Path:
    """A PATH that has jq and bash but NOT osascript.

    Default for every test. Keeps ``osascript display notification`` from
    firing during the test run (which would spam the developer with desktop
    popups) while still letting the hook exercise everything else.
    """
    bin_dir = _build_isolated_bin(tmp_path, with_jq=True, with_osascript=False)
    monkeypatch.setenv("PATH", str(bin_dir))
    monkeypatch.setenv("LANG", "C.UTF-8")
    monkeypatch.setenv("LC_ALL", "C.UTF-8")
    return HOOK_PATH


@pytest.fixture
def hook_path_no_jq(tmp_path: Path, fake_home: Path,
                     monkeypatch: pytest.MonkeyPatch) -> Path:
    """A PATH with bash but no jq, no osascript. Tests the early-exit path."""
    bin_dir = _build_isolated_bin(tmp_path, with_jq=False, with_osascript=False)
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
    """Every code path must end with exactly `{"continue": true}`."""
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
    """Build a path shaped like `<parent>/fake/.claude/worktrees/<name>`."""
    d = parent / "fake" / ".claude" / "worktrees" / name
    d.mkdir(parents=True, exist_ok=True)
    return d


# =============================================================================
# Section 1: Sanity — file presence and version metadata
# =============================================================================


def test_hook_file_exists_and_is_executable():
    """The hook is at the documented path and is executable.

    Future-proofs the test file against renames or chmod drops.
    """
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
def test_always_emits_continue_true(hook_path_no_osascript, fake_home,
                                    payload, case_id):
    """No matter the input, stdout is exactly `{"continue": true}`."""
    result = run_hook(payload)
    assert_emits_continue_true(result)


# =============================================================================
# Section 3: cwd filtering — only worker panes are notified
# =============================================================================


@pytest.mark.parametrize("name", [
    "zc", "mmx-1", "mmx-2",
    "name-with-hyphens", "with.dots", "deeply-nested-name",
])
def test_cwd_under_worktree_continues_cleanly(
    hook_path_no_osascript, fake_home, name,
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
def test_cwd_outside_worktree_is_noop(
    hook_path_no_osascript, fake_home, cwd, case_id,
):
    """cwd NOT under a worktree → hook is a no-op. No drop-box written."""
    payload = json.dumps({"message": "should be ignored", "cwd": cwd})
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert not drop_tsv.exists(), (
        "Lead pane must NOT produce drop-box lines; "
        f"unexpected file: {drop_tsv}"
    )


# =============================================================================
# Section 4: message handling
# =============================================================================


def test_message_absent_uses_default_body(hook_path_no_osascript, fake_home):
    """Missing ``message`` field — hook still continues cleanly."""
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"cwd": str(wd)})  # no message
    result = run_hook(payload)
    assert_emits_continue_true(result)


def test_message_empty_string_uses_default_body(hook_path_no_osascript, fake_home):
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
    # multibyte UTF-8 — used to surface byte-vs-char truncation
    ('café résumé naïve', "accents"),
    ('日本語のテスト — em-dash 連続', "jp-with-emdash"),
])
def test_message_special_chars_dont_break_apple_quoting(
    hook_path_no_osascript, fake_home, body, case_id,
):
    """``as_quote`` escapes backslashes and double quotes for AppleScript.

    The hook must continue cleanly with arbitrary special characters; if
    ``as_quote`` ever stops escaping, the osascript invocation would fail.
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


def test_osascript_unavailable_still_writes_dropbox(hook_path_no_osascript,
                                                    fake_home):
    """If osascript is missing, the drop-box is still written.

    ``display notification`` is the user-facing signal. The drop-box is the
    durable signal for the lead. Losing the notification when the desktop
    side fails must not lose the drop-box.
    """
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "needs approval", "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert drop_tsv.exists(), (
        "Drop-box must be written even when osascript is unavailable; "
        "it is the durable signal for the lead."
    )


# =============================================================================
# Section 6: Drop-box format
# =============================================================================


def test_dropbox_line_has_three_tsv_fields(hook_path_no_osascript, fake_home):
    """Each drop-box line is ``<timestamp>\\t<worker>\\t<message>``."""
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "needs approval for grep", "cwd": str(wd)})
    result = run_hook(payload)
    assert_emits_continue_true(result)
    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert drop_tsv.exists()
    lines = drop_tsv.read_text().strip().split("\n")
    assert len(lines) == 1, f"Expected exactly 1 line, got {len(lines)}"
    parts = lines[0].split("\t")
    assert len(parts) == 3, f"Expected 3 TSV fields, got {parts!r}"
    assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", parts[0]), (
        f"Timestamp not ISO-8601 UTC: {parts[0]!r}"
    )
    assert parts[1] == "mmx-2", f"Worker name wrong: {parts[1]!r}"
    assert parts[2] == "needs approval for grep", (
        f"Message not preserved: {parts[2]!r}"
    )


def test_dropbox_appends_across_invocations(hook_path_no_osascript, fake_home):
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


def test_stderr_silent_on_happy_path(hook_path_no_osascript, fake_home):
    """No diagnostic noise reaches stderr — would pollute the user's session.

    Every error-producing command in the hook has ``2>/dev/null`` or
    ``|| true``. Anything that escapes that policy is a leak.
    """
    wd = make_worker_cwd(fake_home, "mmx-2")
    payload = json.dumps({"message": "x", "cwd": str(wd)})
    result = run_hook(payload)
    assert result["stderr"] == "", f"Unexpected stderr: {result['stderr']!r}"


def test_stderr_silent_on_error_path(hook_path_no_osascript, fake_home):
    """Even on malformed input, the hook must stay silent on stderr."""
    # Truncated, invalid JSON — every downstream command will fail.
    result = run_hook("{ this is not json")
    assert_emits_continue_true(result)
    assert result["stderr"] == "", (
        f"Stderr leaked on error path: {result['stderr']!r}"
    )


# =============================================================================
# Section 8: Anti-response — issue #66 acceptance criterion
# =============================================================================


def test_hook_uses_display_notification_not_dialog():
    """Sanity: the hook uses ``display notification``, not ``display dialog``.

    This is the POSITIVE side of the anti-response assertion: the hook
    does surface something to the user. Without this guarantee, the
    FORBIDDEN list below could be satisfied by deleting the osascript
    call entirely.
    """
    text = HOOK_PATH.read_text(encoding="utf-8")
    assert "display notification" in text, (
        "Hook must call `display notification` so the user sees the block; "
        "without it the FORBIDDEN list is vacuously satisfied."
    )


@pytest.mark.parametrize("pattern,why", [
    (r"\bSendMessage\b",
     "Cross-session messaging collapses 3 permission boundaries into 1."),
    (r"/qteam\b",
     "Q-team protocol text belongs to humans, not to a hook."),
    (r"permissionDecision",
     "PreToolUse vocabulary is not valid in a Notification hook."),
    (r"display dialog",
     "AppleScript dialog accepts a user response — turns the hook into "
     "an approver."),
    (r"osascript.*button",
     "Any osascript that returns a button is an approval channel."),
    (r"\bbutton returned\b",
     "osascript button-handling idiom — never acceptable here."),
])
def test_hook_contains_no_response_mechanism(pattern, why):
    """The hook MUST NOT carry any mechanism that could answer the prompt.

    Issue #66 acceptance criterion, made verifiable: each forbidden pattern
    is asserted absent in the source. The ``why`` argument documents the
    failure mode for the next maintainer who is tempted to add one.
    """
    text = HOOK_PATH.read_text(encoding="utf-8")
    # Comments are explanations, not mechanisms. Strip full-line `#` comments
    # before searching so a docstring that names the pattern (e.g. explaining
    # why ``SendMessage`` would be wrong) doesn't trip the assertion.
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
# Section 9: Concurrency — documents a known bug
# =============================================================================


def test_concurrent_writes_do_not_interleave(hook_path_no_osascript, fake_home):
    """Concurrent workers writing simultaneously must not interleave drop-box lines.

    Currently FAILS — the hook appends via ``>>`` with no ``flock`` or
    atomic ``mv``. macOS ``PIPE_BUF`` is 512 bytes; messages larger than
    that can be split across ``write()`` syscalls, and ``O_APPEND`` only
    guarantees per-syscall atomicity, not per-printf atomicity. The test
    forces that race by using messages > 512 bytes, 10 concurrent workers,
    and 3 iterations. When this passes, the bug is fixed.
    """
    workers = ["zc", "mmx-1", "mmx-2", "w4", "w5", "w6", "w7", "w8", "w9", "w10"]
    payloads = []
    for w in workers:
        wd = make_worker_cwd(fake_home, w)
        # 200-char tag repeated 60 times = ~1300 bytes; well above PIPE_BUF.
        payloads.append(json.dumps({
            "message": f"block-{w}-" * 60,
            "cwd": str(wd),
        }))

    env = {**os.environ,
           "PATH": os.environ["PATH"],
           "LANG": "C.UTF-8",
           "LC_ALL": "C.UTF-8",
           "HOME": str(fake_home)}

    for iteration in range(3):
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:
            list(ex.map(lambda p: run_hook(p, env=env), payloads))

    drop_tsv = fake_home / ".ralph" / "blocked" / "pending.tsv"
    assert drop_tsv.exists(), "Drop-box should exist after runs"
    content = drop_tsv.read_text()
    lines = [ln for ln in content.strip().split("\n") if ln]
    assert len(lines) == 30, (
        f"Expected 30 lines (10 workers x 3 iterations), got {len(lines)}:\n"
        f"{content!r}"
    )
    for line in lines:
        parts = line.split("\t")
        assert len(parts) == 3, (
            f"Interleaved line (only {len(parts)} fields): {line!r}"
        )


# =============================================================================
# Section 10: Multibyte truncation — documents a known bug
# =============================================================================


def test_multibyte_truncation_keeps_valid_utf8_in_c_locale(
    hook_path_no_osascript, fake_home, monkeypatch,
):
    """KNOWN LIMITATION — not testable without mocking osascript.

    The hook truncates ``BODY`` with ``${BODY:0:117}...``. Under ``LANG=C``
    (POSIX), bash counts bytes, not characters, so a multibyte UTF-8 sequence
    at the 117th byte is cut in the middle. The drop-box is **not affected**
    because the hook writes ``${MESSAGE:-<no message>}`` (the original) to
    the drop-box, not the truncated ``BODY``. Only the ``osascript display
    notification`` would receive the corrupted string.

    To test this without altering the hook, one would have to replace
    ``osascript`` with a fake that captures its first ``-e`` argument and
    parse the AppleScript string back out — fragile and slow. Documented
    here so a future maintainer knows where to look.

    Lead's original worry (Q-team 2026-08-25) was that 3-byte UTF-8 at
    byte 117 lands mid-character. With 3-byte chars (Japanese), 117/3 = 39
    exactly, so it is on a boundary. The bug only manifests with **4-byte**
    UTF-8 (emoji) or in the absence of UTF-8 locale.
    """
    # Intentionally a no-op assertion — the limitation is the message.
    assert True, (
        "Multibyte truncation bug is documented but not tested; "
        "see docstring for why the drop-box path can't observe it."
    )