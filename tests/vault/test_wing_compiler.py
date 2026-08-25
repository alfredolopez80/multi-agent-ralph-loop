"""Regression tests for vault-wing-compiler.sh (T54, issue #69).

The wing fed the wake-up 43 bullets of which only 9 were distinct (79%
filler): every line carried a doubled category prefix, and whole blocks
repeated x3/x6. Three independent causes, all fixed and pinned here:

  1. doubled prefix — the extractor's lines already carry "- [cat] "; the
     compiler prepended a second one;
  2. read-modify-write race — the lock covered only the final echo, so N
     concurrent sessions (pane + subagents fire within seconds) each
     appended the same facts; plus a cut -c1-60 dedup key that ignored the
     file path (the only distinguishing part), and no intra-batch dedup;
  3. no retro-repair — the accumulated garbage had no path back.

These tests also pin the knowledge-preservation direction: two legitimately
distinct facts must survive as two lines, and the historical wing is
repaired (prefixes collapsed, duplicates dropped) on the first post-fix run.
"""
import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]   # tests/vault/ -> repo root
HOOK = REPO / ".claude" / "hooks" / "vault-wing-compiler.sh"

WING_HEADER = [
    "# Wing: multi-agent-ralph-loop", "",
    "**Project**: multi-agent-ralph-loop",
    "**Compiled**: 2026-01-01T00:00:00Z",
    "**Source**: vault-wing-compiler.sh (auto-generated)", "", "## Facts", "",
]


def make_home(with_repo=True):
    h = Path(tempfile.mkdtemp())
    for d in ("Documents/Obsidian/MiVault/projects/multi-agent-ralph-loop/facts",
              ".ralph/layers/L2_wings/multi-agent-ralph-loop"):
        (h / d).mkdir(parents=True)
    if with_repo:
        repo = h / "Documents/GitHub/multi-agent-ralph-loop"
        repo.mkdir(parents=True)
        subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
    return h


def write_facts(home, lines):
    import datetime
    today = datetime.date.today().strftime("%Y%m%d")
    f = home / "Documents/Obsidian/MiVault/projects/multi-agent-ralph-loop/facts" / f"facts-{today}.md"
    f.write_text("\n".join(lines) + "\n")
    return f


def write_wing(home, bullet_lines):
    w = home / ".ralph/layers/L2_wings/multi-agent-ralph-loop/context.md"
    w.write_text("\n".join(WING_HEADER + bullet_lines) + "\n")
    return w


def run_hook(home, session="t"):
    env = dict(os.environ)
    env["HOME"] = str(home)
    return subprocess.run(
        ["bash", str(HOOK)],
        input=json.dumps({"session_id": session}),
        capture_output=True, text=True, env=env, timeout=60,
    )


def bullets(wing):
    return [l for l in wing.read_text().splitlines() if l.startswith("- [")]


def test_t54_new_facts_carry_exactly_one_prefix():
    h = make_home()
    write_facts(h, ["- [design_patterns] Adapter pattern (a.sh)"])
    w = write_wing(h, [])
    run_hook(h)
    b = bullets(w)
    assert len(b) == 1
    assert b[0] == "- [design_patterns] Adapter pattern (a.sh)"
    assert "- [design_patterns] - [" not in b[0]


def test_t54_intra_batch_duplicates_enter_once():
    h = make_home()
    write_facts(h, ["- [code_structure] fact X (x.sh)",
                    "- [code_structure] fact X (x.sh)",
                    "- [code_structure] fact X (x.sh)"])
    w = write_wing(h, [])
    run_hook(h)
    assert bullets(w).count("- [code_structure] fact X (x.sh)") == 1


def test_t54_historical_wing_is_retro_repaired():
    # The pre-fix state: doubled prefixes + x2 duplicates of everything.
    h = make_home()
    write_facts(h, ["- [code_structure] brand new fact (n.sh)"])
    w = write_wing(h, [
        "- [design_patterns] - [design_patterns] OLD one (1.sh)",
        "- [design_patterns] - [design_patterns] OLD one (1.sh)",
        "- [code_structure] - [code_structure] OLD two (2.sh)",
        "- [code_structure] - [code_structure] OLD two (2.sh)",
    ])
    run_hook(h)
    b = bullets(w)
    assert "- [design_patterns] OLD one (1.sh)" in b
    assert b.count("- [design_patterns] OLD one (1.sh)") == 1
    assert "- [code_structure] OLD two (2.sh)" in b
    assert len([x for x in b if "OLD" in x]) == 2          # repaired, not duplicated
    assert not any("] - [" in x for x in b)                # no doubled prefixes remain


def test_t54_two_legitimately_distinct_facts_survive():
    # Knowledge preservation: distinct paths are distinct facts, never
    # merged by a shared prefix (the old cut -c1-60 key did exactly that).
    h = make_home()
    write_facts(h, ["- [code_structure] Shell function: check (a/one.sh)",
                    "- [code_structure] Shell function: check (b/two.sh)"])
    w = write_wing(h, [])
    run_hook(h)
    assert len(bullets(w)) == 2


def test_t54_concurrent_runs_do_not_duplicate():
    # The race: pane + subagents fire the compiler within seconds. Three
    # parallel runs over the same facts must leave ONE copy of each fact.
    h = make_home()
    write_facts(h, ["- [design_patterns] raced fact (r.sh)"])
    w = write_wing(h, [])
    procs = [subprocess.Popen(
        ["bash", str(HOOK)], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, env={**os.environ, "HOME": str(h)}) for _ in range(3)]
    for i, p in enumerate(procs):
        p.communicate(json.dumps({"session_id": f"race{i}"}).encode() + b"\n", timeout=60)
    for p in procs:
        assert p.returncode == 0
    assert bullets(w).count("- [design_patterns] raced fact (r.sh)") == 1


def test_t54_known_facts_are_not_re_added():
    h = make_home()
    write_facts(h, ["- [design_patterns] known fact (k.sh)"])
    w = write_wing(h, ["- [design_patterns] known fact (k.sh)"])
    run_hook(h)
    run_hook(h)
    assert bullets(w).count("- [design_patterns] known fact (k.sh)") == 1


def test_t54_failed_project_detection_falls_back_to_unknown():
    # basename of "" succeeds with rc 0, so the old "unknown" fallback was
    # dead: a failed rev-parse compiled silently into projects//facts/.
    h = make_home(with_repo=False)
    w = write_wing(h, [])
    r = run_hook(h)
    assert r.returncode == 0
    assert not (h / "Documents/Obsidian/MiVault/projects" / "" / "facts").exists()
    stray = list((h / "Documents/Obsidian/MiVault/projects").iterdir())
    assert all(d.name != "" for d in stray)  # no empty-name project dir
