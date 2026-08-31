"""Action-position regression runner for k8s-context-guard-v2 (issue #67).

Two-sided matrix: read verbs win by POSITION over resource aliases
(`kubectl get deploy X` is READ), while real writes keep gating
(`delete deploy` / `helm deploy` / `gcloud app deploy`) and unknown-context
protection stays intact. Deterministic: verifier injected, no live cluster.

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

MIN_CASES = 18
ran = passed = failed = 0


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


tmp = Path(tempfile.mkdtemp(prefix="zc4-issue67-"))  # no AGENTS.md -> unknown context

MK = "clerum-issue-223-acf442ca"   # treated as verified minikube by the injected verifier
UNK = "some-undeclared-remote"

# --- Permissive side: reads win by position even when the resource is a verb alias ---
check(
    "minikube_get_deploy_allowed",
    (a := assess(f"kubectl --context {MK} get deploy web", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_describe_deploy_allowed",
    (a := assess(f"kubectl --context {MK} describe deploy web", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_logs_deploy_slash_allowed",
    (a := assess(f"kubectl --context {MK} logs deploy/web", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_get_deploy_dash_name_allowed",
    (a := assess(f"kubectl --context {MK} get deploy-web", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_top_deploy_allowed",
    (a := assess(f"kubectl --context {MK} top deploy", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_via_wrapper_allowed",
    (a := assess("minikube kubectl -- get deploy nginx", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_rollout_status_read",
    (a := assess(f"kubectl --context {MK} rollout status deploy web", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning == "",
    f"action={a.action} warning={a.warning!r}",
)

# --- Gated side: writes still classified write (warning) and gated off-minikube ---
check(
    "minikube_delete_deploy_classified_write",
    (a := assess(f"kubectl --context {MK} delete deploy web", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning.startswith("verified minikube"),
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_set_image_deploy_classified_write",
    (a := assess(f"kubectl --context {MK} set image deploy/x c=i", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning.startswith("verified minikube"),
    f"action={a.action} warning={a.warning!r}",
)
check(
    "minikube_helm_deploy_classified_write",
    (a := assess(f"helm --kube-context {MK} deploy ./chart", minikube_verifier, tmp)).action,
    a.action == "allow" and a.warning.startswith("verified minikube"),
    f"action={a.action} warning={a.warning!r}",
)
check(
    "unknown_delete_deploy_blocked",
    (a := assess(f"kubectl --context {UNK} delete deploy web", nonlocal_verifier, tmp)).action,
    a.action == "block",
    f"action={a.action} reason_code={a.reason_code}",
)
check(
    "unknown_get_deploy_allowed",
    (a := assess(f"kubectl --context {UNK} get deploy web", nonlocal_verifier, tmp)).action,
    a.action == "allow",
    f"action={a.action} reason_code={a.reason_code}",
)
check(
    "unknown_apply_blocked",
    (a := assess(f"kubectl --context {UNK} apply -f x.yaml", nonlocal_verifier, tmp)).action,
    a.action == "block",
    f"action={a.action} reason_code={a.reason_code}",
)
check(
    "chain_read_then_write_unknown_blocked",
    (a := assess(
        f"kubectl --context {UNK} get deploy web; kubectl --context {UNK} apply -f x.yaml",
        nonlocal_verifier,
        tmp,
    )).action,
    a.action == "block",
    f"action={a.action} reason_code={a.reason_code}",
)
check(
    "helm_deploy_no_context_gated",
    (a := assess("helm deploy ./chart", minikube_verifier, tmp)).action,
    a.action == "approval",
    f"action={a.action}",
)

# --- Real entrypoint (stdin JSON -> JSON out), fail-closed intact without --context ---
GUARD = PROJECT_ROOT / ".claude" / "hooks" / "k8s-context-guard-v2.py"


def entrypoint_decision(command, cwd):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": str(cwd)})
    p = subprocess.run(["python3", str(GUARD)], input=payload, text=True, capture_output=True)
    return json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]


check(
    "entrypoint_get_deploy_no_context_denied",
    (d := entrypoint_decision("kubectl get deploy web", tmp)),
    d == "deny",
    f"decision={d}",
)
check(
    "entrypoint_delete_deploy_no_context_denied",
    (d := entrypoint_decision("kubectl delete deploy web", tmp)),
    d == "deny",
    f"decision={d}",
)

# --- gcloud: git-safety-guard.py domain; must stay gated (deny or ask, never allow) ---
GIT_GUARD = PROJECT_ROOT / ".claude" / "hooks" / "git-safety-guard.py"
env = {k: v for k, v in os.environ.items() if "DESTRUCTIVE_CONFIRMED" not in k}
payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "gcloud app deploy app.yaml"}, "cwd": "/tmp"})
p = subprocess.run(["python3", str(GIT_GUARD)], input=payload, text=True, capture_output=True, env=env)
gd = json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]
check("gcloud_app_deploy_not_allowed", gd, gd in {"deny", "ask"}, f"decision={gd}")

print()
print(f"RAN={ran}  PASS={passed}  FAIL={failed}")
if failed > 0 or ran < MIN_CASES:
    print(f"FAIL: expected >= {MIN_CASES} executed cases with zero failures")
    sys.exit(1)
