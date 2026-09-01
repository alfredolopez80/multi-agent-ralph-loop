"""PR9 C5 (#69 Slice E) — absence assertions for the compaction shadowing.

Born green: the deletion is sealed by a test that fails loudly if any of the
removed mechanisms comes back or leaves a live reference behind. Subjects
removed by commits C1-C4 of PR9-EXEC:

  C1: inject-session-context.sh (PreToolUse Agent|Task, S4),
      context-warning.sh (UserPromptSubmit, S5)
  C2: pre-compact-handoff.sh (PreCompact writer, S1),
      post-compact-restore.sh (SessionStart:compact reader, S2)
  C3: session-start-repo-summary.sh (SessionStart reinjection, S6)
  C4: the survivor session-start-restore-context.sh REDUCED (VAULT_HINTS
      stripped) + the post-compact resume proof (source=compact) in the C1 probe

Explicitly allowed references (NOT asserted absent): scripts/ralph compact and
install blocks (outside PR9's allowed paths, flagged PR11 residue),
scripts/benchmark/hotpath_probe.py rows (historical snapshot, PR11), absence
suites themselves (an absence test must name its subjects to assert their
absence), and comment prose documenting the removal (comments are not reads).
"""

import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
HOOKS = REPO / ".claude" / "hooks"
EXAMPLE = REPO / ".claude" / "settings.json.example"
PROBE = REPO / "tests" / "hooks" / "test_session_c1_resume_probe.sh"
SURVIVOR = HOOKS / "session-start-restore-context.sh"

REMOVED_HOOKS = [
    # C1
    "inject-session-context.sh",
    "context-warning.sh",
    # C2
    "pre-compact-handoff.sh",
    "post-compact-restore.sh",
    # C3
    "session-start-repo-summary.sh",
]

VAULT_MARKERS = (
    "MiVault",
    "migrated-from-claude-mem",
    "global/wiki",
    "get_vault_hints",
    "VAULT_HINTS",
)


def _non_comment_lines(path):
    for line in path.read_text(errors="ignore").splitlines():
        if not line.lstrip().startswith("#"):
            yield line


def test_removed_hook_files_are_gone():
    """(F13.1) None of the five removed files exists under .claude/hooks/."""
    assert len(REMOVED_HOOKS) == 5
    present = [n for n in REMOVED_HOOKS if (HOOKS / n).exists()]
    assert present == [], f"removed compaction-shadow hooks reappeared: {present}"


def test_example_registers_none_of_the_removed_hooks():
    """(F13.2) settings.json.example carries none of the removed names."""
    content = EXAMPLE.read_text()
    registered = [n for n in REMOVED_HOOKS if n in content]
    assert registered == [], (
        f"settings.json.example still registers removed hooks: {registered}"
    )


def test_survivor_has_no_vault_reads():
    """(F13.3) The reduced survivor has no MiVault reads in executable lines.
    Comment prose documenting the Slice E reduction itself is allowed; any
    non-comment line naming the vault sources is a live read of a mechanism
    Slice E removed."""
    offenders = [
        line.strip()[:90]
        for line in _non_comment_lines(SURVIVOR)
        if any(marker in line for marker in VAULT_MARKERS)
    ]
    assert offenders == [], (
        f"survivor still reads the vault (Slice E reduction regressed): {offenders}"
    )


def test_c1_probe_covers_post_compact_resume():
    """(F13.4) The resume proof is BOTH boundaries: the C1 probe must carry
    the post-compact variant (a SessionStart payload with source=compact).
    Fresh cases alone do not satisfy the Slice E done-when."""
    content = PROBE.read_text()
    assert '"source":"%s"' in content, (
        "C1 probe no longer builds a source= payload — post-compact proof lost"
    )
    assert "Post-compact" in content, (
        "C1 probe lost the post-compact case section"
    )


