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
from k8s_context_guard.minikube_context import ContextVerification, _is_local_endpoint  # noqa: E402


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


def test_non_minikube_undeclared_apply_blocks(tmp_path):
    # non-minikube + undeclared context (no AGENTS.md) -> unknown -> block (fail-closed);
    # the gate now encapsulates the prod/unknown verdict so _choose can pick it in a chain.
    verifier = make_verifier(set())
    a = assess_command(f"kubectl --context={CLERUM_PROD} apply -f x.yaml", tmp_path, verifier)
    assert a.action == "block"
    assert a.context == CLERUM_PROD


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
    assert a.action == "block"   # undeclared prod-ish context -> unknown -> block
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


# --- hardening regression: wrapper / alt-shell / command-substitution must NOT bypass ---

@pytest.mark.parametrize("wrapper", ["sudo", "timeout 30", "nice -n5", "nohup", "command", "eval", "time", "setsid", "stdbuf -oL"])
def test_wrapper_prefix_does_not_bypass_prod(wrapper, tmp_path):
    a = assess_command(f"{wrapper} kubectl --context={CLERUM_PROD} delete namespace foo", tmp_path, make_verifier(set()))
    assert a.action in ("approval", "block"), f"{wrapper} leaked to allow"


@pytest.mark.parametrize("shell", ["dash", "ksh", "fish", "ash"])
def test_opaque_shell_does_not_bypass(shell, tmp_path):
    a = assess_command(f'{shell} -c "kubectl --context={CLERUM_PROD} delete ns foo"', tmp_path, make_verifier(set()))
    assert a.action == "approval"


@pytest.mark.parametrize("cmd", [
    "X=$(kubectl --context={ctx} delete namespace foo)",
    "echo `kubectl --context={ctx} delete ns foo`",
    "cat <(kubectl --context={ctx} delete ns foo)",   # process substitution
    "tee >(kubectl --context={ctx} delete ns foo)",
])
def test_command_substitution_does_not_bypass(cmd, tmp_path):
    a = assess_command(cmd.format(ctx=CLERUM_PROD), tmp_path, make_verifier(set()))
    assert a.action == "approval"


@pytest.mark.parametrize("server,is_local", [
    ("https://127.0.0.1:63791", True),
    ("https://192.168.58.2:8443", True),
    ("https://[::1]:8443", True),
    ("https://127.0.0.1.evil.com:8443", False),   # suffix spoof
    ("https://10.0.0.1@evil.com", False),          # userinfo spoof
    ("https://34.120.0.1", False),                 # public IP
    ("https://myprod.example.com", False),         # public host
])
def test_is_local_endpoint_rejects_spoofs(server, is_local):
    assert _is_local_endpoint(server) is is_local


def test_wrapper_on_minikube_read_still_allows(tmp_path):
    a = assess_command(f"sudo kubectl --context={MINIKUBE_CTX} get pods", tmp_path, make_verifier({MINIKUBE_CTX}))
    assert a.action == "allow"


@pytest.mark.parametrize("cmd", [
    "time -p kubectl --context={ctx} delete namespace foo",       # -p boolean for time
    "command -p kubectl --context={ctx} delete namespace foo",    # -p boolean for command
    "doas -n kubectl --context={ctx} delete namespace foo",       # -n boolean for doas
    "setsid -c kubectl --context={ctx} delete namespace foo",     # -c boolean for setsid
    "watch kubectl --context={ctx} delete namespace foo",         # no leading positional
    "sudo -u root kubectl --context={ctx} delete namespace foo",  # -u takes a value -> approval
    "nice -n 5 kubectl --context={ctx} delete namespace foo",     # -n takes a value -> approval
    "sudo nice timeout 30 kubectl --context={ctx} delete namespace foo",  # nested wrappers
])
def test_wrapper_flag_edge_cases_do_not_bypass(cmd, tmp_path):
    a = assess_command(cmd.format(ctx=CLERUM_PROD), tmp_path, make_verifier(set()))
    assert a.action in ("approval", "block"), f"leaked: {cmd}"


