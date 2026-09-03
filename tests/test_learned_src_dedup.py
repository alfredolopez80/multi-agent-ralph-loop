"""Invariants for the graduated-rules source tree (.claude/learned-src/learned/).

Cost-optimize lever 3 (2026-09-03): the always-loaded rule prefix carried the
same rule up to 9 times because halls/ and rooms/ restated proven/ and the
flat learned files, and vault-graduation (pre-a964722) appended entries
twice. These tests pin the cleaned state so a future graduation run or a
re-created taxonomy cannot silently re-inflate the prefix.
"""

from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LEARNED_SRC = REPO_ROOT / ".claude" / "learned-src" / "learned"
AUTOLOAD_LEARNED = REPO_ROOT / ".claude" / "rules" / "learned"


def _bullets(path: Path) -> list[str]:
    return [ln.strip() for ln in path.read_text().splitlines() if ln.strip().startswith("- ")]


def test_learned_src_exists_and_is_flat():
    assert LEARNED_SRC.is_dir()
    md = sorted(p.name for p in LEARNED_SRC.glob("*.md"))
    assert md, "learned-src/learned/ must hold at least one flat rule file"
    subdirs = [p.name for p in LEARNED_SRC.iterdir() if p.is_dir()]
    assert subdirs == [], (
        f"taxonomy subdirectories re-created under learned-src: {subdirs}. "
        "halls/ and rooms/ were retired as verbatim duplicates of proven/ "
        "(DISTRIBUTION_POLICY.md addendum 2026-09-03)."
    )


def test_no_repeated_bullets_within_a_file():
    for path in LEARNED_SRC.glob("*.md"):
        bullets = _bullets(path)
        dupes = {b for b in bullets if bullets.count(b) > 1}
        assert not dupes, f"{path.name} repeats graduated entries: {sorted(dupes)}"


def test_no_repeated_bullets_across_files():
    seen: dict[str, str] = {}
    for path in sorted(LEARNED_SRC.glob("*.md")):
        for b in _bullets(path):
            assert b not in seen, f"{path.name} repeats an entry already in {seen[b]}: {b[:80]}"
            seen[b] = path.name


def test_autoload_learned_dir_stays_empty():
    """T62 invariant: .claude/rules/learned/ is auto-loaded per session and
    must not carry copies of learned-src (they are paid twice per session)."""
    if not AUTOLOAD_LEARNED.exists():
        return
    stray = sorted(p.name for p in AUTOLOAD_LEARNED.rglob("*.md"))
    assert stray == [], f"stray auto-loaded learned copies: {stray}"
