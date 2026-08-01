from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass


@dataclass(frozen=True)
class ContextVerification:
    valid: bool
    is_minikube: bool
    profile: str = ""


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(args, text=True, capture_output=True, check=False, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return subprocess.CompletedProcess(args, 1, "", "")


def verify_minikube_context(context: str, kubeconfig: str = "") -> ContextVerification:
    context_args = ["kubectl"]
    if kubeconfig:
        context_args.extend(["--kubeconfig", kubeconfig])
    context_view = _run(
        *context_args,
        "config",
        "view",
        "--raw",
        "--minify",
        "--context",
        context,
        "-o",
        "jsonpath={.clusters[0].cluster.server}",
    )
    context_server = context_view.stdout.strip()
    if context_view.returncode != 0 or not context_server:
        return ContextVerification(valid=False, is_minikube=False)

    profiles_result = _run("minikube", "profile", "list", "--output=json")
    if profiles_result.returncode != 0:
        return ContextVerification(valid=True, is_minikube=False)
    try:
        profiles = json.loads(profiles_result.stdout).get("valid", [])
    except (AttributeError, json.JSONDecodeError):
        return ContextVerification(valid=True, is_minikube=False)

    for item in profiles:
        if not isinstance(item, dict) or item.get("Status") != "Running" or not item.get("Name"):
            continue
        profile = str(item["Name"])
        profile_context = _run("minikube", "-p", profile, "kubectl", "--", "config", "current-context")
        if profile_context.returncode != 0 or profile_context.stdout.strip() != context:
            continue
        profile_server = _run(
            "minikube",
            "-p",
            profile,
            "kubectl",
            "--",
            "config",
            "view",
            "--raw",
            "--minify",
            "-o",
            "jsonpath={.clusters[0].cluster.server}",
        )
        if profile_server.returncode == 0 and profile_server.stdout.strip() == context_server:
            return ContextVerification(valid=True, is_minikube=True, profile=profile)
    return ContextVerification(valid=True, is_minikube=False)
