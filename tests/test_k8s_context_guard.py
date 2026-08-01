"""Unit tests for the k8s-context-guard-v2 hook.

Covers the decision model with `verify_minikube_context` injected (no real cluster),
plus dev/prod classification against an AGENTS.md fixture and the low-confidence
memory layer. Fail-loud: pytest fails on any assertion; the runner additionally
treats "0 tests collected" as failure (zero-tests-is-never-success).
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
HOOKS_DIR = REPO_ROOT / ".claude" / "hooks"
sys.path.insert(0, str(HOOKS_DIR))

from k8s_context_guard import context_classification as cc  # noqa: E402
from k8s_context_guard.cloud_operation_gate import CommandAssessment, assess_command  # noqa: E402
from k8s_context_guard.minikube_context import ContextVerification  # noqa: E402


def _load_entrypoint():
    """Import the guard entrypoint (hyphenated filename) for _decide/_emit access."""
    spec = importlib.util.spec_from_file_location(
        "k8s_guard_entry", HOOKS_DIR / "k8s-context-guard-v2.py"
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ENTRY = _load_entrypoint()

CLERUM_PROD = "gke_eventfire-491421_us-central1-a_clerum"
CLERUM_DEV = "gke_eventfire-491421_us-central1-a_clerum-dev"
MINIKUBE_CTX = "clerum-issue-223-acf442ca"


def make_verifier(minikube_contexts: set[str], invalid: set[str] | None = None):
    invalid = invalid or set()

    def verify(context: str, kubeconfig: str = "") -> ContextVerification:
        if context in invalid:
            return ContextVerification(valid=False, is_minikube=False)
        if context in minikube_contexts:
            return ContextVerification(valid=True, is_minikube=True, profile=f"profile-{context}")
        return ContextVerification(valid=True, is_minikube=False)

    return verify


@pytest.fixture
def agents_cwd(tmp_path: Path) -> Path:
    (tmp_path / "AGENTS.md").write_text(
        "# AGENTS\n\nsome prose\n\n"
        "<!-- k8s-guard:begin -->\n"
        "kube_contexts:\n"
        "  dev:\n"
        f"    - {CLERUM_DEV}\n"
        "    - e2e-clerum-dev\n"
        "  prod:\n"
        f"    - {CLERUM_PROD}\n"
        "<!-- k8s-guard:end -->\n",
        encoding="utf-8",
    )
    return tmp_path


# --- assess_command (with injected verifier) --------------------------------

def test_minikube_apply_allows(tmp_path):
    verifier = make_verifier({MINIKUBE_CTX})
    a = assess_command(f"kubectl --context={MINIKUBE_CTX} apply -f svc.yaml", tmp_path, verifier)
    assert a.action == "allow"
    assert a.profile == f"profile-{MINIKUBE_CTX}"


def test_minikube_complete_delete_is_approval(tmp_path):
    verifier = make_verifier({MINIKUBE_CTX})
    a = assess_command(f"kubectl --context={MINIKUBE_CTX} delete --all -n test", tmp_path, verifier)
    assert a.action == "approval"
    assert a.profile == f"profile-{MINIKUBE_CTX}"  # still known-minikube -> maps to ask


def test_non_minikube_apply_is_approval_with_context(tmp_path):
    verifier = make_verifier(set())
    a = assess_command(f"kubectl --context={CLERUM_PROD} apply -f x.yaml", tmp_path, verifier)
    assert a.action == "approval"
    assert a.context == CLERUM_PROD
    assert a.profile == ""


def test_kubectl_without_context_blocks(tmp_path):
    verifier = make_verifier({MINIKUBE_CTX})
    a = assess_command("kubectl apply -f x.yaml", tmp_path, verifier)
    assert a.action == "block"
    assert a.reason_code == "kubectl_context_required"


def test_kubectl_dynamic_context_blocks(tmp_path):
    verifier = make_verifier({MINIKUBE_CTX})
    a = assess_command('kubectl --context="$(cat ctx)" apply -f x.yaml', tmp_path, verifier)
    assert a.action == "block"
    assert a.reason_code == "kubectl_context_not_static"


def test_read_on_prod_allows(tmp_path):
    verifier = make_verifier(set())
    a = assess_command(f"kubectl --context={CLERUM_PROD} get pods -n foo", tmp_path, verifier)
    assert a.action == "allow"


def test_script_with_internal_apply_to_prod(tmp_path):
    script = tmp_path / "deploy.sh"
    script.write_text(f"#!/bin/bash\nkubectl --context={CLERUM_PROD} apply -f x.yaml\n", encoding="utf-8")
    script.chmod(0o755)
    verifier = make_verifier(set())
    a = assess_command(f"bash {script}", tmp_path, verifier)
    assert a.action == "approval"
    assert a.context == CLERUM_PROD


def test_script_with_internal_apply_to_minikube(tmp_path):
    script = tmp_path / "deploy.sh"
    script.write_text(f"#!/bin/bash\nkubectl --context={MINIKUBE_CTX} apply -f x.yaml\n", encoding="utf-8")
    script.chmod(0o755)
    verifier = make_verifier({MINIKUBE_CTX})
    a = assess_command(f"bash {script}", tmp_path, verifier)
    assert a.action == "allow"


# --- classify (AGENTS.md lists + obvious-prod + memory) ---------------------

def test_exact_match_prod_vs_dev(agents_cwd):
    assert cc.classify(CLERUM_PROD, agents_cwd) == "prod"
    assert cc.classify(CLERUM_DEV, agents_cwd) == "dev"


def test_prefix_does_not_cross_capture(agents_cwd):
    # `...clerum` (prod) is a prefix of `...clerum-dev` (dev): exact match must keep them apart.
    assert cc.classify(CLERUM_PROD, agents_cwd) != "dev"
    assert cc.classify(CLERUM_DEV, agents_cwd) != "prod"


def test_obvious_prod_pattern():
    assert cc.is_obvious_prod("gke_x_europe-west1_infra-prod")
    assert cc.is_obvious_prod("arn:aws:eks:us-east-1:123:cluster/foo")
    assert not cc.is_obvious_prod(CLERUM_PROD)  # no 'prod' token -> relies on the list
    assert not cc.is_obvious_prod(CLERUM_DEV)


def test_undeclared_remote_is_unknown(agents_cwd):
    assert cc.classify("gke_other_region_something", agents_cwd) == "unknown"


def test_memory_elevates_unknown_to_memory(agents_cwd, tmp_path, monkeypatch):
    mem = tmp_path / "mem.json"
    mem.write_text(json.dumps({"contexts": {"gke_other_region_something": {"clarified_as": "dev"}}}), encoding="utf-8")
    monkeypatch.setattr(cc, "_MEMORY_PATH", mem)
    assert cc.classify("gke_other_region_something", agents_cwd) == "memory"


def test_memory_never_degrades_prod(agents_cwd, tmp_path, monkeypatch):
    mem = tmp_path / "mem.json"
    mem.write_text(json.dumps({"contexts": {"gke_x_infra-prod": {"clarified_as": "dev"}}}), encoding="utf-8")
    monkeypatch.setattr(cc, "_MEMORY_PATH", mem)
    assert cc.classify("gke_x_infra-prod", agents_cwd) == "prod"  # obvious-prod wins over memory


# --- _decide mapping (entrypoint) -------------------------------------------

def test_decide_block_to_deny(tmp_path):
    d, _ = ENTRY._decide(CommandAssessment(action="block", reason="x", reason_code="c"), tmp_path)
    assert d == "deny"


def test_decide_allow(tmp_path):
    d, _ = ENTRY._decide(CommandAssessment(action="allow", tool="kubectl"), tmp_path)
    assert d == "allow"


def test_decide_minikube_complete_delete_to_ask(tmp_path):
    d, _ = ENTRY._decide(
        CommandAssessment(action="approval", context=MINIKUBE_CTX, profile=f"profile-{MINIKUBE_CTX}"), tmp_path
    )
    assert d == "ask"


def test_decide_prod_to_deny(agents_cwd):
    d, _ = ENTRY._decide(CommandAssessment(action="approval", context=CLERUM_PROD, tool="kubectl"), agents_cwd)
    assert d == "deny"


def test_decide_dev_to_ask(agents_cwd):
    d, _ = ENTRY._decide(CommandAssessment(action="approval", context=CLERUM_DEV, tool="kubectl"), agents_cwd)
    assert d == "ask"


def test_decide_unknown_to_deny(agents_cwd):
    d, _ = ENTRY._decide(CommandAssessment(action="approval", context="gke_nope", tool="kubectl"), agents_cwd)
    assert d == "deny"


def test_decide_helm_write_without_context_to_ask(tmp_path):
    d, _ = ENTRY._decide(CommandAssessment(action="approval", tool="helm", consequence="install"), tmp_path)
    assert d == "ask"


# --- output shape ------------------------------------------------------------

def test_emit_shape(capsys):
    ENTRY._emit("deny", "because")
    out = json.loads(capsys.readouterr().out)
    hso = out["hookSpecificOutput"]
    assert hso["hookEventName"] == "PreToolUse"
    assert hso["permissionDecision"] == "deny"
    assert hso["permissionDecisionReason"] == "because"
    # never the Stop-style shape
    assert "decision" not in out
    assert "decision" not in hso


def test_emit_allow_has_no_reason(capsys):
    ENTRY._emit("allow")
    out = json.loads(capsys.readouterr().out)
    assert out["hookSpecificOutput"]["permissionDecision"] == "allow"
    assert "permissionDecisionReason" not in out["hookSpecificOutput"]