def test_no_hook_sources_a_removed_sibling():
    """No surviving hook EXECUTES a removed basename on a non-comment line.
    Comment prose documenting the removal itself is allowed."""
    offenders = []
    for hook in HOOKS.iterdir():
        if not hook.is_file():
            continue
        for line in _non_comment_lines(hook):
            for name in REMOVED_HOOKS:
                if name in line:
                    offenders.append(f"{hook.name}: {line.strip()[:90]}")
    assert offenders == [], (
        f"surviving hooks still execute removed compaction-shadow hooks: {offenders}"
    )


def _py_docstring_lines(path):
    """Line numbers that belong to docstrings (ast-detected, not heuristic)."""
    import ast

    lines = set()
    try:
        tree = ast.parse(path.read_text(errors="ignore"))
    except (SyntaxError, ValueError):
        return lines
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef,
                             ast.AsyncFunctionDef, ast.ClassDef)):
            body = node.body
            if (body and isinstance(body[0], ast.Expr)
                    and isinstance(body[0].value, ast.Constant)
                    and isinstance(body[0].value.value, str)):
                start = body[0].lineno
                end = body[0].end_lineno or start
                lines.update(range(start, end + 1))
    return lines


def test_no_test_asserts_removed_hook_behavior():
    """(F13.5) The two C1 hooks (the plan's scope for this assertion) are
    absent from every tests/ reference that asserted their behavior: no
    executable line in tests/ names them. Removal-note docstrings are allowed
    (ast-detected: they document the deletion, they do not exercise it), as
    are the absence suites themselves — naming the subject IS the assertion
    there. S1/S2/S6 references are sealed by F13.1/F13.2 and the hooks-dir
    scan: any behavior test would need the file to exist."""
    import ast

    c1_hooks = ("inject-session-context.sh", "context-warning.sh")
    excluded = ("test_pr9_shadowing_absence.py", "test-pr9-shadowing-absence.sh")
    offenders = []

    for path in (REPO / "tests").rglob("*.py"):
        if path.name in excluded:
            continue
        doc_lines = _py_docstring_lines(path)
        for lineno, line in enumerate(path.read_text(errors="ignore").splitlines(), 1):
            if lineno in doc_lines or line.lstrip().startswith("#"):
                continue
            for name in c1_hooks:
                if name in line:
                    offenders.append(
                        f"{path.relative_to(REPO)}:{lineno}: {line.strip()[:80]}"
                    )
    for pattern in ("*.sh", "*.bats", "*.json"):
        for path in (REPO / "tests").rglob(pattern):
            if path.name in excluded:
                continue
            for lineno, line in enumerate(path.read_text(errors="ignore").splitlines(), 1):
                if line.lstrip().startswith("#"):
                    continue
                for name in c1_hooks:
                    if name in line:
                        offenders.append(
                            f"{path.relative_to(REPO)}:{lineno}: {line.strip()[:80]}"
                        )
    assert offenders == [], (
        f"tests still reference the removed C1 hooks on executable lines: {offenders}"
    )


def test_survivor_still_emits_valid_sessionstart_json():
    """The reduced survivor must still work end to end: a SessionStart run
    against an empty sandbox emits valid additionalContext and none of the
    removed vault-hint text. Absence assertions prove nothing if the pruning
    broke the survivor."""
    import json
    import tempfile

    with tempfile.TemporaryDirectory(prefix="pr9-absence-") as tmp:
        proc = subprocess.run(
            ["bash", str(SURVIVOR)],
            input='{"hook_event_name": "SessionStart", "source": "startup", "session_id": "pr9-absence"}',
            capture_output=True, text=True, timeout=30, cwd=tmp,
            env={"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": tmp},
        )
    assert proc.returncode == 0, (
        f"reduced survivor exited {proc.returncode}: {proc.stderr[:200]}"
    )
    payload = json.loads(proc.stdout)
    ctx = payload["hookSpecificOutput"]["additionalContext"]
    assert ctx, "survivor produced empty additionalContext"
    for marker in VAULT_MARKERS[:3]:
        assert marker not in ctx, (
            f"survivor context contains {marker!r} — vault injection came back"
        )
