#!/usr/bin/env bash
umask 077
set -uo pipefail

# PreToolUse hook: block cluster-mutating kubectl/helm/kustomize commands whose EFFECTIVE
# context is not in the allowlist.
# Reads tool input JSON from stdin. Exit 0 = allow, exit 2 = block with message.
#
# v2 (2026-07-31) fixes three defects in the original guard:
#
# D1 — It matched the command TEXT with grep, so any command merely MENTIONING kubectl was
#      blocked, including a heredoc writing documentation, and read-only renders like
#      `kubectl kustomize` or `kustomize build` that never contact an API server.
#      Over-blocking has a security cost of its own: an agent that hits it learns to
#      evade it — one was observed building the string as "kube"+"ctl" to slip past the
#      grep. A control that trains callers to route around it protects nothing.
#      Now the guard fires only when one of these is the command being INVOKED (start of
#      a line or after | && || ; $( or a backtick), never on a mention inside a quoted
#      string or a heredoc body.
#
# D2 — It read `kubectl config current-context`, not the `--context` flag the command
#      actually uses. With a kind context active, this PASSED:
#          kubectl --context=gke_proj_region_prod apply -f destructive.yaml
#      i.e. it authorised a mutation against production, the exact inverse of its promise.
#      Now the effective context is parsed from the command itself; current-context is
#      only the fallback when the command names none.
#
# D3 — `^kind-` was hardcoded, so every minikube / k3d / k3s project was blocked in its
#      own legitimate use case. Now K8S_GUARD_ALLOWED_CONTEXTS holds a comma-separated
#      list of ERE patterns, defaulting to `^kind-` so existing setups are unaffected.
#
# Decisions are fail-closed: if the effective context cannot be determined, or is not
# allowed, the command is blocked. That is stricter than v1, which allowed anything once
# current-context happened to match.

HOOK_NAME="k8s-context-guard"
ALLOWED_CONTEXTS="${K8S_GUARD_ALLOWED_CONTEXTS:-^kind-}"

INPUT="$(cat)"

COMMAND=""
if command -v jq >/dev/null 2>&1; then
  COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
else
  COMMAND="$(printf '%s' "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)"
fi

# No command to evaluate: nothing for this guard to decide on.
[[ -z "$COMMAND" ]] && exit 0

# ---------------------------------------------------------------------------
# D1: strip everything that is DATA rather than an invocation, then look for the
# tools at the head of a command position.
# ---------------------------------------------------------------------------

strip_noninvocations() {
  # Drop heredoc bodies (<<EOF ... EOF, <<'EOF', <<-EOF) and quoted strings, so text
  # written INTO a file never counts as running anything.
  awk '
    BEGIN { in_heredoc = 0 }
    {
      line = $0
      if (in_heredoc) {
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (line == delim) { in_heredoc = 0 }
        next
      }
      if (match($0, /<<-?[ \t]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
        delim = substr($0, RSTART, RLENGTH)
        gsub(/^<<-?[ \t]*['"'"'"]?|['"'"'"]?$/, "", delim)
        in_heredoc = 1
        sub(/<<-?[ \t]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?.*$/, "", $0)
      }
      print
    }
  ' <<< "$1" |
  # Remove single- and double-quoted spans: a tool name inside a string is data.
  sed "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g"
}

# A shell wrapper carries the real command INSIDE a quoted span. Unwrap it BEFORE
# blanking quoted text, otherwise the payload disappears and the invocation scan sees
# only the wrapper name — a total bypass of every check in this file.
#
# SCOPE, stated so the next audit does not have to rediscover it: this is defence in
# depth by text matching, NOT a shell parser. It recognises the wrappers observed in
# practice (bash/sh/zsh/dash/eval, optionally via sudo). It does not attempt mismatched
# or nested quoting, nor other interpreters that can carry a command (`python3 -c`,
# `perl -e`, `ssh host "..."`, `xargs`). Those remain covered by the normal permission
# prompt, which this hook advises but never replaces. Widen the list when a real bypass
# is observed; do not mistake this for a complete boundary.
unwrap_shell_wrappers() {
  local cmd="$1" prev="" i=0
  # A wrapper may nest. Bounded to avoid pathological input.
  while [[ "$cmd" != "$prev" && $i -lt 5 ]]; do
    prev="$cmd"; i=$((i + 1))
    cmd="$(printf '%s' "$cmd" | sed -E "s/(^|[|&;[:space:]])(sudo[[:space:]]+)?(bash|sh|zsh|dash|eval)[[:space:]]+(-[a-z]+[[:space:]]+)*['\"]([^'\"]*)['\"]/\1\5/g")"
  done
  printf '%s' "$cmd"
}

COMMAND="$(unwrap_shell_wrappers "$COMMAND")"
EXECUTABLE="$(strip_noninvocations "$COMMAND")"

# Split on shell separators so each piece starts at a command position, then discard
# benign wrappers (env assignments, sudo, time, ...) before reading the first token.
mapfile -t SEGMENTS < <(printf '%s' "$EXECUTABLE" | sed 's/\$(/\n/g; s/`/\n/g; s/&&/\n/g; s/||/\n/g; s/|/\n/g; s/;/\n/g')

invokes_k8s_tool=0
for seg in "${SEGMENTS[@]}"; do
  cleaned="$(printf '%s' "$seg" \
    | sed -E 's/^[[:space:]]+//' \
    | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//' \
    | sed -E 's/^(sudo|command|env|time|nice|nohup|xargs)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*//')"
  first_token="${cleaned%%[[:space:]]*}"
  first_token="${first_token##*/}"          # allow /usr/local/bin/kubectl
  case "$first_token" in
    kubectl|helm|kustomize) invokes_k8s_tool=1; break ;;
  esac
