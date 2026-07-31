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
  grep -qE '\bkubectl[[:space:]]+config[[:space:]]+(view|current-context|get-contexts|get-clusters)\b' <<< "$cmd" && return 0
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

if [[ "$EXECUTABLE" =~ --context[=[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  CONTEXT="${BASH_REMATCH[1]}"
  CONTEXT_SOURCE="--context flag"
elif [[ "$EXECUTABLE" =~ --kube-context[=[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  CONTEXT="${BASH_REMATCH[1]}"          # helm's spelling
  CONTEXT_SOURCE="--kube-context flag"
else
  CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
  CONTEXT_SOURCE="current-context"
fi

CONTEXT="${CONTEXT%\"}"; CONTEXT="${CONTEXT#\"}"
CONTEXT="${CONTEXT%\'}"; CONTEXT="${CONTEXT#\'}"

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

if context_is_allowed "$CONTEXT"; then
  exit 0
fi

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
