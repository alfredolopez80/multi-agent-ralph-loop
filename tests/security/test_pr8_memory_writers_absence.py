"""PR8 C5 (#69 Slice D) — absence assertions for the automatic memory writers.

Born green, same lesson as Slices A/B: the deletion is sealed by a test that
fails loudly if any of the removed mechanisms comes back or leaves a live
reference behind. Subjects removed by commits C1-C4 of PR8-EXEC:

  C1: vault-fact-extractor.sh, session-accumulator.sh        (PostToolUse inflow)
  C2: memory-projection.sh, vault-log-writer.sh              (SessionEnd writers)
  C3: vault-graduation.sh, vault-promotion.sh,
      vault-index-updater.sh, vault-wing-compiler.sh         (SessionStart pipeline)
  C4: decision-extractor.sh, semantic-realtime-extractor.sh,
      continuous-learning.sh, dream-consolidate.sh,
      vault-writeback.sh, session-end-extractors.sh          (unregistered + cold)

Explicit cold-path surfaces survive by design: the vault skill, dream.py,
learn_capture.py (flagged PR11 residue), /exit-review. They are NOT asserted
absent.
"""

import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
HOOKS = REPO / ".claude" / "hooks"
EXAMPLE = REPO / ".claude" / "settings.json.example"

REMOVED_HOOKS = [
    # C1
    "vault-fact-extractor.sh",
    "session-accumulator.sh",
    # C2
    "memory-projection.sh",
    "vault-log-writer.sh",
    # C3
    "vault-graduation.sh",
    "vault-promotion.sh",
    "vault-index-updater.sh",
    "vault-wing-compiler.sh",
    # C4
    "decision-extractor.sh",
    "semantic-realtime-extractor.sh",
    "continuous-learning.sh",
    "dream-consolidate.sh",
    "vault-writeback.sh",
    "session-end-extractors.sh",
]


def test_removed_hook_files_are_gone():
    """(F23.1) None of the 14 removed files exists under .claude/hooks/."""
    assert len(REMOVED_HOOKS) == 14
    present = [n for n in REMOVED_HOOKS if (HOOKS / n).exists()]
    assert present == [], f"removed memory-writer hooks reappeared: {present}"


def test_weekly_compile_script_is_gone():
    """(F23.3) Chain M's producer script is gone."""
    assert not (REPO / "scripts" / "vault-weekly-compile.sh").exists()


def test_example_registers_none_of_the_removed_hooks():
    """(F23.2) settings.json.example carries none of the removed names."""
    content = EXAMPLE.read_text()
    registered = [n for n in REMOVED_HOOKS if n in content]
    assert registered == [], (
        f"settings.json.example still registers removed hooks: {registered}"
    )


def test_wake_up_has_no_dead_producer_reads():
    """(F23.4) wake-up-layer-stack.sh no longer reads what C3 deleted:
    the _vault-index and the L2_wings blocks."""
    content = (HOOKS / "wake-up-layer-stack.sh").read_text()
    for marker in ("_vault-index", "L2_wings", "vault-wing-compiler",
                   "vault-index-updater", "VAULT_INDEX", "LINT_REPORT"):
        assert marker not in content, (
            f"wake-up-layer-stack.sh still references {marker!r} — its producer "
            f"was deleted by Slice D; this is a dead read"
        )


def test_no_hook_sources_a_removed_sibling():
    """No surviving hook EXECUTES a removed basename. Comment prose documenting
    the removal itself is allowed; any non-comment line naming one is a dead
    reference (a source, fork or exec of a file that no longer exists)."""
    offenders = []
    for hook in HOOKS.iterdir():
        if not hook.is_file():
            continue
        for line in hook.read_text(errors="ignore").splitlines():
            if line.lstrip().startswith("#"):
                continue
            for name in REMOVED_HOOKS:
                if name in line:
                    offenders.append(f"{hook.name}: {line.strip()[:90]}")
    assert offenders == [], (
        f"surviving hooks still execute removed memory writers: {offenders}"
    )


def test_no_hook_references_dream_auto_apply_env():
    """(F23.5) RALPH_DREAM_APPLY had exactly one auto-bound consumer
    (dream-consolidate.sh, deleted in C4). No executable hook line may
    reference it; dream.py keeps it as an explicit-tool opt-in outside
    .claude/hooks/."""
    offenders = []
    for hook in HOOKS.iterdir():
        if not hook.is_file():
            continue
        for line in hook.read_text(errors="ignore").splitlines():
            if line.lstrip().startswith("#"):
                continue
            if "RALPH_DREAM_APPLY" in line:
                offenders.append(f"{hook.name}: {line.strip()[:90]}")
    assert offenders == [], (
        f"hooks still reference RALPH_DREAM_APPLY (auto-apply policy): {offenders}"
    )


def test_wake_up_still_emits_valid_sessionstart_json():
    """The survivor must still work: wake-up emits valid additionalContext.
    A guard that only asserts absence proves nothing if the surviving hook
    broke in the pruning."""
    proc = subprocess.run(
        ["bash", str(HOOKS / "wake-up-layer-stack.sh")],
        input="", capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, f"wake-up exited {proc.returncode}: {proc.stderr[:200]}"
    assert '"additionalContext"' in proc.stdout, (
        f"wake-up lost its SessionStart payload; stdout head: {proc.stdout[:200]!r}"
    )
