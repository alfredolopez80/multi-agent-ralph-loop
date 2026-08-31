from __future__ import annotations

import re
import shlex
from collections.abc import Callable
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Literal

from .context_classification import classify
from .minikube_context import ContextVerification, verify_minikube_context
from .script_operation_inspector import script_cloud_commands, script_path, wrapper_script_path

# NOTE: restricted from codex's {aws, gcloud, helm, kubectl, minikube, terraform}.
# This guard owns only the kube-context domain; aws/gcloud/terraform stay with
# git-safety-guard.py (disjoint frontiers -> no double-decision). kustomize is
# intentionally excluded: `kustomize build` is read-only and never touches a cluster.
CLOUD_TOOLS = {"helm", "kubectl", "minikube"}
_CLOUD_TOOL_ALT = "|".join(re.escape(name) for name in sorted(CLOUD_TOOLS))  # derived; keeps the substitution scan in sync
READ_ACTIONS = {
    "api-resources", "api-versions", "can-i", "cluster-info", "describe", "diff", "explain", "get",
    "get-contexts", "head", "history", "info", "list", "logs", "ls", "output", "plan", "providers",
    "search", "show", "status", "template", "top", "validate", "version", "view", "whoami",
}
DESTRUCTIVE_ACTIONS = {"delete", "destroy", "drain", "drop", "purge", "remove", "rm", "terminate", "uninstall", "wipe"}
MUTATING_ACTIONS = {
    "add", "annotate", "apply", "attach", "autoscale", "cordon", "cp", "create", "deploy", "detach",
    "edit", "expose", "import", "install", "label", "move", "mv", "patch", "put", "replace", "restart",
    "restore", "resume", "rollback", "rollout", "scale", "set", "start", "stop", "submit", "suspend",
    "taint", "uncordon", "update", "upgrade", "use-context",
}
COMPLETE_KUBERNETES_RESOURCES = {
    "cluster", "clusters", "crd", "customresourcedefinition", "customresourcedefinitions", "namespace",
    "namespaces", "node", "nodes", "no", "ns",
    # PV/PVC deletion can reclaim/destroy underlying data — high blast radius even on minikube.
    "pv", "persistentvolume", "persistentvolumes", "pvc", "persistentvolumeclaim", "persistentvolumeclaims",
}

# Command-prefix wrappers to peel off before tool classification, mirroring the PR-#31
# hardening in git-safety-guard.py. A leading `sudo`/`timeout`/`nice`/… must NOT smuggle a
# cloud tool past the guard (it would otherwise be classified as an opaque non-cloud tool
# and silently allowed). Value-taking options and leading positional values are consumed.
_WRAPPERS = {
    "sudo", "doas", "command", "nice", "ionice", "nohup", "setsid", "stdbuf", "time", "timeout", "watch", "chrt",
}
# Per-wrapper BOOLEAN (no-value) flags. Option arity differs per CLI (`-p` is boolean for
# `time`/`command` but value-taking for `chrt`; `-n` is boolean for `doas` but value-taking
# for `nice`/`ionice`; `-c` is boolean for `setsid` but value-taking for `ionice`), so a
# single shared table is WRONG and mis-skips the real tool. We enumerate only the safe
# boolean flags; ANY other option makes the peel un-inspectable -> approval (fail-closed),
# never a guessed skip that could swallow the tool token.
_WRAPPER_BOOLEAN_OPTS: dict[str, set[str]] = {
    "sudo": {"-A", "-b", "-E", "-H", "-i", "-K", "-k", "-n", "-S", "-s", "-v"},
    "doas": {"-n", "-s"},
    "command": {"-p", "-v", "-V"},
    "nice": set(),      # only option is `-n VALUE`
    "ionice": set(),    # `-c/-n/-p` all take values
    "nohup": set(),
    "setsid": {"-c", "-f", "-w"},
    "stdbuf": set(),    # `-i/-o/-e` take values
    "time": {"-p", "-v"},
    "timeout": set(),   # `-s/-k` take values; leading DURATION handled below
    "watch": set(),     # interval is `-n SECONDS`, never a leading positional
    "chrt": set(),
}
_WRAPPERS_LEADING_VALUE = {"timeout"}  # `timeout DURATION COMMAND` — first positional is a value
# Shells whose `-c` payload this guard does NOT parse (only bash/sh/zsh are inspected). An
# opaque shell hides a cloud command -> require approval instead of silent allow.
_OPAQUE_SHELLS = {"dash", "ksh", "fish", "ash", "csh", "tcsh", "rbash"}


