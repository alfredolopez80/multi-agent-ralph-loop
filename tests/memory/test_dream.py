"""Tests for the Ralph dream consolidation / L3 builder (Phase B3).

Covers: target_layer classification, score_candidate ranges, content-hash dedup
against existing layers, RED sources being skipped wholesale, and dry-run
writing nothing while --apply produces a GREEN/YELLOW-only L3 layer.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

import dream  # noqa: E402
from _dream_core import (  # noqa: E402
    L3_LAYER_NAME,
    Candidate,
    build_report,
    collect_sources,
    extract_candidates,
    l3_candidates,
    render_l3,
    score_candidate,
    target_layer,
)

# A RED secret string assembled from fragments so this test file does not itself
# trip the scanner when grepped.
_RED_SECRET = "api_key = " + "sk-" + "ABCDEF0123456789ABCDEF0123"


@pytest.fixture()
def ralph_home(tmp_path) -> Path:
    home = tmp_path / "ralph_home"
    (home / "handoffs" / "sess1").mkdir(parents=True)
    (home / "ledgers").mkdir(parents=True)
    (home / "layers").mkdir(parents=True)
    return home


@pytest.fixture()
def vault_root(tmp_path) -> Path:
    root = tmp_path / "vault"
    (root / "projects" / "demo" / "lessons").mkdir(parents=True)
    return root


# ---------------------------------------------------------------------------
# target_layer classification.
# ---------------------------------------------------------------------------

def test_target_layer_l1_wins_on_criticality():
    assert target_layer("You must always validate inputs") == "L1"
    assert target_layer("Never log secret material") == "L1"


def test_target_layer_l2_repo_project_markers():
    assert target_layer("This repo uses a checkpoint convention") == "L2"
    assert target_layer("Run the migration before tests") == "L2"


def test_target_layer_l3_vault_index_markers():
    assert target_layer("Index this into the vault as an external note") == "L3"
    assert target_layer("External reference worth keeping in the index") == "L3"


def test_target_layer_report_only_when_no_marker():
    assert target_layer("a plain sentence with nothing notable here") == "report-only"


# ---------------------------------------------------------------------------
# score_candidate range + signals.
# ---------------------------------------------------------------------------

def test_score_candidate_within_bounds():
    score = score_candidate("a decision was validated as the root cause", 3, {"handoffs", "lessons"})
    assert 0.0 <= score <= 0.95


def test_score_candidate_base_is_half():
    assert score_candidate("we recorded a clear engineering observation here", 1, set()) == 0.5


def test_score_candidate_multi_source_and_strong_marker_raise():
    base = score_candidate("a generic note about the workflow steps", 1, set())
    strong = score_candidate(
        "this decision is the validated root cause of the failure", 2, {"handoffs", "lessons"}
    )
    assert strong > base


def test_score_candidate_penalizes_too_short_and_too_long():
    short = score_candidate("decision", 1, set())
    assert short <= 0.4
    long_text = "decision " + ("x" * 230)
    assert score_candidate(long_text, 1, set()) <= 0.5


def test_score_candidate_never_exceeds_cap():
    score = score_candidate(
        "this decision is the validated root cause and was always reproduced",
        5,
        {"handoffs", "ledgers", "lessons"},
    )
    assert score <= 0.95


# ---------------------------------------------------------------------------
# RED sources are skipped wholesale.
# ---------------------------------------------------------------------------

def test_collect_sources_skips_red(ralph_home, vault_root):
    safe = ralph_home / "handoffs" / "sess1" / "handoff-safe.md"
    safe.write_text(
        "Timestamp: 2026-06-01T00:00:00+00:00\nDecision: index this into the vault.\n",
        encoding="utf-8",
    )
    red = ralph_home / "handoffs" / "sess1" / "handoff-red.md"
    red.write_text(f"Decision: keep the vault index.\n{_RED_SECRET}\n", encoding="utf-8")

    sources, skipped = collect_sources(ralph_home, None, 1000, vault_root=vault_root)
    labels = {item.label for item in sources}
    assert any("handoff-safe.md" in label for label in labels)
    assert not any("handoff-red.md" in label for label in labels)
    assert len(skipped) == 1
    assert skipped[0]["reason"] == "RED"


def test_red_never_appears_in_l3(ralph_home, vault_root):
    red = ralph_home / "ledgers" / "CONTINUITY-red.md"
    red.write_text(
        f"Decision: index this into the vault as external note.\n{_RED_SECRET}\n",
        encoding="utf-8",
    )
    report = build_report(ralph_home, None, 1000, "2026-06-17T00:00:00+00:00", vault_root=vault_root)
    rendered = render_l3(report)
    assert "sk-" not in rendered
    assert "ABCDEF0123456789" not in rendered
    assert report["red_skipped"] == 1


# ---------------------------------------------------------------------------
# Dedup against existing layers.
# ---------------------------------------------------------------------------

def test_extract_candidates_dedups_against_existing_layer(ralph_home, vault_root):
    line = "Index the migration decision into the vault external note"
    # Seed an existing L3 layer that already contains this consolidation.
    (ralph_home / "layers" / L3_LAYER_NAME).write_text(
        f"# L3 Dream Consolidations\n\n## 1. {line}\n", encoding="utf-8"
    )
    source = ralph_home / "handoffs" / "sess1" / "h.md"
    source.write_text(
        f"Timestamp: 2026-06-01T00:00:00+00:00\n{line}\n", encoding="utf-8"
    )
    sources, _ = collect_sources(ralph_home, None, 1000, vault_root=vault_root)
    candidates, duplicate_count = extract_candidates(sources, ralph_home / "layers")
    assert duplicate_count >= 1
    matching = [c for c in candidates if line.lower() in c.text.lower()]
    assert matching and matching[0].duplicate_existing is True
    # Duplicates are excluded from the eligible L3 set.
    report = build_report(ralph_home, None, 1000, "2026-06-17T00:00:00+00:00", vault_root=vault_root)
    assert all(line.lower() not in str(c.get("text", "")).lower() for c in l3_candidates(report))


def test_extract_candidates_collapses_identical_lines(ralph_home, vault_root):
    line = "Decision: always index validated learnings into the vault."
    h1 = ralph_home / "handoffs" / "sess1" / "h1.md"
    h2 = ralph_home / "ledgers" / "l1.md"
    h1.write_text(f"Timestamp: 2026-06-01T00:00:00+00:00\n{line}\n", encoding="utf-8")
    h2.write_text(f"Generated: 2026-06-02T00:00:00+00:00\n{line}\n", encoding="utf-8")
    sources, _ = collect_sources(ralph_home, None, 1000, vault_root=vault_root)
    candidates, _ = extract_candidates(sources, ralph_home / "layers")
    matching = [c for c in candidates if "always index validated" in c.text.lower()]
    assert len(matching) == 1
    assert matching[0].duplicate_count == 2
    assert set(matching[0].source_groups) == {"handoffs", "ledgers"}


# ---------------------------------------------------------------------------
# Dry-run writes nothing; --apply writes L3.
# ---------------------------------------------------------------------------

def _seed_l3_worthy(ralph_home: Path) -> None:
    src = ralph_home / "handoffs" / "sess1" / "good.md"
    src.write_text(
        "Timestamp: 2026-06-01T00:00:00+00:00\n"
        "Decision: index the validated root cause into the vault external note.\n",
        encoding="utf-8",
    )


def test_dry_run_writes_nothing(ralph_home, vault_root, capsys):
    _seed_l3_worthy(ralph_home)
    rc = dream.main(
        [
            "--dry-run",
            "--ralph-home",
            str(ralph_home),
            "--vault-root",
            str(vault_root),
        ]
    )
    assert rc == 0
    assert not (ralph_home / "layers" / L3_LAYER_NAME).exists()
    out = capsys.readouterr().out
    assert "DREAM_DRY_RUN_OK" in out


def test_default_is_dry_run(ralph_home, vault_root):
    _seed_l3_worthy(ralph_home)
    rc = dream.main(["--ralph-home", str(ralph_home), "--vault-root", str(vault_root)])
    assert rc == 0
    assert not (ralph_home / "layers" / L3_LAYER_NAME).exists()


def test_apply_writes_l3(ralph_home, vault_root):
    _seed_l3_worthy(ralph_home)
    rc = dream.main(
        ["--apply", "--ralph-home", str(ralph_home), "--vault-root", str(vault_root)]
    )
    assert rc == 0
    l3 = ralph_home / "layers" / L3_LAYER_NAME
    assert l3.is_file()
    content = l3.read_text(encoding="utf-8")
    assert "L3 Dream Consolidations" in content
    assert "validated root cause" in content


def test_emit_patch_prints_without_writing(ralph_home, vault_root, capsys):
    _seed_l3_worthy(ralph_home)
    rc = dream.main(
        ["--emit-patch", "--ralph-home", str(ralph_home), "--vault-root", str(vault_root)]
    )
    assert rc == 0
    assert not (ralph_home / "layers" / L3_LAYER_NAME).exists()
    out = capsys.readouterr().out
    assert "L3 Dream Consolidations" in out


def test_l3_candidates_are_green_or_yellow_only(ralph_home, vault_root):
    _seed_l3_worthy(ralph_home)
    report = build_report(ralph_home, None, 1000, "2026-06-17T00:00:00+00:00", vault_root=vault_root)
    for candidate in l3_candidates(report):
        assert candidate["classification"] in ("GREEN", "YELLOW")
        assert candidate["target_layer"] == "L3"


def test_since_days_filters_old_sources(ralph_home, vault_root):
    old = ralph_home / "handoffs" / "sess1" / "old.md"
    old.write_text(
        "Timestamp: 2000-01-01T00:00:00+00:00\nDecision: index old note into vault.\n",
        encoding="utf-8",
    )
    sources, _ = collect_sources(ralph_home, 30, 1000, vault_root=vault_root)
    assert not any("old.md" in item.label for item in sources)


# ---------------------------------------------------------------------------
# Candidate.public_dict shape.
# ---------------------------------------------------------------------------

def test_candidate_public_dict_keys():
    candidate = Candidate(target_layer="L3", classification="GREEN", text="x")
    keys = set(candidate.public_dict().keys())
    assert {
        "target_layer",
        "classification",
        "text",
        "source_paths",
        "source_groups",
        "confidence",
        "hash",
        "duplicate_existing",
        "duplicate_count",
    } == keys
