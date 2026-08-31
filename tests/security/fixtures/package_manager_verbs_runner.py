"""Package-manager verbs regression runner for git-safety-guard.py (PR3-C4).

Pins the explicit package-manager mutation list at the CONFIRMATION tier (ask):
brew install/uninstall/upgrade/tap/untap; pip installs carrying a
system-python marker (--break-system-packages/--system/sudo); npm with a
standalone -g/--global. Local/venv installs and diagnostics stay allow-listed
(the C1 false-positive lesson), PACKAGE_DESTRUCTIVE_CONFIRMED=1 skips the
tier, and the existing cloud/git protections are unchanged.

Fail-loud: every case asserts the exact decision; the run fails unless
>= MIN_CASES cases executed with zero failures (zero-tests-is-never-success).
"""

import json
import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
GUARD = PROJECT_ROOT / ".claude" / "hooks" / "git-safety-guard.py"

MIN_CASES = 20
ran = passed = failed = xfailed = 0


def decision(command, extra_env=None):
    env = {k: v for k, v in os.environ.items() if "DESTRUCTIVE_CONFIRMED" not in k}
    env.update(extra_env or {})
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": "/tmp"})
    p = subprocess.run(["python3", str(GUARD)], input=payload, text=True, capture_output=True, env=env)
    return json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]


def check(name, got, ok, detail=""):
    global ran, passed, failed
    ran += 1
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}: {detail or got}")


def expect(name, command, want, extra_env=None):
    got = decision(command, extra_env)
    check(name, got, got == want, f"decision={got}")


# --- (1) brew mutating verbs: one fixture per verb (all ask) ---
expect("brew_install_ask", "brew install wget", "ask")
expect("brew_uninstall_ask", "brew uninstall wget", "ask")
expect("brew_upgrade_ask", "brew upgrade", "ask")
expect("brew_tap_ask", "brew tap homebrew/cask", "ask")
expect("brew_untap_ask", "brew untap homebrew/cask", "ask")

# --- (2) pip: ONLY system-python markers gate; venv flow stays usable ---
expect("pip_break_system_packages_ask", "pip install requests --break-system-packages", "ask")
expect("pip_system_flag_ask", "pip3 install --system numpy", "ask")
expect("sudo_pip_install_ask", "sudo pip3 install requests", "ask")
expect("pip_requirements_allow", "pip install -r requirements.txt", "allow")
expect("pip_plain_venv_allow", "pip install requests", "allow")
expect("pip_show_allow", "pip show requests", "allow")

# --- (3) npm: standalone -g/--global gates; local installs stay usable ---
expect("npm_global_short_ask", "npm install -g typescript", "ask")
expect("npm_flag_first_ask", "npm -g install typescript", "ask")
expect("npm_global_long_ask", "npm install --global yarn", "ask")
expect("npm_pkg_named_g_allow", "npm install pkg-g", "allow")
expect("npm_local_install_allow", "npm install typescript", "allow")

# --- (4) Diagnostics stay allow-listed ---
expect("brew_list_allow", "brew list", "allow")

# --- (5) Escape hatch: PACKAGE_DESTRUCTIVE_CONFIRMED=1 skips the tier ---
expect(
    "escape_package_confirmed_allows",
    "brew install wget",
    "allow",
    {"PACKAGE_DESTRUCTIVE_CONFIRMED": "1"},
)

# --- (6) Existing protections unchanged ---
expect("existing_gcloud_deploy_still_ask", "gcloud app deploy", "ask")
expect("existing_aws_terminate_still_deny", "aws ec2 terminate-instances i-1", "deny")

print()
print(f"RAN={ran}  PASS={passed}  FAIL={failed}  XFAIL={xfailed}")
# "Passed: N | ..." is the summary format tests/run-all-unit-tests.sh parses for an
# assertion count (strategy 1); keep it in sync if this line ever changes.
print(f"Passed: {passed} | Failed: {failed} | Xfail: {xfailed}")
if failed > 0 or ran < MIN_CASES:
    print(f"FAIL: expected >= {MIN_CASES} executed cases with zero failures")
    sys.exit(1)