def test_wrapper_boolean_flag_still_reaches_tool(tmp_path):
    # a genuinely-boolean flag must be skipped so a legit minikube read still allows
    a = assess_command(f"time -p kubectl --context={MINIKUBE_CTX} get pods", tmp_path, make_verifier({MINIKUBE_CTX}))
    assert a.action == "allow"


# --- pv/pvc/node complete-deletion -> ask even on verified minikube (fix #6) ---

@pytest.mark.parametrize("resource", ["pv", "pvc", "persistentvolume", "persistentvolumeclaim", "no", "node"])
def test_high_blast_deletion_asks_on_minikube(resource, tmp_path):
    a = assess_command(f"kubectl --context={MINIKUBE_CTX} delete {resource} x", tmp_path, make_verifier({MINIKUBE_CTX}))
    assert a.action == "approval", f"delete {resource} should ask even on minikube"


# --- helm / minikube context routing (fix #4) ---

def test_helm_write_to_prod_is_denied(agents_cwd):
    a = assess_command(f"helm uninstall app --kube-context {CLERUM_PROD}", agents_cwd, make_verifier(set()))
    assert a.action == "block" and a.context == CLERUM_PROD  # prod declared -> gate blocks
    assert ENTRY._decide(a, agents_cwd)[0] == "deny"


def test_helm_read_allows(tmp_path):
    a = assess_command("helm list --kube-context anything", tmp_path, make_verifier(set()))
    assert a.action == "allow"


def test_minikube_write_is_ask(tmp_path):
    a = assess_command("minikube delete -p clerum-x", tmp_path, make_verifier(set()))
    assert a.action == "approval"
    assert ENTRY._decide(a, tmp_path)[0] == "ask"


# --- parser: an item ending in ':' must not drop the rest of the section (fix #7) ---

def test_agents_parser_item_with_colon_preserves_section(tmp_path):
    (tmp_path / "AGENTS.md").write_text(
        "<!-- k8s-guard:begin -->\nprod:\n  - ctx-a:\n  - real-prod-ctx\n<!-- k8s-guard:end -->\n",
        encoding="utf-8",
    )
    _dev, prod = cc.load_context_lists(tmp_path)
    assert "real-prod-ctx" in prod


# --- corrupt memory / unparseable command / _choose precedence ---

def test_corrupt_memory_is_deny(agents_cwd, tmp_path, monkeypatch):
    mem = tmp_path / "mem.json"
    mem.write_text("{not valid json", encoding="utf-8")
    monkeypatch.setattr(cc, "_MEMORY_PATH", mem)
    assert cc.classify("gke_totally_unknown", agents_cwd) == "unknown"


def test_unparseable_command_is_ask(tmp_path):
    a = assess_command('kubectl --context="oops apply', tmp_path, make_verifier(set()))
    assert a.action == "approval"


def test_choose_prefers_destructive_prod_across_segments(tmp_path):
    a = assess_command(
        f"kubectl --context={CLERUM_PROD} delete deploy x && kubectl --context={MINIKUBE_CTX} get pods",
        tmp_path, make_verifier({MINIKUBE_CTX}),
    )
    assert a.action in ("approval", "block") and a.context == CLERUM_PROD


def test_chain_prod_mutation_wins_over_dev(agents_cwd):
    # prod apply + dev delete in one chain: the prod verdict (deny) must win over dev's ask,
    # even though the dev segment is more "destructive" by verb (Codex P1 #4).
    a = assess_command(
        f"kubectl --context={CLERUM_PROD} apply -f x.yaml && kubectl --context={CLERUM_DEV} delete pod y",
        agents_cwd, make_verifier(set()),
    )
    assert a.action == "block"
    assert ENTRY._decide(a, agents_cwd)[0] == "deny"


def test_main_deny_returns_exit_zero(monkeypatch, capsys):
    # A deny must exit 0 so the JSON permissionDecision actually blocks (Codex P1 #1).
    import io
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "kubectl apply -f x.yaml"}, "cwd": "/tmp"})
    monkeypatch.setattr("sys.stdin", io.StringIO(payload))
    rc = ENTRY.main()
    out = json.loads(capsys.readouterr().out)
    assert out["hookSpecificOutput"]["permissionDecision"] == "deny"  # no --context -> deny
    assert rc == 0
