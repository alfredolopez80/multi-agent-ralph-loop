from __future__ import annotations

import hashlib
import os
import re
from pathlib import Path

SCRIPT_INTERPRETERS = {"bash", "node", "perl", "python", "python3", "ruby", "sh", "zsh"}
SCRIPT_SUFFIXES = {".bash", ".js", ".mjs", ".pl", ".py", ".rb", ".sh", ".zsh"}
PYTHON_VALUE_OPTIONS = {"-W", "-X", "--check-hash-based-pycs"}
MAX_SCRIPT_BYTES = 256_000
# Narrowed to this guard's domain (helm/kubectl/minikube). aws/gcloud/terraform belong to
# git-safety-guard; extracting them here would be dead work since CLOUD_TOOLS drops them.
TOOL_RE = re.compile(r"(?<![A-Za-z0-9_.-])(helm|kubectl|minikube)(?![A-Za-z0-9_.-])")

# Tools and wrappers whose line-prefix in a script means "this line IS an invocation".
# A line that merely MENTIONS one of these tools (in a string literal, regex, error
# message, comment, or variable name) is NOT an invocation — treating it as one was
# the source of a false positive when running any Python file that discusses kubectl
# (e.g. the k8s-context-guard code itself): the inspector extracted the suffix of
# `CLOUD_TOOLS = {"helm", "kubectl", "minikube"}` from "kubectl" onwards and tried to
# assess `"kubectl", "minikube"}` as a kubectl command, which denied on missing
# --context. Gate the TOOL_RE scan on this set so only true invocations are detected.
_INVOCATION_STARTERS: frozenset[str] = frozenset({
    # Cloud tools — commands this guard inspects.
    "helm", "kubectl", "minikube",
    # Wrappers peeled by cloud_operation_gate._strip_command_wrappers. A line that
    # starts with one of these is still an invocation once the wrapper is removed
    # (the existing TOOL_RE scan then locates the tool inside the rest of the line).
    "sudo", "doas", "command", "nice", "ionice", "nohup", "setsid", "stdbuf",
    "time", "timeout", "watch", "chrt",
})


def _line_starts_with_invocation(stripped: str) -> bool:
    """True iff the first whitespace-separated token of `stripped` names a real
    cloud tool or a recognized wrapper (the path's basename is taken so relative
    paths like `./kubectl …` and `/usr/bin/kubectl …` also qualify).

    Used to gate `TOOL_RE.search` inside `script_cloud_commands` so that a line
    which only contains the string "kubectl" inside a literal / regex / message
    / variable name does not get extracted as a phantom command.
    """
    if not stripped:
        return False
    first_token = stripped.split(None, 1)[0]
    first_word = Path(first_token).name.lower()
    return first_word in _INVOCATION_STARTERS


def _is_script_interpreter(tool: str) -> bool:
    return tool in SCRIPT_INTERPRETERS or bool(re.fullmatch(r"python(?:3(?:\.\d+)*)?", tool))


def _regular_script(candidate: Path) -> Path | None:
    absolute = candidate.expanduser()
    if absolute.is_symlink():
        return None
    try:
        resolved = absolute.resolve(strict=True)
    except OSError:
        return None
    return resolved if resolved.is_file() else None


# ONLY $HOME/$PWD are expanded, and they are process facts, not a shell engine:
# $PWD is the EFFECTIVE cwd the guard already tracks across `cd` segments and
# $HOME never changes mid-command. Any other $VAR stays literal, which marks the
# token as still-dynamic (see unresolved_script_uncertainty) instead of guessing.
_DYNAMIC_ENV_RE = re.compile(r"\$\{(HOME|PWD)\}|\$(HOME|PWD)\b")


def _expand_static_env(token: str, cwd: Path) -> str:
    def _sub(match: re.Match[str]) -> str:
        name = match.group(1) or match.group(2)
        if name == "PWD":
            return str(cwd)
        return os.environ.get("HOME") or match.group(0)

    return _DYNAMIC_ENV_RE.sub(_sub, token)


