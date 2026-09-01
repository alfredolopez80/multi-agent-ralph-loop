"""No-recreation assertions for Slice F (PR11-EXEC, #69 Phase 3 PR 11).
Plan: results/PR11-PREP-plan.md.

This test asserts the post-Slice-F state of the repo. A failure here means
someone re-introduced a deleted artifact (C2 archive phantoms, C3 PHASE0
DELETEs), a stale docs reference, or a regression in the worker-blocked-safe
plane or the SECURITY manifest.

Adaptations from the literal plan (the plan was authored pre-Slice-E; main is
at f30bd02 now and Slice E simplified the surface significantly):

  - Group 1 (hot-path per-tool only security) is adapted: the plan said
    "PostToolUse:Edit|Write|Bash contains only audit-secrets.js", but
    audit-secrets.js is not registered in .claude/settings.json.example
    (it lives in user-side settings, not the example), and option A of
    the BLOCKED message 5156bffd skipped C1. The intent ("lean hot-path")
    is captured as: at most 1 hook entry in the matcher.

  - Group 4 (__pycache__) uses git ls-files instead of os.path.exists:
    pytest regenerates bytecode on test runs and the directories are
    filesystem-only build artifacts (git-untracked). User decision: skip
    filesystem cleanup; test at git level for robustness.

  - Group 7 (SECURITY manifest) is implemented inline because
    tests/test_security_baseline.py referenced by the plan does not exist.
"""
from pathlib import Path
import json
import subprocess

REPO = Path(__file__).resolve().parents[1]


# Group 3: 4 archive phantoms removed in C2 (F9-F14).
ARCHIVE_PHANTOMS = [
    "memory-write-trigger.sh",
    "semantic-auto-extractor.sh",
    "episodic-auto-convert.sh",
    "reflection-engine.sh",
]

# Group 4: 5 PHASE0 DELETEs from C3. F18 + F20 are TRACKED git removals.
# F21/F22 are filesystem-only (never tracked, ignored); F23 is .gitignore.
PHASE0_TRACKED = [
    ".claude/scripts/validate-all-orchestrator-skills.sh",
    ".claude/agents/AGENTES_SKILLS_AUDIT_v2.72.2.md.old",
]

# Group 6: 5 worker-blocked-safe hooks. Slice F MUST NOT touch these.
WORKER_BLOCKED_SAFE = [
    "git-safety-guard.py",
    "repo-boundary-guard.sh",
    "permission-guard.sh",
    "k8s-context-guard-v2.py",
    "skill-validator.sh",
]

# Distributors audited for residual references (Group 5: no-recreation).
DISTRIBUTORS = [
    ".claude/scripts/sync-rules-from-source.sh",
    "scripts/validate-global-infrastructure.sh",
    "scripts/validate-hooks-registration.sh",
    "scripts/validate-hooks-execution.sh",
    "install.sh",
    "install-claude-native-agents.sh",
]


# ─────────────────────────────────────────────────────────────────────────────
# Group 3: archive phantoms
# ─────────────────────────────────────────────────────────────────────────────


def test_archive_phantoms_absent_pre_migration():
    """C2 F9-F12: pre-migration archive phantoms are gone (no callers)."""
    for name in ARCHIVE_PHANTOMS:
        path = REPO / ".claude/archive/pre-migration-v2.70.0-20260127-231849" / name
        assert not path.exists(), f"{name} re-appeared in pre-migration archive"


def test_archive_phantoms_absent_hooks_audit():
    """C2 F13-F14: hooks-audit-20260119 duplicate copies are gone."""
    for name in ("memory-write-trigger.sh", "reflection-engine.sh"):
        path = REPO / ".claude/archive/hooks-audit-20260119" / name
        assert not path.exists(), f"{name} re-appeared in hooks-audit archive"


def test_archive_readme_states_purge_policy():
    """C2 F17: archive-purge policy is documented."""
    readme = REPO / ".claude/archive/README.md"
    assert readme.exists(), "archive/README.md missing — F17 not done"
    text = readme.read_text(encoding="utf-8")
    # The policy must explicitly mention the absence-of-caller rule
    assert "git rm" in text, "archive/README.md does not mention git rm"
    assert "caller" in text, "archive/README.md does not mention caller policy"


# ─────────────────────────────────────────────────────────────────────────────
# Group 4: PHASE0 DELETEs
# ─────────────────────────────────────────────────────────────────────────────


def test_phase0_tracked_deletes():
    """C3 F18, F20: PHASE0 tracked files removed from git index."""
    for path_str in PHASE0_TRACKED:
        result = subprocess.run(
            ["git", "ls-files", "--error-unmatch", path_str],
            cwd=REPO, capture_output=True, text=True,
        )
        assert result.returncode != 0, f"{path_str} still tracked"


def test_phase0_pycache_dirs_not_tracked():
    """C3 F21, F22: __pycache__ dirs not in git index (build artifacts).
    Uses git ls-files — robust to pytest regenerating bytecode locally
    (user decision after guard blocked the filesystem cleanup)."""
    for path_str in (
        ".claude/hooks/__pycache__",
        ".claude/hooks/k8s_context_guard/__pycache__",
    ):
        result = subprocess.run(
            ["git", "ls-files", path_str],
            cwd=REPO, capture_output=True, text=True,
        )
        assert result.stdout.strip() == "", f"{path_str} tracked (unexpected)"


