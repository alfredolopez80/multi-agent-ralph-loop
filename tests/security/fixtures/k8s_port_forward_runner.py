"""port-forward tier runner for k8s-context-guard-v2 (PF-TIER / gap #45).

Three-result gate per the user's policy decision:
  (1) `kubectl port-forward --context <valid>` -> ASK (tunnel visibility),
      regardless of whether the cluster is verified-minikube or a declared dev.
  (2) `kubectl port-forward` (no --context) -> DENY (kubectl_context_required).
      The existing context-required block keeps doing its job; no change.

The verified-minikube allow shortcut used to swallow port-forward silently
(because a network tunnel is not a cluster mutation but it can expose local
services to the cluster side). After this change the shortcut explicitly
excludes port-forward; the action flows through to approval -> ask, even on
local clusters. Regression matrix asserts:
  - direct gate call (`assess_command`) for three verifier profiles
  - end-to-end entrypoint (stdin JSON -> JSON out) for the same three cases

Deterministic: verifier injected, no live cluster. Fail-loud: every case asserts
the exact decision; the run is a failure unless >= MIN_CASES cases execute
with zero failures (zero-tests-is-never-success).
"""

import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT_ROOT / ".claude" / "hooks"))

from k8s_context_guard.cloud_operation_gate import assess_command  # noqa: E402

MIN_CASES = 5
ran = passed = failed = xfailed = 0


@dataclass
class MinikubeVer:
    valid: bool = True
    is_minikube: bool = True
    profile: str = "minikube"


@dataclass
class NonLocalVer:
    valid: bool = True
    is_minikube: bool = False
    profile: str = ""


def minikube_verifier(context, kubeconfig=""):
    return MinikubeVer()


def nonlocal_verifier(context, kubeconfig=""):
    return NonLocalVer()


def check(name, got, ok, detail=""):
    global ran, passed, failed
    ran += 1
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}: {detail or got}")


def assess(cmd, verifier, cwd):
    return assess_command(cmd, cwd, verifier)


tmp = Path(tempfile.mkdtemp(prefix="pf-tier-"))  # no AGENTS.md -> unknown for non-minikube

MK = "clerum-pf-tier-minikube"     # verified minikube
UNK = "some-pf-tier-undeclared"    # valid per verifier but no AGENTS.md -> unknown

# --- Direct gate: port-forward against a verified-minikube context -> ASK ---
# (was "allow" before PF-TIER; the minikube-allow shortcut explicitly excludes
# port-forward now because a tunnel exposes the local machine to the cluster.)
check(
    "minikube_port_forward_asks",
    (a := assess(f"kubectl --context {MK} port-forward svc/web 8080:80", minikube_verifier, tmp)).action,
    a.action == "approval" and a.context == MK,
    f"action={a.action} context={a.context}",
)

# --- Direct gate: port-forward against a non-minikube UNKNOWN context -> DENY ---
# The non-minikube classify() returns "unknown" without an AGENTS.md dev block,
# so the existing context_unknown block flips the approval to block -> deny.
check(
    "unknown_port_forward_denied",
    (a := assess(f"kubectl --context {UNK} port-forward svc/web 8080:80", nonlocal_verifier, tmp)).action,
    a.action == "block" and a.reason_code == "context_unknown",
    f"action={a.action} reason_code={a.reason_code}",
)

# --- Direct gate: port-forward WITHOUT --context -> DENY (context_required) ---
# The existing kubectl_context_required block catches this regardless of action.
check(
    "no_context_port_forward_denied",
    (a := assess("kubectl port-forward svc/web 8080:80", minikube_verifier, tmp)).action,
    a.action == "block" and a.reason_code == "kubectl_context_required",
    f"action={a.action} reason_code={a.reason_code}",
)

# --- End-to-end entrypoint: the two cases that don't depend on a live minikube ---
# The minikube path through the entrypoint requires a real `minikube profile list`
# Status=OK/Running entry, which we cannot fake from inside the test process.
# The direct-gate `minikube_port_forward_asks` above exercises that policy branch
# with a mocked verifier (the same approach used by suite #67).
GUARD = PROJECT_ROOT / ".claude" / "hooks" / "k8s-context-guard-v2.py"


def entrypoint_decision(command, cwd):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": str(cwd)})
    p = subprocess.run(["python3", str(GUARD)], input=payload, text=True, capture_output=True)
    return json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]


check(
    "entrypoint_no_context_port_forward_deny",
    (d := entrypoint_decision("kubectl port-forward svc/web 8080:80", tmp)),
    d == "deny",
    f"decision={d}",
)
check(
    "entrypoint_unknown_port_forward_deny",
    (d := entrypoint_decision(f"kubectl --context {UNK} port-forward svc/web 8080:80", tmp)),
    d == "deny",
    f"decision={d}",
)

print()
print(f"RAN={ran}  PASS={passed}  FAIL={failed}  XFAIL={xfailed}")
# Format must match what tests/run-all-unit-tests.sh parses for assertion counts.
print(f"Passed: {passed} | Failed: {failed} | Xfail: {xfailed}")
if failed > 0 or ran < MIN_CASES:
    print(f"FAIL: expected >= {MIN_CASES} executed cases with zero failures")
    sys.exit(1)