def _strip_command_wrappers(parts: list[str]) -> tuple[list[str], bool]:
    """Peel leading command-prefix wrappers (sudo/timeout/nice/…) to reach the real tool.

    Returns (stripped_parts, uninspectable). `uninspectable=True` when the peel cannot
    continue safely — `eval`, or an option we cannot prove is boolean (guessing its arity
    could swallow the tool token, e.g. `sudo -u root kubectl …` or `nice -n 5 kubectl …`).
    The caller then requires approval rather than allow.
    """
    index = 0
    while index < len(parts):
        tool = _tool(parts[index])
        if tool == "eval":
            return parts[index:], True
        if tool not in _WRAPPERS:
            break
        boolean_opts = _WRAPPER_BOOLEAN_OPTS.get(tool, set())
        index += 1
        if tool in _WRAPPERS_LEADING_VALUE and index < len(parts) and not parts[index].startswith("-"):
            index += 1  # consume the leading DURATION positional
        while index < len(parts) and parts[index].startswith("-"):
            option = parts[index].split("=", 1)[0]
            if "=" in parts[index] or option in boolean_opts:
                index += 1
                continue
            # Unknown option that may take a value: refuse to guess -> un-inspectable.
            return parts[index:], True
    return parts[index:], False


@dataclass(frozen=True)
class CommandAssessment:
    action: Literal["allow", "approval", "block"]
    reason_code: str = ""
    reason: str = ""
    risk_level: str = ""
    tool: str = ""
    consequence: str = ""
    context: str = ""
    profile: str = ""
    warning: str = ""
    approval_subject: str = ""


ContextVerifier = Callable[[str, str], ContextVerification]


def _tool(value: str) -> str:
    return Path(value).name.lower()


def _segments(command: str) -> list[list[str]]:
    normalized: list[str] = []
    quote = ""
    escaped = False
    for char in command:
        if escaped:
            normalized.append(char)
            escaped = False
            continue
        if char == "\\" and quote != "'":
            normalized.append(char)
            escaped = True
            continue
        if char in {"'", '"'}:
            quote = "" if quote == char else quote or char
        normalized.append(";" if char == "\n" and not quote else char)
    lexer = shlex.shlex("".join(normalized), posix=True, punctuation_chars=";&|")
    lexer.whitespace_split = True
    segments: list[list[str]] = []
    current: list[str] = []
    for piece in lexer:
        if piece and all(char in ";&|" for char in piece):
            if current:
                segments.append(current)
                current = []
            continue
        current.append(piece)
    if current:
        segments.append(current)
    return segments


def _without_environment(parts: list[str]) -> list[str]:
    if not parts:
        return parts
    index = 1 if _tool(parts[0]) == "env" else 0
    value_options = {"-u", "--unset", "-C", "--chdir", "-S", "--split-string", "-a", "--argv0"}
    while index < len(parts) and _tool(parts[0]) == "env":
        part = parts[index]
        option = part.split("=", 1)[0]
        if option in value_options:
            index += 1 if "=" in part else 2
            continue
        if part.startswith("-"):
            index += 1
            continue
        if "=" not in part:
            break
        index += 1
    while index < len(parts) and "=" in parts[index] and not parts[index].startswith("-"):
        index += 1
    return parts[index:]


def _environment_value(parts: list[str], name: str) -> str:
    prefix = name + "="
    for part in parts:
        if part.startswith(prefix):
            return part.split("=", 1)[1]
        if _tool(part) in CLOUD_TOOLS:
            break
    return ""


def _context(parts: list[str]) -> str:
    for index, part in enumerate(parts):
        if part == "--context" and index + 1 < len(parts):
            return parts[index + 1]
        if part.startswith("--context="):
            return part.split("=", 1)[1]
    return ""


def _option(parts: list[str], name: str) -> str:
    for index, part in enumerate(parts):
        if part == name and index + 1 < len(parts):
            return parts[index + 1]
        if part.startswith(name + "="):
            return part.split("=", 1)[1]
    return ""


def _words(parts: list[str]) -> list[str]:
    return [Path(part).name.lower().replace("_", "-") for part in parts[1:] if part and not part.startswith("-")]


