"""Regression tests for repo-boundary-guard.sh v2.99.0 (T23, issue #61).

One test per defect uncovered by the SECURITY_BASELINE fixture work. The
semantics that make these tests valid (manifest property): the boundary is
GITHUB_DIR-scoped BY DESIGN — paths outside ~/Documents/GitHub are allowed
on purpose, so every deny fixture targets a path under an isolated
GITHUB_DIR (HOME override on a PHYSICALLY resolved temp dir — macOS symlinks
/tmp and /var, and a non-physical path silently fails the prefix match).
"""
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
GUARD = REPO / ".claude" / "hooks" / "repo-boundary-guard.sh"


def _tmpdir_physical():
    """mktemp dir resolved through symlinks (what pwd -P gives in shell)."""
    return Path(os.path.realpath(tempfile.mkdtemp()))


def run_boundary(home, file_path):
    payload = json.dumps({"tool_name": "Edit",
                          "tool_input": {"file_path": str(file_path)}})
    env = dict(os.environ)
    env["HOME"] = str(home)
    return subprocess.run(
        ["bash", str(GUARD)],
        input=payload, capture_output=True, text=True,
        env=env, cwd=str(REPO), timeout=30,
    )


def decision_of(result):
    return json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"]


def test_defect1_sentinel_is_consulted_and_denies(tmp_path):
    # Defect 1 (#61): __CANONICALIZE_FAILED__ was emitted and never compared —
    # log said "denying as precaution", verdict was ALLOW. Deterministic
    # trigger: a realpath stub that always fails, prepended to PATH (the guard
    # calls realpath only inside canonicalize, so nothing else is affected).
    # Note: exotic paths (symlink loops) no longer reach the sentinel — the
    # v2.99.0 ancestor walk reconstructs them textually — which is why the
    # stub is the honest way to exercise the sentinel contract.
    d = _tmpdir_physical()
    stub_dir = d / "bin"
    stub_dir.mkdir()
    stub = stub_dir / "realpath"
    stub.write_text("#!/bin/sh\nexit 1\n")
    stub.chmod(0o755)
    payload = json.dumps({"tool_name": "Edit",
                          "tool_input": {"file_path": str(d / "x" / "y.md")}})
    env = dict(os.environ)
    env["HOME"] = str(d)
    env["PATH"] = f"{stub_dir}:{env['PATH']}"
    result = subprocess.run(
        ["bash", str(GUARD)],
        input=payload, capture_output=True, text=True,
        env=env, cwd=str(REPO), timeout=30,
    )
    assert decision_of(result) == "deny", (
        "a path canonicalize cannot resolve must deny, not flow into "
        "'Allow other paths'"
    )


def test_defect2_multilevel_missing_path_resolves_and_denies(tmp_path):
    # Defect 2 (#61): both `realpath -m` branches were dead on macOS
    # ("illegal option -- m"), and the single dirname+basename fallback could
    # not resolve multi-level misses — the path fell to the sentinel and
    # ALLOWED. The portable ancestor walk now resolves it, and being under
    # GITHUB_DIR (isolated HOME) it denies as another repo path.
    d = _tmpdir_physical()
    target = d / "Documents" / "GitHub" / "a" / "b" / "c" / "x.md"
    result = run_boundary(d, target)
    assert decision_of(result) == "deny"


def test_defect3_symlinked_home_github_dir_denies(tmp_path):
    # Defect 3 (#61): GITHUB_DIR was built from raw $HOME while paths were
    # canonicalized — through a symlinked HOME the other-repo branch silently
    # failed to match. With GITHUB_DIR canonicalized, a symlinked HOME still
    # denies a path under it (resolved through the symlink).
    d = _tmpdir_physical()
    (d / "real" / "Documents" / "GitHub").mkdir(parents=True)
    os.symlink(d / "real", d / "ln")
    target = d / "ln" / "Documents" / "GitHub" / "fr" / "x.md"
    result = run_boundary(d / "ln", target)
    assert decision_of(result) == "deny"


def test_ephemeral_sibling_repo_still_denies(tmp_path):
    # The canonical positive-deny (manifest fixture semantics): another git
    # repo under an isolated GITHUB_DIR.
    d = _tmpdir_physical()
    fr = d / "Documents" / "GitHub" / "fr"
    fr.mkdir(parents=True)
    subprocess.run(["git", "-C", str(fr), "init", "-q"], check=True)
    result = run_boundary(d, fr / "x.md")
    assert decision_of(result) == "deny"
    assert "REPO BOUNDARY" in result.stdout


