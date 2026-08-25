"""Equivalence gate for the security-only settings profile (T68, issue #46).

The profile (.claude/security/settings.security-only.json) materializes
acceptance checkbox 2 of #46: a settings file that registers ONLY the
security plane. The manifest (.claude/security/SECURITY_BASELINE.json) is
the single source of truth for what the plane IS, so the profile is
DERIVED, never hand-written — a hand-written list diverges from the
manifest within a week. These tests make every divergence loud:

  1. The committed profile must equal the derivation byte for byte.
     Regenerate after any manifest change with:
         python3 tests/test_security_only_profile.py --update
  2. Divergence fails in BOTH directions: a control added to the manifest
     without regenerating fails (missing); a registration removed from or
     hand-injected into the profile fails (extra). Green means
     "profile == manifest", nothing weaker.
  3. The checker itself is proven able to fail: mutation tests below
     remove and inject registrations on in-memory copies and assert the
     checker reports them — a guard that could never fail is
     indistinguishable from a deleted guard.
  4. Escape hatch: ANNOTATED_EXTRAS / ANNOTATED_OMISSIONS below silence a
     documented divergence. An annotation without a written reason is
     invalid; an annotation matching no real divergence is STALE and
     fails. Same contract as .claude/hooks/skill-validator.allowlist: the
     hatch cannot rot.
  5. Zero entries is failure, never pass: an empty manifest or an empty
     derivation raises instead of producing a silent green.

Application is deliberately out of scope here: `claude --settings
.claude/security/settings.security-only.json` loads the plane on top of
the user's own settings (user settings still apply); full variant-A
isolation is a lead/user decision that comes after this file exists.
"""
import json
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO / ".claude" / "security" / "SECURITY_BASELINE.json"
PROFILE_PATH = REPO / ".claude" / "security" / "settings.security-only.json"

# Hook commands must not bake in one machine's layout: $CLAUDE_PROJECT_DIR
# resolves per-project at hook-execution time (and per-worktree, which is
# how this repo actually runs).
COMMAND_PREFIX = "$CLAUDE_PROJECT_DIR/"

# Escape hatch. Shape: {"(event, matcher, command)": {"reason": "..."}}
# ANNOTATED_EXTRAS: registrations present in the profile but NOT derivable
# from the manifest (e.g. a temporary control not yet promoted to it).
# ANNOTATED_OMISSIONS: manifest registrations deliberately absent from the
# profile. Every entry needs a written reason or it is invalid; an entry
# matching no real divergence is STALE and fails.
ANNOTATED_EXTRAS = {}
ANNOTATED_OMISSIONS = {}


# ------------------------------------------------------------- derivation

def load_manifest(path=MANIFEST_PATH):
    return json.loads(Path(path).read_text())


def derive_regs(manifest):
    """Registrations the manifest demands: one per (control, matcher).

    kind=lib controls (worktree-utils) are sourced, not registered, so
    they contribute nothing here. An empty derivation is a hard error:
    a security plane with zero registrations is failure, never pass.
    """
    regs = []
    for control in manifest["controls"]:
        if control.get("kind") != "hook" or not control.get("event"):
            continue
        for matcher in control["matchers"]:
            regs.append({
                "event": control["event"],
                "matcher": matcher,
                "command": COMMAND_PREFIX + control["hook"],
            })
    if not regs:
        raise ValueError(
            "empty derivation: the manifest declares no hook controls — "
            "refusing to render an empty security plane (zero entries is "
            "failure, never pass)"
        )
    return regs


def render_profile(regs):
    """Deterministic settings JSON: group by event, manifest order inside."""
    hooks = {}
    for reg in regs:
        hooks.setdefault(reg["event"], []).append({
            "matcher": reg["matcher"],
            "hooks": [{"type": "command", "command": reg["command"]}],
        })
    return {"hooks": hooks}


def profile_text(regs):
    return json.dumps(render_profile(regs), indent=2) + "\n"


def flatten_profile(profile):
    """Settings shape -> flat (event, matcher, command) triples."""
    flat = []
    for event, blocks in profile.get("hooks", {}).items():
        for block in blocks:
            for entry in block["hooks"]:
                flat.append((event, block["matcher"], entry["command"]))
    return flat