def _kubectl_complete_deletion(parts: list[str]) -> bool:
    operands_with_action = [part.lower().replace("_", "-") for part in parts[1:] if part and not part.startswith("-")]
    if "delete" not in operands_with_action:
        return False
    operands = operands_with_action[operands_with_action.index("delete") + 1 :]
    return (
        "--all" in parts
        or "--all-namespaces" in parts
        or "-A" in parts
        or any(resource.split("/", 1)[0] in COMPLETE_KUBERNETES_RESOURCES for resource in operands)
        or any(
            part in {"-f", "--filename", "-k", "--kustomize"}
            or part.startswith(("--filename=", "--kustomize="))
            for part in parts
        )
    )


def _classify_words(parts: list[str]) -> tuple[str, str]:
    words = _words(parts)
    if any(words[index : index + 2] == ["rollout", "status"] for index in range(len(words) - 1)):
        return ("read", "")
    # Classify by ACTION POSITION, not global token membership (issue #67): these CLIs
    # place the verb in the first sub-command slot and resource aliases after it, so a
    # token like `deploy` following a read verb (`kubectl get deploy X`) is a resource
    # name, not a helm/gcloud write. Scanning left-to-right and stopping at the FIRST
    # word that matches a known action keeps those reads READ while `helm deploy` and
    # `kubectl delete deploy X` still gate on their real first-position verb.
    for word in words:
        if any(word == action or word.startswith(action + "-") for action in DESTRUCTIVE_ACTIONS):
            return ("destructive", word)
        if any(word == action or word.startswith(action + "-") for action in MUTATING_ACTIONS):
            return ("mutating", word)
        if word in READ_ACTIONS or word.startswith(("describe-", "get-", "list-", "head-")):
            return ("read", "")
    return ("mutating", "unclassified")


def _shell_command(parts: list[str]) -> str:
    for index, part in enumerate(parts[1:], start=1):
        if part.startswith("-") and not part.startswith("--") and part[1:].isalpha() and "c" in part[1:]:
            return parts[index + 1] if index + 1 < len(parts) else ""
    return ""


def _rewrites_inspected_script(command: str, scripts: list[Path], cwd: Path) -> bool:
    for match in re.finditer(r">{1,2}\s*([^\s;&|]+)", command):
        raw_target = match.group(1).strip("'\"")
        target = Path(raw_target).expanduser()
        target = target if target.is_absolute() else cwd / target
        if target.resolve(strict=False) in scripts:
            return True
    return False


def _approval(tool: str, risk: str, consequence: str) -> CommandAssessment:
    return CommandAssessment(
        action="approval",
        reason_code="cloud_command_approval_required",
        risk_level=risk,
        tool=tool,
        consequence=consequence,
    )


