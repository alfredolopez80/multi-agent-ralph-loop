#!/usr/bin/env python3
"""k8s-context-guard-v2 — contextual PreToolUse/Bash guard for kubectl/helm/minikube.

Claude Code port of the codex-ralph-vault-loop context guard. Owns the kube-context
domain only (aws/gcloud/terraform stay with git-safety-guard.py). Emits the modern
PreToolUse contract: hookSpecificOutput.permissionDecision ∈ {allow, ask, deny}.

I/O contract (mirrors git-safety-guard.py):
  stdin  = hook input JSON: tool_name, tool_input.command, cwd
  stdout = {"hookSpecificOutput": {"hookEventName":"PreToolUse","permissionDecision": ...}}
  exit   = 0 for allow/ask, non-zero for deny (both still print JSON)

Fail-closed: unparsable input or any evaluation error -> deny (never allow).
Named "-v2" with a distinct HOOK_NAME so it can never be confused with the retired
sagart/legacy `k8s-context-guard` (identical-name twins were a diagnostic trap).
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

HOOK_NAME = "k8s-context-guard-v2"

_HOOKS_DIR = os.path.dirname(os.path.realpath(__file__))
if _HOOKS_DIR not in sys.path:
    sys.path.insert(0, _HOOKS_DIR)

from k8s_context_guard.cloud_operation_gate import CommandAssessment, assess_command  # noqa: E402
from k8s_context_guard.context_classification import classify  # noqa: E402


def _log(message: str) -> None:
    """Best-effort audit log. A logging failure must NEVER suppress the security
    decision, so its errors are swallowed here by explicit design — this isolates
    logging, it does not mask a guard failure (the guard itself is fail-closed)."""
    try:
        logdir = Path.home() / ".ralph" / "logs"
        logdir.mkdir(parents=True, exist_ok=True)
        with (logdir / "k8s-context-guard.log").open("a", encoding="utf-8") as handle:
            handle.write(message + "\n")
    except OSError:
        pass


def _emit(decision: str, reason: str = "") -> None:
    payload: dict[str, object] = {
        "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": decision}
    }
    if reason:
        payload["hookSpecificOutput"]["permissionDecisionReason"] = reason  # type: ignore[index]
    print(json.dumps(payload))


def _decide(assessment: CommandAssessment, cwd: Path) -> tuple[str, str]:
    """Map a CommandAssessment to (permissionDecision, reason)."""
    if assessment.action == "block":
        code = f" [{assessment.reason_code}]" if assessment.reason_code else ""
        return "deny", f"{HOOK_NAME}: {assessment.reason or 'blocked cluster operation'}{code}"

    if assessment.action == "allow":
        return "allow", ""

    # action == "approval"
    if assessment.profile:
        # Verified minikube, but a complete deletion (--all/-A/ns/node/crd/-f).
        return "ask", (
            f"{HOOK_NAME}: complete deletion on verified minikube '{assessment.context}' "
            f"({assessment.consequence or 'delete a complete scope'}) — confirm."
        )

    if assessment.context:
        # kubectl against a non-minikube context: classify by declared lists / memory.
        kind = classify(assessment.context, cwd)
        if kind in ("prod", "unknown"):
            detail = "declared/obvious prod" if kind == "prod" else "not verified-minikube and not declared dev"
            return "deny", f"{HOOK_NAME}: context '{assessment.context}' is {kind} ({detail}) — denied."
        # dev (declared) or memory (low-confidence hit) -> confirm with the user.
        return "ask", f"{HOOK_NAME}: context '{assessment.context}' classified '{kind}' — confirm."

    # approval without a kube context (helm/minikube write) -> confirm.
    return "ask", (
        f"{HOOK_NAME}: {assessment.tool} write ({assessment.consequence or 'mutate cluster state'}) — confirm."
    )


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        _emit("deny", f"{HOOK_NAME}: could not parse hook input (fail-closed).")
        return 1

    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        _emit("allow")
        return 0

    tool_input = payload.get("tool_input") or {}
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not command or not command.strip():
        _emit("allow")
        return 0

    cwd = Path(payload.get("cwd") or os.getcwd())

    try:
        assessment = assess_command(command, cwd)
        decision, reason = _decide(assessment, cwd)
    except Exception as exc:  # noqa: BLE001 - fail-closed on ANY evaluation error
        _log(f"ERROR evaluating command (fail-closed to deny): {exc!r} :: {command}")
        _emit("deny", f"{HOOK_NAME}: guard failed to evaluate the command (fail-closed).")
        return 1

    _log(f"{decision}: ctx={assessment.context!r} profile={assessment.profile!r} "
         f"action={assessment.action} :: {command}")
    _emit(decision, reason)
    return 0 if decision in ("allow", "ask") else 1


if __name__ == "__main__":
    sys.exit(main())