done

[[ "$invokes_k8s_tool" -eq 0 ]] && exit 0

# ---------------------------------------------------------------------------
# Exemptions: operations that never contact a cluster API server.
# ---------------------------------------------------------------------------

is_cluster_free() {
  local cmd="$1"
  # Local manifest rendering
  grep -qE '\bkubectl[[:space:]]+kustomize\b' <<< "$cmd" && return 0
  grep -qE '(^|[|&;[:space:]])kustomize[[:space:]]+build\b' <<< "$cmd" && return 0
  grep -qE '\bhelm[[:space:]]+(template|lint|show|dependency)\b' <<< "$cmd" && return 0
  # Client-side validation only
  grep -qE '\-\-dry-run[= ]client\b' <<< "$cmd" && return 0
  # Reading local kubeconfig
  grep -qE '\bkubectl[[:space:]]+config[[:space:]]+(view|current-context|get-contexts|get-clusters|use-context|set-context|rename-context)\b' <<< "$cmd" && return 0
  grep -qE '\bhelm[[:space:]]+(list|version|env|repo)\b' <<< "$cmd" && return 0
  grep -qE '\bkubectl[[:space:]]+(version[[:space:]]+--client|api-versions|api-resources)\b' <<< "$cmd" && return 0
  return 1
}

if is_cluster_free "$EXECUTABLE"; then
  exit 0
fi

# Pure reads against a cluster stay allowed, as in v1: they cannot mutate state.
if grep -qE '\bkubectl\b' <<< "$EXECUTABLE" \
   && grep -qE '\b(get|describe|logs|explain|top|events)\b' <<< "$EXECUTABLE" \
   && ! grep -qE '\b(apply|create|delete|patch|replace|edit|scale|rollout|drain|cordon|uncordon|taint|label|annotate|exec|cp|port-forward)\b' <<< "$EXECUTABLE"; then
  exit 0
fi

# ---------------------------------------------------------------------------
# D2: resolve the context the command will ACTUALLY use.
# ---------------------------------------------------------------------------

CONTEXT=""
CONTEXT_SOURCE=""

# Collect EVERY context flag in the command, not just the first. Two reasons the
# first-match approach was exploitable:
#   1. kubectl applies the LAST occurrence when the flag repeats (standard last-wins CLI
#      semantics), so a decoy allowed value in front made the guard read that one while
#      kubectl acted on a later, non-allowed one.
#   2. A chain of two invocations is a single string with two contexts; judging it by the
#      first authorises the second.
# Every context named must be allowed, so a decoy cannot cover a real one.
mapfile -t CONTEXTS < <(
  printf '%s' "$EXECUTABLE" \
    | grep -oE -- '--(kube-)?context[= ]+[^[:space:];&|]+' \
    | sed -E 's/^--(kube-)?context[= ]+//'
)

if [[ "${#CONTEXTS[@]}" -gt 0 ]]; then
  CONTEXT_SOURCE="--context flag"
else
  CONTEXTS=("$(kubectl config current-context 2>/dev/null || true)")
  CONTEXT_SOURCE="current-context"
fi

CLEANED=()
for c in "${CONTEXTS[@]}"; do
  c="${c%\"}"; c="${c#\"}"; c="${c%\'}"; c="${c#\'}"
  CLEANED+=("$c")
done
CONTEXTS=("${CLEANED[@]}")

# ---------------------------------------------------------------------------
# D3: configurable allowlist, evaluated fail-closed.
# ---------------------------------------------------------------------------

context_is_allowed() {
  local ctx="$1"
  [[ -z "$ctx" ]] && return 1          # unknown context is never allowed
  local IFS=','
  local pattern
  for pattern in $ALLOWED_CONTEXTS; do
    pattern="$(printf '%s' "$pattern" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -z "$pattern" ]] && continue
    if grep -qE "$pattern" <<< "$ctx"; then
      return 0
    fi
  done
  return 1
}

# One non-allowed context anywhere in the command is enough to block it.
ALL_ALLOWED=1
DENIED_CONTEXT=""
for c in "${CONTEXTS[@]}"; do
  if ! context_is_allowed "$c"; then
    ALL_ALLOWED=0
    DENIED_CONTEXT="$c"
    break
  fi
done

if [[ "$ALL_ALLOWED" -eq 1 && "${#CONTEXTS[@]}" -gt 0 ]]; then
  exit 0
fi
CONTEXT="$DENIED_CONTEXT"

if [[ -z "$CONTEXT" ]]; then
  detected="none (no --context flag and no current-context set)"
else
  detected="'${CONTEXT}' (from ${CONTEXT_SOURCE})"
fi

cat >&2 <<EOF
BLOCKED by ${HOOK_NAME}: this command would act on a cluster whose context is not allowed.

  Effective context : ${detected}
  Allowed patterns  : ${ALLOWED_CONTEXTS}

The effective context is taken from the command's own --context/--kube-context flag when
present, and only otherwise from kubectl's current-context — so switching current-context
does not authorise a command that names a different one.

To permit your local cluster, set the allowlist (comma-separated regular expressions):

  export K8S_GUARD_ALLOWED_CONTEXTS='^kind-,^minikube\$,^k3d-'

Read-only work is already allowed: kubectl get/describe/logs, kubectl kustomize,
kustomize build, helm template and --dry-run=client never reach this check.
EOF
exit 2
