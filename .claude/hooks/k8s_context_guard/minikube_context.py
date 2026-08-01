from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass

# minikube API servers are ALWAYS local endpoints: 127.0.0.1/localhost (docker & other
# port-forward drivers expose the apiserver on a forwarded localhost port) or an RFC1918
# private IP (bare-metal/VM drivers). A production cluster (GKE/EKS/AKS/DO) never resolves
# to a local endpoint. Requiring a local server is what stops a hand-crafted kubeconfig
# context — named like a minikube profile but pointing at prod — from being mistaken for
# a local cluster.
_LOCAL_HOST = re.compile(r"^(?:127\.0\.0\.1|localhost|::1|0\.0\.0\.0)$", re.IGNORECASE)
_RFC1918 = re.compile(r"^(?:10\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.)")


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


def _is_local_endpoint(server: str) -> bool:
    """True iff the kube API server URL points at a local/private address."""
    match = re.match(r"https?://(\[?[^/:\]]+\]?)", server.strip())
    if not match:
        return False
    host = match.group(1).strip("[]").lower()
    return bool(_LOCAL_HOST.match(host) or _RFC1918.match(host))


def verify_minikube_context(context: str, kubeconfig: str = "") -> ContextVerification:
    """Factually verify whether `context` is a live local minikube cluster.

    A context is verified-minikube iff BOTH hold:
      1. its name is a Status-OK/Running profile in `minikube profile list` (the
         authoritative local-cluster registry — names come from minikube, not a guessed
         pattern), AND
      2. the server URL its kubeconfig resolves to is a LOCAL endpoint.

    Both conditions matter: (1) alone could be spoofed by a kubeconfig context named like
    a profile but pointing elsewhere; (2) rules that out because prod never resolves local.
    Returns valid=False (→ the guard blocks) when the context does not resolve to any
    configured cluster.

    NOTE (codex-port fix): the original compared per-profile `current-context`/`config view`
    via `minikube -p N kubectl -- …`, which does NOT scope to the profile (it reads the
    shared/global kubeconfig) and gated on `Status == "Running"`, a value minikube v1.3x
    never emits (it reports 'OK'). Both bugs made `is_minikube` always False on real minikube.
    """
    if not context:
        return ContextVerification(valid=False, is_minikube=False)

    context_args = ["kubectl"]
    if kubeconfig:
        context_args.extend(["--kubeconfig", kubeconfig])
    context_view = _run(
        *context_args, "config", "view", "--raw", "--minify",
        "--context", context, "-o", "jsonpath={.clusters[0].cluster.server}",
    )
    context_server = context_view.stdout.strip()
    if context_view.returncode != 0 or not context_server:
        # Context does not resolve to a configured cluster -> caller blocks (invalid).
        return ContextVerification(valid=False, is_minikube=False)

    profiles_result = _run("minikube", "profile", "list", "--output=json")
    if profiles_result.returncode != 0:
        return ContextVerification(valid=True, is_minikube=False)
    try:
        profiles = json.loads(profiles_result.stdout).get("valid", [])
    except (AttributeError, json.JSONDecodeError):
        return ContextVerification(valid=True, is_minikube=False)

    active_profiles = {
        str(profile["Name"])
        for profile in profiles
        if isinstance(profile, dict) and profile.get("Name") and profile.get("Status") in {"OK", "Running"}
    }
    if context in active_profiles and _is_local_endpoint(context_server):
        return ContextVerification(valid=True, is_minikube=True, profile=context)
    return ContextVerification(valid=True, is_minikube=False)