def _script_candidate_token(parts: list[str]) -> str | None:
    """First positional candidate token of a script invocation, or None when the
    command has no script-path shape: inline `-c`/`-m` code, option-only
    invocations, or a bare PATH lookup (`make`, `ls`) that never names a file."""
    if not parts:
        return None
    tool = Path(parts[0]).name.lower()
    if _is_script_interpreter(tool):
        index = 1
        while index < len(parts):
            part = parts[index]
            if part == "--":
                index += 1
                break
            if part in {"-c", "-m"}:
                return None
            option = part.split("=", 1)[0]
            if option in PYTHON_VALUE_OPTIONS:
                index += 1 if "=" in part or (len(part) > 2 and part[:2] in PYTHON_VALUE_OPTIONS) else 2
                continue
            if part.startswith("-"):
                index += 1
                continue
            break
        if index >= len(parts):
            return None
        return parts[index]
    if "/" not in parts[0] and not Path(parts[0]).is_absolute():
        return None
    return parts[0]


def script_path(parts: list[str], cwd: Path) -> Path | None:
    token = _script_candidate_token(parts)
    if token is None:
        return None
    is_interpreter = _is_script_interpreter(Path(parts[0]).name.lower())
    candidate = Path(_expand_static_env(token, cwd))
    candidate = candidate if candidate.is_absolute() else cwd / candidate
    script = _regular_script(candidate)
    if not script:
        return None
    if is_interpreter or script.suffix.lower() in SCRIPT_SUFFIXES or script.stat().st_mode & 0o111:
        return script
    return None


def unresolved_script_uncertainty(parts: list[str], cwd: Path) -> bool:
    """True when the invocation has script shape but its path cannot be safely
    resolved to an inspectable regular file: a still-dynamic token (any $VAR
    beyond $HOME/$PWD, or backticks) or an existing non-regular target (a
    symlink — rejected by _regular_script — is mutable between inspection and
    execution). That is evaluation uncertainty, not evidence of safety
    (issue #68): the caller must produce an explicit non-allow verdict, never a
    silent allow.

    NOT uncertainty: a literal nonexistent path (nothing expands at runtime —
    the shell itself fails) and bare PATH lookups, which have no script shape
    and stay outside this gate so ordinary non-cloud scripts remain usable.
    """
    token = _script_candidate_token(parts)
    if token is None:
        return False
    expanded = _expand_static_env(token, cwd)
    if "$" in expanded or "`" in token:
        return True
    candidate = Path(expanded)
    candidate = candidate if candidate.is_absolute() else cwd / candidate
    if candidate.is_symlink():
        return True
    try:
        resolved = candidate.resolve(strict=True)
    except OSError:
        return False
    return not resolved.is_file()


def wrapper_script_path(parts: list[str], cwd: Path) -> Path | None:
    value_options = {"--profile", "--context"}
    index = 1
    while index < len(parts):
        part = parts[index]
        if part in value_options:
            index += 2
            continue
        if any(part.startswith(option + "=") for option in value_options):
            index += 1
            continue
        candidate = Path(part)
        candidate = candidate if candidate.is_absolute() else cwd / candidate
        return _regular_script(candidate)
    return None


def script_cloud_commands(path: Path) -> tuple[list[str], str, str]:
    try:
        if path.stat().st_size > MAX_SCRIPT_BYTES:
            return ([], "script exceeds static inspection limit", "")
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ([], "script cannot be inspected as text", "")
    commands: list[str] = []
    for line in content.replace("\\\n", " ").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # Only scan lines that LOOK like a real command invocation (first token is
        # a cloud tool or a recognized wrapper). A line that merely contains
        # "kubectl" inside a string literal / regex / error message / variable
        # name is NOT an invocation — the original `TOOL_RE.search` blindly
        # extracted such mentions and the recursive assessment then denied on
        # missing --context, which is wrong: the user ran a Python file that
        # discusses kubectl, they did not invoke kubectl.
        if not _line_starts_with_invocation(stripped):
            continue
        match = TOOL_RE.search(stripped)
        if match:
            commands.append(stripped[match.start() :])
    fingerprint = hashlib.sha256(content.encode("utf-8")).hexdigest()
    return (commands, "", fingerprint)