def _assess_cloud_parts(
    parts: list[str],
    verifier: ContextVerifier,
    kubeconfig: str = "",
    cwd: Path | None = None,
) -> CommandAssessment:
    # Path.cwd() must be resolved per-call, NOT baked into the default arg at import time.
    if cwd is None:
        cwd = Path.cwd()
    tool = _tool(parts[0])
    risk, operation = _classify_words(parts)

    if tool == "minikube":
        # minikube only ever targets LOCAL profiles; a read is safe, a write (delete/stop/
        # pause) affects a local cluster -> ask (profile set so the entrypoint maps to ask).
        if risk == "read":
            return CommandAssessment(action="allow", tool=tool)
        profile = _option(parts, "--profile") or _option(parts, "-p")
        return replace(_approval(tool, risk, f"{operation} a local minikube profile"), profile=profile or "minikube")

    if tool not in {"kubectl", "helm"}:
        if risk == "read":
            return CommandAssessment(action="allow", tool=tool)
        return _approval(tool, risk, f"{operation} cluster or cloud state")

    # kubectl (--context) and helm (--kube-context) both name their target cluster; verify
    # the declared context the same way so helm writes against prod are DENIED, not just asked.
    context = _context(parts) if tool == "kubectl" else _option(parts, "--kube-context")
    if not context:
        if tool == "helm":
            # helm without --kube-context uses the ambient current-context — unknowable
            # statically -> approval (never silent allow). R3 (default-context) backstop.
            if risk == "read":
                return CommandAssessment(action="allow", tool=tool)
            return _approval(tool, risk, f"{operation} the ambient kube-context")
        return CommandAssessment(
            action="block",
            reason_code="kubectl_context_required",
            reason="Every kubectl command must declare --context explicitly.",
            tool=tool,
        )
    if any(char in context for char in "$`{}"):
        return CommandAssessment(
            action="block",
            reason_code="kubectl_context_not_static",
            reason="kubectl --context must be a static context name.",
            tool=tool,
        )
    effective_kubeconfig = _option(parts, "--kubeconfig") or kubeconfig
    if effective_kubeconfig:
        config_path = Path(effective_kubeconfig).expanduser()
        effective_kubeconfig = str(config_path if config_path.is_absolute() else (cwd / config_path).resolve(strict=False))
    verification = verifier(context, effective_kubeconfig)
    if not verification.valid:
        return CommandAssessment(
            action="block",
            reason_code="kubectl_context_invalid",
            reason="The declared kubectl context does not resolve to a configured cluster.",
            tool=tool,
            context=context,
        )
    complete = _kubectl_complete_deletion(parts)
    if verification.is_minikube and not complete:
        warning = "" if risk == "read" else f"verified minikube {context}: {operation} local resources"
        return CommandAssessment(
            action="allow",
            tool=tool,
            context=context,
            profile=verification.profile,
            warning=warning,
        )
    if risk == "read":
        return CommandAssessment(action="allow", tool=tool, context=context)
    consequence = "delete a complete Kubernetes scope" if complete else f"{operation} non-minikube cluster state"
    approval = replace(
        _approval(tool, "destructive" if complete else risk, consequence),
        context=context,
        profile=verification.profile if verification.is_minikube else "",
    )
    # A verified-minikube complete deletion stays approval (-> ask). For a NON-minikube context,
    # encapsulate the dev/prod verdict in the assessment itself so _choose picks the most
    # restrictive across a whole chain: a prod (or undeclared) mutation in ANY segment wins as a
    # block, even alongside another segment's dev/ask.
    if not verification.is_minikube:
        kind = classify(context, cwd)
        if kind in ("prod", "unknown"):
            return replace(
                approval,
                action="block",
                reason_code=f"context_{kind}",
                reason=f"context '{context}' is {kind} (not verified-minikube, not declared dev).",
            )
    return approval


def _choose(assessments: list[CommandAssessment]) -> CommandAssessment:
    blocked = next((item for item in assessments if item.action == "block"), None)
    if blocked:
        return blocked
    approvals = [item for item in assessments if item.action == "approval"]
    if approvals:
        return next((item for item in approvals if item.risk_level == "destructive"), approvals[0])
    warning = next((item for item in assessments if item.warning), None)
    meaningful_allow = next((item for item in assessments if item.tool), None)
    return warning or meaningful_allow or CommandAssessment(action="allow")