def full_regs():
    """Derivation INCLUDING the annotated hatch: what --update writes.

    manifest_regs - ANNOTATED_OMISSIONS + ANNOTATED_EXTRAS. The committed
    profile is byte-compared against THIS, so a hatch entry changes the
    canonical output instead of fighting it.
    """
    regs = derive_regs(load_manifest())
    keep = {(r["event"], r["matcher"], r["command"]) for r in regs} - set(ANNOTATED_OMISSIONS)
    out = [r for r in regs if (r["event"], r["matcher"], r["command"]) in keep]
    for event, matcher, command in ANNOTATED_EXTRAS:
        out.append({"event": event, "matcher": matcher, "command": command})
    return out


# ----------------------------------------------------------------- checker

def divergence(manifest_regs, profile_regs,
               extras=None, omissions=None):
    """Compare derivation against profile, honoring the annotated hatch.

    Returns {"missing": [...], "extra": [...], "annotation_errors": [...]}.
    Green is missing == extra == annotation_errors == [].
    """
    extras = ANNOTATED_EXTRAS if extras is None else extras
    omissions = ANNOTATED_OMISSIONS if omissions is None else omissions

    wanted = {(r["event"], r["matcher"], r["command"]) for r in manifest_regs}
    present = set(profile_regs)

    raw_missing = wanted - present
    raw_extra = present - wanted

    errors = []
    for label, annotations, matching in (
        ("extra", extras, raw_extra),
        ("omission", omissions, raw_missing),
    ):
        for key, spec in annotations.items():
            reason = (spec or {}).get("reason", "").strip()
            if not reason:
                errors.append(
                    f"annotated {label} {key}: an annotation without a "
                    f"written reason is invalid (fail-closed, like "
                    f"skill-validator.allowlist)"
                )
            elif key not in matching:
                errors.append(
                    f"annotated {label} {key}: STALE — no such divergence "
                    f"exists anymore; remove the annotation (the hatch "
                    f"cannot rot)"
                )

    silenced_extra = {k for k in extras if k in raw_extra}
    silenced_missing = {k for k in omissions if k in raw_missing}
    return {
        "missing": sorted(raw_missing - silenced_missing),
        "extra": sorted(raw_extra - silenced_extra),
        "annotation_errors": errors,
    }


def check_committed_profile():
    report = divergence(derive_regs(load_manifest()),
                        flatten_profile(json.loads(PROFILE_PATH.read_text())))
    return report


# ------------------------------------------------------------------- tests

def test_manifest_declares_nonzero_controls():
    manifest = load_manifest()
    assert len(manifest["controls"]) > 0, (
        "the security manifest is empty — zero controls is failure, "
        "never pass"
    )


def test_profile_exists_wellformed_settings_shape():
    assert PROFILE_PATH.is_file(), (
        f"{PROFILE_PATH.relative_to(REPO)} does not exist — generate it: "
        f"python3 tests/test_security_only_profile.py --update"
    )
    profile = json.loads(PROFILE_PATH.read_text())
    assert isinstance(profile.get("hooks"), dict) and profile["hooks"], (
        "profile must carry a non-empty 'hooks' object"
    )
    for event, blocks in profile["hooks"].items():
        assert blocks, f"event {event} has no matcher blocks"
        for block in blocks:
            assert isinstance(block.get("matcher"), str) and block["matcher"], (
                f"{event}: matcher block without a matcher string"
            )
            assert isinstance(block.get("hooks"), list) and block["hooks"], (
                f"{event}/{block['matcher']}: block without a hooks list"
            )
            for entry in block["hooks"]:
                assert entry.get("type") == "command", (
                    f"{event}/{block['matcher']}: non-command hook entry"
                )
                assert isinstance(entry.get("command"), str) and entry["command"], (
                    f"{event}/{block['matcher']}: hook entry without command"
                )


def test_profile_commands_resolve_to_existing_files():
    profile = json.loads(PROFILE_PATH.read_text())
    for event, matcher, command in flatten_profile(profile):
        assert command.startswith(COMMAND_PREFIX), (
            f"{command}: commands must be repo-relative under "
            f"{COMMAND_PREFIX} — absolute paths bake in one machine's "
            f"layout"
        )
        rel = command[len(COMMAND_PREFIX):]
        assert (REPO / rel).is_file(), (
            f"{command}: points at {rel}, which does not exist in the repo"
        )


def test_profile_equals_manifest_derivation():
    report = check_committed_profile()
    assert report == {"missing": [], "extra": [], "annotation_errors": []}, (
        f"security-only profile diverges from the manifest.\n"
        f"  missing (manifest demands, profile lacks): {report['missing']}\n"
        f"  extra (profile has, manifest does not): {report['extra']}\n"
        f"  annotation problems: {report['annotation_errors']}\n"
        f"Regenerate with: python3 tests/test_security_only_profile.py --update"
    )