def test_in_repo_edit_still_allows():
    # No over-blocking: a legitimate in-repo Edit with the real HOME allows.
    result = run_boundary(Path.home(), REPO / "CLAUDE.md")
    assert decision_of(result) == "allow"


# --- T28 (#63): free-text flag payloads are not paths ---
# The extractor's "quoted path with spaces" alternation matched the payload
# of `git commit -m "<prose>"` as a path — and while the sentinel fail-open
# existed, every long-quoted command was silently immune to the whole
# mentioned-paths check. Payloads of -m/--message/--reedit-message/--author
# are now blanked from the scan; -F values, -C values and -c code stay
# scanned. Both directions tested.

def run_boundary_bash(home, command):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    env = dict(os.environ)
    env["HOME"] = str(home)
    return subprocess.run(
        ["bash", str(GUARD)],
        input=payload, capture_output=True, text=True,
        env=env, cwd=str(REPO), timeout=30,
    )


@pytest.fixture
def external_repo_dir():
    d = _tmpdir_physical()
    fr = d / "Documents" / "GitHub" / "fr"
    fr.mkdir(parents=True)
    subprocess.run(["git", "-C", str(fr), "init", "-q"], check=True)
    return d, fr


def test_t28_long_quoted_commit_message_allows(external_repo_dir):
    d, fr = external_repo_dir
    cmd = f'git commit -m "fix: align docs at {fr}/x.md with tests (prose, not a path)"'
    result = run_boundary_bash(d, cmd)
    assert decision_of(result) == "allow"


@pytest.mark.parametrize("cmd_builder", [
    lambda fr: f'git commit --message "touching {fr}/x.md in prose only"',
    lambda fr: f"git commit -m'{fr}/x.md in prose'",
    lambda fr: f'git commit --author="a <dev>; see {fr}/x.md" -m t',
    lambda fr: f'git commit --reedit-message={fr}/x.md',
    lambda fr: f'git commit -m {fr}/x.md',
], ids=["--message-quoted", "-m-attached", "--author", "--reedit-message=", "-m-bare"])
def test_t28_freetext_variants_allow(external_repo_dir, cmd_builder):
    d, fr = external_repo_dir
    result = run_boundary_bash(d, cmd_builder(fr))
    assert decision_of(result) == "allow"


def test_t28_real_quoted_path_still_denies(external_repo_dir):
    d, fr = external_repo_dir
    result = run_boundary_bash(d, f'cp a.txt "{fr}/x.md"')
    assert decision_of(result) == "deny"


def test_t28_f_value_is_still_a_path(external_repo_dir):
    d, fr = external_repo_dir
    result = run_boundary_bash(d, f'git commit -F "{fr}/msg.txt"')
    assert decision_of(result) == "deny"


def test_t28_git_dash_c_value_is_still_a_path(external_repo_dir):
    # `git -C <dir>` is a directory flag: blanking -c/-C payloads would
    # blind exactly this. Must keep denying. (Historically used a
    # SUBDIRECTORY because the pre-T29 mention gate required one level
    # INSIDE the external repo — the root gap it left, closed in T29/#65,
    # has its own tests below.)
    d, fr = external_repo_dir
    sub = fr / "pkg"
    sub.mkdir()
    result = run_boundary_bash(d, f'git -C "{sub}" commit -m x')
    assert decision_of(result) == "deny"


def test_t28_python_dash_c_code_still_scanned(external_repo_dir):
    d, fr = external_repo_dir
    result = run_boundary_bash(d, f"python3 -c \"open('{fr}/x.md')\"")
    assert decision_of(result) == "deny"


# --- T29 (#65): the sibling-repo ROOT must trigger the mention check ---
# The mention gate required GITHUB_DIR/<repo>/ — one level INSIDE the
# external repo — so `git -C <sibling-root> ...` never reached extraction
# and was immune to the whole check. The gate now fires on the root. The
# second test pins the fix to the component-boundary shape: a directory
# merely NAMED LIKE a sibling (`<fr>-evil`) must be extracted and evaluated
# as the whole component — collapsing it into `<fr>` would trade the gap
# for the prefix collision (repo vs repo-evil) the gate shape exists to
# prevent. The exact-equality assert on the deny reason is what tells the
# two apart: a collapse would name `<fr>`, not `<fr>-evil`.