def assess_command(
    command: str,
    cwd: Path,
    verifier: ContextVerifier = verify_minikube_context,
) -> CommandAssessment:
    # Command substitution ($()/backticks) is NOT expanded by shlex, so a cloud tool hidden
    # inside one escapes per-segment classification. Treat any cloud tool inside a
    # substitution as un-inspectable -> approval (never a silent allow).
    # covers $(...), <(...) and >(...) process substitution, and `...` backticks
    if re.search(rf"(?:[$<>]\([^)]*|`[^`]*)\b(?:{_CLOUD_TOOL_ALT})\b", command):
        approval = _approval("command", "mutating", "execute a cloud command hidden in command substitution")
        return replace(approval, approval_subject=command)
    script_hashes: list[str] = []
    inspected_scripts: list[Path] = []
    assessments: list[CommandAssessment] = []
    try:
        segments = _segments(command)
    except ValueError:
        approval = _approval("command", "mutating", "execute a command that cannot be parsed safely")
        return replace(approval, approval_subject=command)

    def assess_parts(raw_parts: list[str], depth: int = 0, active_cwd: Path = cwd) -> None:
        raw_tool = _tool(raw_parts[0]) if raw_parts else ""
        if raw_tool == "env":
            env_cwd = _option(raw_parts, "--chdir") or _option(raw_parts, "-C")
            if env_cwd:
                candidate = Path(env_cwd).expanduser()
                active_cwd = (candidate if candidate.is_absolute() else active_cwd / candidate).resolve(strict=False)
        kubeconfig = _environment_value(raw_parts, "KUBECONFIG")
        parts = _without_environment(raw_parts)
        if not parts:
            return
        # Peel command-prefix wrappers (sudo/timeout/nice/…) so a leading wrapper cannot
        # smuggle a cloud tool past classification (PR-#31 bypass class).
        parts, uninspectable = _strip_command_wrappers(parts)
        if uninspectable:
            assessments.append(_approval("command", "mutating", "execute a cloud command hidden behind eval"))
            return
        if not parts:
            return
        if depth > 3:
            assessments.append(_approval("local-script", "mutating", "execute nested script logic beyond inspection depth"))
            return
        tool = _tool(parts[0])
        if tool in _OPAQUE_SHELLS:
            assessments.append(_approval("local-script", "mutating", f"execute a cloud command via un-inspected shell '{tool}'"))
            return
        if tool in {"bash", "sh", "zsh"}:
            shell_command = _shell_command(parts)
            if shell_command:
                try:
                    assess_sequence(_segments(shell_command), depth + 1, active_cwd)
                except ValueError:
                    assessments.append(_approval("local-script", "mutating", "execute dynamic shell content"))
                return
        if tool == "xargs":
            for index, part in enumerate(parts[1:], start=1):
                nested_tool = _tool(part)
                if nested_tool in CLOUD_TOOLS or nested_tool in {"bash", "sh", "zsh"} or script_path(parts[index:], active_cwd):
                    assess_parts(parts[index:], depth + 1, active_cwd)
                    return
            return
        trusted_wrapper = Path.home() / ".ralph-codex" / "bin" / "run-local-minikube-script"
        if tool in {"run-local-minikube-script", "run-local-minikube-script.py"}:
            if Path(parts[0]).expanduser() != trusted_wrapper:
                assessments.append(_approval("local-script", "mutating", "execute an unverified minikube wrapper"))
                return
            wrapper_context = _context(parts)
            wrapper_profile = _option(parts, "--profile")
            verification = verifier(wrapper_context, "") if wrapper_context else ContextVerification(False, False)
            if (
                not wrapper_context
                or not verification.valid
                or not verification.is_minikube
                or wrapper_profile != verification.profile
            ):
                assessments.append(
                    CommandAssessment(
                        action="block",
                        reason_code="minikube_wrapper_context_invalid",
                        reason=(
                            "The minikube runner requires matching --profile and --context values that resolve "
                            "to the same running minikube API endpoint."
                        ),
                        tool="local-script",
                        context=wrapper_context,
                    )
                )
                return
            script = wrapper_script_path(parts, active_cwd)
            if not script:
                assessments.append(
                    CommandAssessment(
                        action="block",
                        reason_code="local_script_invalid",
                        reason="The minikube runner requires a readable regular script file.",
                        tool="local-script",
                    )
                )
                return
            assessments.append(
                CommandAssessment(
                    action="allow",
                    tool="local-script",
                    context=wrapper_context,
                    profile=verification.profile,
                )
            )
        else:
            script = script_path(parts, active_cwd)

        if script:
            inspected_scripts.append(script)
            commands, error, script_hash = script_cloud_commands(script)
            if script_hash:
                script_hashes.append(f"{script}:{script_hash}")
            if error:
                assessments.append(_approval("local-script", "mutating", error))
                return
            for script_command in commands:
                try:
                    for segment in _segments(script_command):
                        assess_parts(segment, depth + 1, active_cwd)
                except ValueError:
                    assessments.append(
                        _approval("local-script", "mutating", "execute a cloud command that cannot be parsed statically")
                    )
            return

        if tool in CLOUD_TOOLS:
            assessments.append(_assess_cloud_parts(parts, verifier, kubeconfig, active_cwd))

    def assess_sequence(command_segments: list[list[str]], depth: int, start_cwd: Path) -> None:
        active_cwd = start_cwd
        for segment in command_segments:
            parts = _without_environment(segment)
            if parts and _tool(parts[0]) == "cd":
                if len(parts) != 2 or parts[1] == "-" or any(char in parts[1] for char in "$`{}"):
                    assessments.append(_approval("local-script", "mutating", "execute a relative script after dynamic cd"))
                    continue
                target = Path(parts[1]).expanduser()
                active_cwd = (target if target.is_absolute() else active_cwd / target).resolve(strict=False)
                continue
            assess_parts(segment, depth, active_cwd)

    assess_sequence(segments, 0, cwd)
    chosen = _choose(assessments)
    if inspected_scripts and _rewrites_inspected_script(command, inspected_scripts, cwd) and chosen.action == "allow":
        chosen = _approval("local-script", "mutating", "rewrite an inspected script before execution")
    subject = f"{cwd.resolve(strict=False)}\n{command}"
    if script_hashes:
        subject += "\n" + "\n".join(sorted(set(script_hashes)))
    return replace(chosen, approval_subject=subject)