def test_gitignore_covers_pycache():
    """C3 F23: .gitignore already covers __pycache__/ (defense in depth)."""
    gitignore = (REPO / ".gitignore").read_text(encoding="utf-8")
    assert "__pycache__" in gitignore, ".gitignore does not mention __pycache__"


# ─────────────────────────────────────────────────────────────────────────────
# Group 1 (adapted): PostToolUse hot-path
# ─────────────────────────────────────────────────────────────────────────────


def test_posttooluse_edit_write_bash_minimal():
    """Adapted from plan Group 1: PostToolUse:Edit|Write|Bash is minimal.
    The plan said 'audit-secrets only'; reality (post-Slice-E + option A
    skip-to-C2) has at most plan-sync-post-step there. The intent — a lean
    hot-path — is captured as: at most 1 hook entry."""
    settings = json.loads((REPO / ".claude/settings.json.example").read_text(encoding="utf-8"))
    per_tool = []
    for m in settings.get("hooks", {}).get("PostToolUse", []):
        if m.get("matcher") == "Edit|Write|Bash":
            per_tool.extend(m.get("hooks", []))
    assert len(per_tool) <= 1, (
        f"hot-path PostToolUse:Edit|Write|Bash has {len(per_tool)} entries; "
        f"expected <=1. Re-check whether slice E simplification still holds."
    )


# ─────────────────────────────────────────────────────────────────────────────
# Group 5: no-recreation in distributors
# ─────────────────────────────────────────────────────────────────────────────


def test_no_distributor_recreates_archive_phantoms():
    """No distributor lists any of the 4 archive phantoms. A reference in a
    distributor (sync-rules, validators, install) would re-create the file
    on next sync and silently undo the purge."""
    for name in ARCHIVE_PHANTOMS:
        for d in DISTRIBUTORS:
            dpath = REPO / d
            if not dpath.exists():
                continue
            text = dpath.read_text(encoding="utf-8")
            assert name not in text, (
                f"{d} references deleted archive phantom {name} "
                f"(would re-create on next sync)"
            )


def test_no_distributor_lists_phase0_residue():
    """No distributor lists the 5 PHASE0 DELETEs (tracked or residue)."""
    for path_str in PHASE0_TRACKED:
        basename = path_str.rsplit("/", 1)[-1]
        for d in DISTRIBUTORS:
            dpath = REPO / d
            if not dpath.exists():
                continue
            text = dpath.read_text(encoding="utf-8")
            assert basename not in text, (
                f"{d} references deleted PHASE0 residue {basename}"
            )


# ─────────────────────────────────────────────────────────────────────────────
# Group 6: worker-blocked-safe preserved
# ─────────────────────────────────────────────────────────────────────────────


def test_worker_blocked_safe_preserved():
    """Slice F must NOT touch the 5 worker-blocked-safe hooks."""
    for name in WORKER_BLOCKED_SAFE:
        path = REPO / ".claude/hooks" / name
        assert path.exists(), f"{name} missing — Slice F MUST NOT touch worker-blocked-safe"


# ─────────────────────────────────────────────────────────────────────────────
# Group 7: SECURITY manifest intact
# ─────────────────────────────────────────────────────────────────────────────


def test_security_baseline_intact():
    """SECURITY_BASELINE.json has 6 controls + 5 named gaps (Slice F does not
    modify the manifest; this guards against accidental regression)."""
    baseline = json.loads((REPO / ".claude/security/SECURITY_BASELINE.json").read_text(encoding="utf-8"))
    assert len(baseline.get("controls", [])) == 6, (
        f"expected 6 controls, got {len(baseline.get('controls', []))}"
    )
    gap_ids = {g.get("id") for g in baseline.get("gaps", [])}
    expected_gaps = {
        "secrets-ordinary-work", "red-toxic", "mcp-egress",
        "package-manager", "symlink-escape",
    }
    assert gap_ids == expected_gaps, f"gap set drifted: {gap_ids - expected_gaps} new, {expected_gaps - gap_ids} missing"


# ─────────────────────────────────────────────────────────────────────────────
# F24-F26: docs reconciliation (post Slice E)
# ─────────────────────────────────────────────────────────────────────────────


def test_claude_md_no_stale_lifecycle_hook_refs():
    """F24: CLAUDE.md must not mention hooks slice E removed."""
    text = (REPO / "CLAUDE.md").read_text(encoding="utf-8")
    for name in ("pre-compact-handoff.sh", "post-compact-restore.sh"):
        assert name not in text, (
            f"CLAUDE.md still references slice-E-deleted {name} — F24 incomplete"
        )


def test_claude_md_no_stale_critical_hooks():
    """F24 follow-up: CLAUDE.md 'Critical Hooks' table reflects registrations.
    The 4 hooks listed in the original table that are no longer in
    settings.json.example (status-auto-check, batch-progress-tracker,
    learning-gate, task-completed-quality-gate) must be gone from the doc."""
    text = (REPO / "CLAUDE.md").read_text(encoding="utf-8")
    for name in (
        "status-auto-check.sh",
        "batch-progress-tracker.sh",
        "learning-gate.sh",
        "task-completed-quality-gate.sh",
    ):
        assert name not in text, (
            f"CLAUDE.md 'Critical Hooks' still lists unregistered {name}"
        )