def test_t29_sibling_repo_root_git_dash_c_denies(external_repo_dir):
    d, fr = external_repo_dir
    result = run_boundary_bash(d, f'git -C "{fr}" commit -m x')
    assert decision_of(result) == "deny"


def test_t29_prefix_named_dir_evaluated_whole_not_collapsed(external_repo_dir):
    d, fr = external_repo_dir
    evil = fr.parent / f"{fr.name}-evil"
    evil.mkdir()
    subprocess.run(["git", "-C", str(evil), "init", "-q"], check=True)
    result = run_boundary_bash(d, f'git -C "{evil}" commit -m x')
    assert decision_of(result) == "deny"
    reason = json.loads(result.stdout)["hookSpecificOutput"]["permissionDecisionReason"]
    m = re.search(r"external repository \(([^)]+)\)\. Use", reason)
    assert m, f"deny reason does not name the evaluated path: {reason!r}"
    assert m.group(1) == str(evil), (
        f"expected the WHOLE component {evil} to be evaluated, got {m.group(1)}"
    )


# --- T37 (#66): a Bash COMMAND is not a path ---
# The lead's exact blocked command (verbatim, from the guard's own log at
# 20:46:04): `gh issue close 64 --comment` with multiline prose. extract_paths
# returned .command, so the ENTIRE command went through is_allowed_path as if
# it were one path; canonicalize's ancestor walk died on the multiline string
# (dirname is line-oriented and returned nothing), the sentinel fired, and the
# #61 rule (sentinel denies) blocked it as "Path <the entire command>".
# Issue #65 passed the same shape because ITS prose canonicalized back under
# the CWD — the boundary depended on the prose content, not the command.

def test_t37_gh_comment_multiline_prose_allows(external_repo_dir):
    d, fr = external_repo_dir
    cmd = '''gh issue close 64 --comment "Cerrado por tres tareas, porque el agujero tenía dos ramas y una víctima concreta.

**T30** (`1598484`, main `80c4e4c`) — rama bats del runner. bats sale 0 cuando no hay líneas `not ok`, incluido el caso en que TODOS los tests son `# skip`. El guard parsea el plan TAP y falla con `ZERO ASSERTIONS` cuando `assertions_run <= 0` aunque bats salga 0. `test_quality_gates.bats` archivado en `tests/archive/v2-suite/`. Verificado con TAP sintético, 6 casos: todo-skip → ZERO ASSERTIONS; plan vacío → ZERO ASSERTIONS; sin plan → ZERO ASSERTIONS; 2 reales + 1 skip → PASSED(2); 3 reales → PASSED; fallo real → FAILED.

**T34** (`c47bc5a`) — rama shell, que seguía abierta y tenía una víctima viva. La Suite 12 (`test-e2e.sh`) imprimía `Skipping hook execution tests...`, reportaba 0 passed / 0 failed y el runner la contaba como ✓. La ruta shell decidía solo por exit code. El guard nuevo captura la salida y exige un indicador de aserción; se catalogaron los 8 formatos distintos de las 26 suites ANTES de escribir el parser (la primera regex extrajo `897448` de un SHA — cazado por la encuesta, no por main).

**T34b** (`ed1d22a`, main `c809165`) — la corrección del veredicto. `promptify-auto-detect.sh` no estaba retirado: se había **consolidado** en `command-router.sh` (`run_promptify_auto_detect()` en la línea 377, invocado en la 434). Retirar la Suite 12 habría borrado cobertura de código que corre hoy en cada prompt. La suite se repunta a la función viva, con 7 aserciones.

Suite completa: 31/31, exit 0." 2>&1 | tail -2'''
    result = run_boundary_bash(d, cmd)
    assert decision_of(result) == "allow", (
        "a Bash command must never be evaluated as a path — the mention gate "
        "owns Bash; canonicalize dying on multiline prose denied this as "
        "'Path <the entire command>'"
    )


def test_t37_comment_with_real_external_path_still_denies(external_repo_dir):
    # The fresh violation the fix must NOT blind: a REAL external repo path
    # inside --comment prose still trips the mention gate (which since T29
    # covers the sibling root too). Blinding the payload would trade a false
    # positive for a hole; this pins that the fix removed the command-as-path
    # branch without widening any other.
    d, fr = external_repo_dir
    result = run_boundary_bash(d, f'gh issue close 64 --comment "repro: ver {fr}/src/foo.sh del vecino"')
    assert decision_of(result) == "deny"