def test_committed_profile_is_byte_identical_to_derivation():
    assert PROFILE_PATH.read_text() == profile_text(full_regs()), (
        "profile differs from the deterministic derivation (ordering or "
        "formatting drift) — regenerate with: "
        "python3 tests/test_security_only_profile.py --update"
    )


def test_checker_detects_removed_registration():
    """The checker can fail: dropping one registration must be reported."""
    regs = derive_regs(load_manifest())
    profile_regs = flatten_profile(render_profile(regs))
    victim = profile_regs[0]
    report = divergence(regs, [r for r in profile_regs if r != victim])
    assert victim in [tuple(r) for r in report["missing"]], (
        f"removed registration {victim} went undetected — this checker "
        f"cannot be trusted to catch erosion"
    )
    assert report["extra"] == []


def test_checker_detects_injected_registration():
    """Hand-injected registrations must be reported as extra."""
    regs = derive_regs(load_manifest())
    profile_regs = flatten_profile(render_profile(regs))
    injected = ("PreToolUse", "Bash", "$CLAUDE_PROJECT_DIR/.claude/hooks/not-in-manifest.sh")
    report = divergence(regs, profile_regs + [injected])
    assert injected in [tuple(r) for r in report["extra"]], (
        f"injected registration {injected} went undetected"
    )
    assert report["missing"] == []


def test_manifest_growth_requires_regeneration():
    """Control #7 in the manifest: the committed profile must fall behind."""
    manifest = load_manifest()
    manifest["controls"].append({
        "id": "synthetic-future-control",
        "kind": "hook",
        "hook": ".claude/hooks/future-guard.sh",
        "event": "PreToolUse",
        "matchers": ["Bash"],
        "sources": [],
        "properties": [],
        "fixture": {},
    })
    grown = derive_regs(manifest)
    committed = flatten_profile(json.loads(PROFILE_PATH.read_text()))
    report = divergence(grown, committed)
    assert report["missing"], (
        "a grown manifest did not leave the committed profile behind — "
        "the equivalence gate would pass stale"
    )


def test_escape_hatch_silences_annotated_extra():
    regs = derive_regs(load_manifest())
    profile_regs = flatten_profile(render_profile(regs))
    extra = ("PreToolUse", "Bash", "$CLAUDE_PROJECT_DIR/.claude/hooks/temporary.sh")

    with_reason = {extra: {"reason": "temporary while Txx lands"}}
    report = divergence(regs, profile_regs + [extra], extras=with_reason)
    assert report == {"missing": [], "extra": [], "annotation_errors": []}, (
        f"annotated extra was not silenced: {report}"
    )

    unannotated = divergence(regs, profile_regs + [extra])
    assert extra in [tuple(r) for r in unannotated["extra"]], (
        "without the annotation the extra must fail"
    )


def test_annotation_without_reason_is_invalid():
    regs = derive_regs(load_manifest())
    profile_regs = flatten_profile(render_profile(regs))
    extra = ("PreToolUse", "Bash", "$CLAUDE_PROJECT_DIR/.claude/hooks/temporary.sh")
    report = divergence(regs, profile_regs + [extra],
                        extras={extra: {"reason": "   "}})
    assert report["annotation_errors"], (
        "a blank annotation reason must be rejected, not accepted"
    )


def test_stale_annotation_fails():
    regs = derive_regs(load_manifest())
    profile_regs = flatten_profile(render_profile(regs))
    ghost = ("PreToolUse", "Bash", "$CLAUDE_PROJECT_DIR/.claude/hooks/ghost.sh")
    report = divergence(regs, profile_regs,
                        extras={ghost: {"reason": "silences nothing"}})
    assert report["annotation_errors"], (
        "an annotation matching no real divergence is STALE and must fail"
    )


def test_empty_derivation_raises():
    with pytest.raises(ValueError, match="empty derivation"):
        derive_regs({"controls": []})


# --------------------------------------------------------------- update CLI

if __name__ == "__main__":
    if "--update" in sys.argv[1:]:
        regs = full_regs()
        PROFILE_PATH.write_text(profile_text(regs))
        print(f"regenerated {PROFILE_PATH.relative_to(REPO)} "
              f"({len(regs)} registrations) "
              f"from {MANIFEST_PATH.relative_to(REPO)} (hatch included)")
    else:
        print(__doc__)
        print("usage: python3 tests/test_security_only_profile.py --update")
        sys.exit(2)
