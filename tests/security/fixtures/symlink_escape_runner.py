"""Symlink-escape regression runner for repo-boundary-guard.sh (issue #45, PR3-C5).

Fixture-first: captures the REQUIRED behavior — a path that superficially
points inside the trusted boundary but resolves through a symlink to OUTSIDE
it must not be silently allowed by canonicalization.

The fixture repo is created under $HOME/Documents/GitHub (the guard's
GITHUB_DIR, wherever HOME points — run-all-unit-tests sandboxes HOME, so the
effective location is read, never assumed) and git-initialized so the guard
detects it as its own boundary. Under the gate the sandbox trap cleans it;
standalone the runner cleans up after itself.

Fail-loud: every case asserts the exact decision; the run fails unless
>= MIN_CASES cases executed with zero failures (zero-tests-is-never-success).
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
GUARD = PROJECT_ROOT / ".claude" / "hooks" / "repo-boundary-guard.sh"

MIN_CASES = 9
ran = passed = failed = xfailed = 0


def check(name, got, ok, detail=""):
    global ran, passed, failed
    ran += 1
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}: {detail or got}")


def guard_decision(tool, payload_tool_input, cwd):
    payload = {"tool_name": tool, "tool_input": payload_tool_input, "cwd": str(cwd)}
    # The guard detects the boundary from the PROCESS cwd (git rev-parse), never
    # from the payload's cwd field — so the subprocess must actually run there.
    p = subprocess.run(["bash", str(GUARD)], input=json.dumps(payload), text=True, capture_output=True, cwd=str(cwd))
    return json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]


# --- Fixture: under the EFFECTIVE GITHUB_DIR; a git repo of its own ---
home = Path.home()
fixture_root = home / "Documents" / "GitHub"
fixture = fixture_root / f".zc4-c5-fix-{os.getpid()}"
outside = home / ".zc4-c5-outside"
shutil.rmtree(fixture, ignore_errors=True)
shutil.rmtree(outside, ignore_errors=True)
(fixture / "scripts").mkdir(parents=True)
subprocess.run(["git", "init", "-q", str(fixture)], check=True)
outside.mkdir(parents=True)
outside.joinpath("secret.txt").write_text("outside data", encoding="utf-8")
# macOS /var -> /private/var: the guard's mention-gate compares command tokens
# against the CANONICALIZED GITHUB_DIR (#61), so the exercised commands must use
# the canonical fixture path. A raw-alias mention slipping the scan is a
# separate preexisting gap, reported to lead — not what this suite pins.
fixture = Path(os.path.realpath(fixture))
outside = Path(os.path.realpath(outside))
(fixture / "escape.sh").symlink_to(outside)                      # in-repo -> $HOME (out)
chain = fixture / "chain.sh"
chain.symlink_to(fixture / "escape.sh")                          # depth-2 chain -> out
(fixture / "tmplink.sh").symlink_to(Path("/tmp/zc4-c5-tmpdir"))  # in-repo -> /tmp
Path("/tmp/zc4-c5-tmpdir").mkdir(exist_ok=True)
(fixture / "internal_link.sh").symlink_to(fixture / "scripts")    # in-repo -> in-repo
try:
    # --- Required: escaping symlinks are DENIED (silent allow was the gap) ---
    d = guard_decision("Bash", {"command": f"cp {fixture}/escape.sh {fixture}/copy.sh"}, fixture)
    check("escape_symlink_bash_blocked", d, d == "deny", f"decision={d} (symlink resolves outside boundary)")

    d = guard_decision("Write", {"file_path": f"{fixture}/escape.sh/out.txt", "content": "x"}, fixture)
    check("escape_symlink_write_blocked", d, d == "deny", f"decision={d}")

    d = guard_decision("Bash", {"command": f"cp {fixture}/chain.sh {fixture}/copy2.sh"}, fixture)
    check("chained_symlink_blocked", d, d == "deny", f"decision={d} (depth-2 symlink resolves outside)")

    d = guard_decision("Bash", {"command": f"cp {fixture}/tmplink.sh {fixture}/copy3.sh"}, fixture)
    check(
        "tmp_target_symlink_blocked",
        d,
        d == "deny",
        f"decision={d} (in-repo symlink -> /tmp: no exceptions, direct /tmp stays the route)",
    )

    # --- Same-repo symlinks and unclaimed paths stay usable ---
    d = guard_decision("Bash", {"command": f"cp {fixture}/internal_link.sh {fixture}/copy4.sh"}, fixture)
    check("internal_symlink_still_allows", d, d == "allow", f"decision={d}")

    # Pure readonly (no redirect) short-circuits before the scan: still allowed.
    d = guard_decision("Bash", {"command": f"cat {fixture}/internal_link.sh"}, fixture)
    check("readonly_pure_still_allows", d, d == "allow", f"decision={d}")

    # A redirect makes the command a write-scan (guard v2.69 policy), so ALL
    # mentioned paths are boundary-checked even when the symlink is only READ:
    # the conservative cost of fail-closed — pinned here as designed behavior.
    d = guard_decision("Bash", {"command": f"cat {fixture}/escape.sh > /dev/null"}, fixture)
    check("redirect_makes_symlink_read_blocked", d, d == "deny", f"decision={d} (write-scan policy)")

    d = guard_decision("Bash", {"command": f"cp {outside}/secret.txt {fixture}/copy5.sh"}, fixture)
    check(
        "direct_outside_unclaimed_flows",
        d,
        d == "allow",
        f"decision={d} (never claimed the boundary: the fix must not widen the deny)",
    )

    d = guard_decision("Bash", {"command": "echo x > /tmp/zc4-c5-direct.txt"}, fixture)
    check("direct_tmp_still_allowed", d, d == "allow", f"decision={d}")
finally:
    shutil.rmtree(fixture, ignore_errors=True)
    shutil.rmtree(outside, ignore_errors=True)
    shutil.rmtree("/tmp/zc4-c5-tmpdir", ignore_errors=True)

print()
print(f"RAN={ran}  PASS={passed}  FAIL={failed}  XFAIL={xfailed}")
# "Passed: N | ..." is the summary format tests/run-all-unit-tests.sh parses for an
# assertion count (strategy 1); keep it in sync if this line ever changes.
print(f"Passed: {passed} | Failed: {failed} | Xfail: {xfailed}")
if failed > 0 or ran < MIN_CASES:
    print(f"FAIL: expected >= {MIN_CASES} executed cases with zero failures")
    sys.exit(1)
