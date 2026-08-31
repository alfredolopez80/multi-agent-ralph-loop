"""Unresolved-script-path regression runner for k8s-context-guard-v2 (issue #68).

Matrix (done-when of P2-68): literal resolvable cloud scripts stay inspected;
dynamic/symlink cloud scripts get an explicit non-allow (never a silent allow);
the verdict under bypassPermissions semantics is "deny" (an "ask" would be
auto-approved and is not enforcement); ordinary non-cloud dynamic scripts that
resolve via $HOME/$PWD stay usable; static protections (bash -c, make) intact.

Fail-loud: every case asserts the exact decision; the run is a failure unless
>= MIN_CASES cases executed with zero failures (zero-tests-is-never-success).
"""

import json
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT_ROOT / ".claude" / "hooks"))

from k8s_context_guard.cloud_operation_gate import assess_command  # noqa: E402

MIN_CASES = 12
ran = passed = failed = xfailed = 0


@dataclass
class MinikubeVer:
    valid: bool = True
    is_minikube: bool = True
    profile: str = "minikube"


def check(name, got, ok, detail=""):
    global ran, passed, failed
    ran += 1
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}: {detail or got}")


def assess(cmd, cwd):
    return assess_command(cmd, cwd, lambda c, k: MinikubeVer())


GUARD = PROJECT_ROOT / ".claude" / "hooks" / "k8s-context-guard-v2.py"


def entrypoint_decision(command, cwd):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": str(cwd)})
    p = subprocess.run(["python3", str(GUARD)], input=payload, text=True, capture_output=True)
    return json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]


tmp = Path(tempfile.mkdtemp(prefix="zc4-issue68-"))

cloud = tmp / "deploy_lit.sh"
cloud.write_text("#!/usr/bin/env bash\nkubectl delete pod x\n", encoding="utf-8")
cloud.chmod(0o755)
clean = tmp / "clean_lit.sh"
clean.write_text("#!/usr/bin/env bash\necho hello\n", encoding="utf-8")
clean.chmod(0o755)
link = tmp / "deploy_link.sh"
link.symlink_to(cloud)
nocloud = tmp / "normal.sh"
nocloud.write_text("#!/usr/bin/env bash\necho ok\n", encoding="utf-8")
nocloud.chmod(0o755)

# --- (1) Literal resolvable cloud script: inspected, existing violation gated ---
a = assess(f"bash {cloud}", tmp)
check(
    "literal_cloud_violation_inspected",
    a.action,
    a.action == "block" and a.reason_code == "kubectl_context_required",
    f"action={a.action} reason_code={a.reason_code}",
)
a = assess(f"bash {clean}", tmp)
check(
    "literal_clean_still_allows",
    a.action,
    a.action == "allow",
    f"action={a.action} reason_code={a.reason_code}",
)

# --- (2) Same relevant script through unresolved/dynamic path: no silent allow ---
a = assess('bash "$SCRIPT_DIR/deploy.sh"', tmp)
check(
    "dynamic_path_cloud_blocked",
    a.action,
    a.action == "block" and a.reason_code == "unresolved_script_path",
    f"action={a.action} reason_code={a.reason_code}",
)
a = assess(f"bash {link}", tmp)
check(
    "symlink_to_cloud_blocked",
    a.action,
    a.action == "block" and a.reason_code == "unresolved_script_path",
    f"action={a.action} reason_code={a.reason_code}",
)

# --- (3) bypassPermissions: the emitted verdict must be "deny", never "ask".
# Under bypassPermissions the harness auto-approves every "ask", so an ask here
# would silently become allow — i.e. NOT enforcement. "deny" cannot be
# auto-approved; this assertion pins the enforcement property itself.
d = entrypoint_decision('bash "$SCRIPT_DIR/deploy.sh"', tmp)
check(
    "bypass_enforcement_verdict_is_deny",
    d,
    d == "deny",
    f"decision={d} (ask would be auto-approved under bypassPermissions)",
)

# --- (4) Ordinary non-cloud dynamic scripts that resolve stay usable ---
a = assess(f"bash $PWD/{nocloud.name}", tmp)
check(
    "pwd_resolvable_nocloud_usable",
    a.action,
    a.action == "allow",
    f"action={a.action} reason_code={a.reason_code}",
)
old_home = os.environ.get("HOME")
os.environ["HOME"] = str(tmp)
try:
    a = assess(f"bash $HOME/{nocloud.name}", tmp)
finally:
    if old_home is None:
        os.environ.pop("HOME", None)
    else:
        os.environ["HOME"] = old_home
check(
    "home_resolvable_nocloud_usable",
    a.action,
    a.action == "allow",
    f"action={a.action} reason_code={a.reason_code}",
)
# ... and the resolvable dynamic path is REALLY inspected: a cloud violation in
# it gates exactly like the literal form.
a = assess(f"bash $PWD/{cloud.name}", tmp)
check(
    "pwd_resolvable_cloud_inspected",
    a.action,
    a.action == "block" and a.reason_code == "kubectl_context_required",
    f"action={a.action} reason_code={a.reason_code}",
)

# An arbitrary unresolvable variable is NOT identifiable as non-cloud -> the
# fail-closed cost of issue #68: gated (visible deny), never silent allow.
a = assess('bash "$ANYVAR/normal.sh"', tmp)
check(
    "arbitrary_var_nocloud_gated_documented",
    a.action,
    a.action == "block" and a.reason_code == "unresolved_script_path",
    f"action={a.action} reason_code={a.reason_code}",
)

# --- (5) Static protections intact / ordinary commands outside the gate ---
a = assess("make build", tmp)
check(
    "no_script_shape_stays_allow",
    a.action,
    a.action == "allow",
    f"action={a.action} reason_code={a.reason_code}",
)
a = assess('bash -c "kubectl delete pod x"', tmp)
check(
    "bash_c_kubectl_still_detected",
    a.action,
    a.action == "block" and a.reason_code == "kubectl_context_required",
    f"action={a.action} reason_code={a.reason_code}",
)
# A literal nonexistent path is not uncertainty: nothing expands at runtime, the
# shell itself fails — it must keep flowing without a guard verdict.
a = assess(f"bash {tmp}/nonexistent_normal.sh", tmp)
check(
    "literal_nonexistent_not_uncertainty",
    a.action,
    a.action == "allow",
    f"action={a.action} reason_code={a.reason_code}",
)

print()
print(f"RAN={ran}  PASS={passed}  FAIL={failed}  XFAIL={xfailed}")
# "Passed: N | ..." is the summary format tests/run-all-unit-tests.sh parses for an
# assertion count (strategy 1); keep it in sync if this line ever changes.
print(f"Passed: {passed} | Failed: {failed} | Xfail: {xfailed}")
if failed > 0 or ran < MIN_CASES:
    print(f"FAIL: expected >= {MIN_CASES} executed cases with zero failures")
    sys.exit(1)
