#!/usr/bin/env bash
# anti-rationalization-gate.sh — Stop hook: blocks excuses AND mid-plan confirmations
# VERSION: 2.0.1
# v2.0.1 (2026-08-28, T87): project paths resolve from the working-tree ROOT
#   containing $cwd (not from $cwd itself) — a session that cd'd into a
#   subdirectory kept the active plan invisible and left Modo B silently OFF.
# Event: Stop
# Format: allow == clean `exit 0` with NO stdout; block == {"decision": "block",
#   "reason": "..."}. `{"decision": "approve"}` is NOT a valid Claude Code value
#   and is rejected by output validation — never emit it. See
#   tests/HOOK_FORMAT_REFERENCE.md.
#
# v2.0.0 (2026-04-20): MERGED plan-continuation-gate.sh into this hook.
#   - Unifies two Stop-chain gates into a single coordinated enforcer
#   - Shared state file (anti-rat-blocks.json) — no duplicated counters
#   - Reads plan-state.json (same source as statusline-ralph.sh) for execution awareness
#   - Confirmation-pattern detection is GATED on an active plan (no false positives
#     when the agent is idle between tasks)
#   - stop_hook_active infinite-loop guard added
#
# Two enforcement modes:
#   A) EXCUSE mode — always on. Scans transcript for rationalizations from
#      docs/reference/anti-rationalization.md (+ parallel-first fallback).
#   B) CONFIRMATION mode — only when an ACTIVE plan is detected. Scans the
#      tail for ES/EN patterns like "¿Procedo?" / "Should I continue?" that
#      violate .claude/rules/plan-immutability.md.
#
# Active-plan detection (PROJECT-ISOLATED, freshness filter: last_updated < 30 min):
#   - Reads ONLY $PROJECT_ROOT/.claude/plan-state.json (working-tree root of $cwd)
#   - NO global/cross-project fallback — plans are per-repo by design to prevent
#     cross-project contamination (a plan in project A must NEVER block Stop
#     hooks in project B)
#
# Safeguards:
#   - Respects stop_hook_active (no self-triggering loops)
#   - MAX_BLOCKS=3 per session (auto-reset + approve after threshold)
#   - Fail-open on jq missing, patterns file missing, or malformed input

umask 077
INPUT=$(head -c 100000)

# --- Guard: jq required, fail-open otherwise ---
if ! command -v jq >/dev/null 2>&1; then
  # allow: silent exit 0 (see Format note in the header)
  exit 0
fi

# --- Shared library: the ONLY stat dialect strategy (T99 r3 finding 2) ---
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  # No library -> degraded but working: git-root-or-cwd resolution without
  # the content-marker walk, and no reliable mtime (stat_mtime failing =>
  # epoch stays 0 => "unknown", never guessed).
  get_project_root() {
    local cwd="${1:-${PWD:-.}}" canon r
    canon="$(cd "$cwd" 2>/dev/null && pwd -P || echo "$cwd")"
    r="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$r" ]] && { echo "$r"; return; }
    echo "$canon"
  }
  stat_mtime() { return 1; }
}

# --- Infinite-loop guard: honor stop_hook_active ---
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  # allow: silent exit 0 (see Format note in the header)
  exit 0
fi

# --- Resolve CWD and project-scoped state (isolated per-repo) ---
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)
[[ -z "$CWD" || "$CWD" == "null" ]] && CWD="$(pwd)"

# v2.0.1 (T87): a session that cd'd into a subdirectory still belongs to this
# project — its plan-state, per-project state dir and patterns file all live
# at the working-tree ROOT. Resolve the root CONTAINING CWD; the root is
# always an ancestor of CWD, so per-project isolation is unchanged and no
# cross-project fallback is added. Non-git projects keep CWD as the scope.
#
# v2.0.2 (T99, retro-audit of T87): "non-git projects keep CWD" was not
# honored — `git rev-parse --show-toplevel` climbs past nested boundaries,
# so a non-git project living inside a CONTAINER repo (e.g. a dotfiles repo
# spanning $HOME) adopted the ancestor's root and read the ANCESTOR's
# patterns/state: cross-project contamination the header forbids. The
# ancestor-repo case is now materialized as: adopt the repo root only when
# NO directory between the root and CWD (inclusive) marks itself a separate
# project (own .git — which rev-parse would have stopped at — or .claude/).
# A broken git (present but failing on a corrupt repo / dubious ownership)
# is distinguished from "not a git repository" and logged; both keep CWD
# scope, but only the broken case needs the operator to know.
# T99 r4: ONE project-resolution definition (lib/worktree-utils.sh:
# get_project_root — content-marker walk, broken-git tolerant, always
# absolute). The gate and every writer now share it by construction; the
# split-brain measured in review (gate seeing the nested plan while a
# writer mutated the container's) is structurally dead.
PROJECT_ROOT="$(get_project_root "$CWD")"
# Operator signal for BROKEN git (corrupt HEAD, unreadable .git): the
# resolution above is filesystem-only and unaffected, but the operator
# still wants to know the repo is unhealthy. Dedup by (location, day) —
# a corrupt repo fails every Stop, and the log must stay readable.
_T99_BROKEN_RC=0
git -C "$CWD" rev-parse --show-toplevel >/dev/null 2>&1 || _T99_BROKEN_RC=$?
if [[ "$_T99_BROKEN_RC" -ne 0 ]]; then
  _T99_HAS_GIT=""
  _T99_DIR="$(cd "$CWD" 2>/dev/null && pwd -P || echo "$CWD")"
  while [[ -n "$_T99_DIR" && "$_T99_DIR" != "/" ]]; do
    if [[ -e "$_T99_DIR/.git" ]]; then _T99_HAS_GIT="$_T99_DIR"; break; fi
    _next="${_T99_DIR%/*}"
    [[ "$_next" == "$_T99_DIR" ]] && break
    _T99_DIR="$_next"
  done
  if [[ -n "$_T99_HAS_GIT" ]]; then
    _T99_DEDUP_DIR="$CWD/.claude/state"
    mkdir -p "$_T99_DEDUP_DIR" 2>/dev/null || true
    _T99_DEDUP_KEY="$(date +%F) $_T99_HAS_GIT"
    if [[ ! -f "$_T99_DEDUP_DIR/.anti-rat-git-broken.last" ]] \
       || [[ "$(cat "$_T99_DEDUP_DIR/.anti-rat-git-broken.last" 2>/dev/null)" != "$_T99_DEDUP_KEY" ]]; then
      mkdir -p "${HOME}/.ralph/logs" 2>/dev/null || true
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] git present but broken under $CWD ($_T99_HAS_GIT/.git, rc=$_T99_BROKEN_RC); treating as no-git" \
        >> "${HOME}/.ralph/logs/anti-rationalization-gate.log" 2>/dev/null || true
      printf '%s\n' "$_T99_DEDUP_KEY" > "$_T99_DEDUP_DIR/.anti-rat-git-broken.last" 2>/dev/null || true
    fi
  fi
fi

# State and patterns are PER-PROJECT. No cross-project contamination.
STATE_DIR="$PROJECT_ROOT/.claude/state"
STATE_FILE="$STATE_DIR/anti-rat-blocks.json"
PATTERNS_FILE="$PROJECT_ROOT/docs/reference/anti-rationalization.md"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# --- Max blocks guard ---
MAX_BLOCKS=3
BLOCK_COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  BLOCK_COUNT=$(jq -r '.blocks // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi
if [[ "$BLOCK_COUNT" -ge "$MAX_BLOCKS" ]]; then
  echo '{"blocks": 0}' > "$STATE_FILE" 2>/dev/null || true
  # allow: silent exit 0 (see Format note in the header)
  exit 0
fi

# --- Active-plan detection (freshness filter: last_updated < 30 min) ---

HAS_ACTIVE_PLAN=false
ACTIVE_PLAN_DETAIL=""
FRESH_WINDOW=1800  # 30 minutes

# 1) Project-level plan-state.json
PROJECT_PLAN_STATE="$PROJECT_ROOT/.claude/plan-state.json"
if [[ -f "$PROJECT_PLAN_STATE" ]]; then
  UPDATED_EPOCH=0
  LAST_UPDATED=$(jq -r '.last_updated // ""' "$PROJECT_PLAN_STATE" 2>/dev/null)
  if [[ -n "$LAST_UPDATED" && "$LAST_UPDATED" != "null" ]]; then
    TS="${LAST_UPDATED%%+*}"; TS="${TS%Z}"
    # Force UTC interpretation — plan timestamps are emitted with %Y-%m-%dT%H:%M:%SZ
    UPDATED_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$TS" "+%s" 2>/dev/null \
      || date -d "$LAST_UPDATED" "+%s" 2>/dev/null \
      || echo 0)
  fi
  # Defensive fallback: several updater hooks (plan-sync-post-step, auto-plan-state,
  # plan-state-adaptive, ...) mutate .steps[] without rewriting .last_updated.
  # When that happens, file mtime is the best proxy for freshness.
  # T99 r3 finding 2: the hand-rolled `stat -f %m || stat -c %Y || echo 0`
  # here carried the GNU trap — on Linux `-f` SUCCEEDS with non-numeric
  # filesystem info, the fallback was unreachable, and the arithmetic broke
  # Modo B in CI. stat_mtime (shared lib) probes the dialect and gates the
  # value; "unknown" stays 0 (conservative: no plan = no block).
  if [[ "$UPDATED_EPOCH" -eq 0 ]]; then
    UPDATED_EPOCH="$(stat_mtime "$PROJECT_PLAN_STATE" 2>/dev/null || echo 0)"
  fi
  NOW_EPOCH=$(date "+%s")
  AGE_SEC=$((NOW_EPOCH - UPDATED_EPOCH))
  if [[ "$UPDATED_EPOCH" -gt 0 && "$AGE_SEC" -ge 0 && "$AGE_SEC" -lt "$FRESH_WINDOW" ]]; then
    IN_PROGRESS=$(jq -r '[.steps[]? | select(.status == "in_progress")] | length' "$PROJECT_PLAN_STATE" 2>/dev/null || echo 0)
    if [[ "${IN_PROGRESS:-0}" -gt 0 ]]; then
      HAS_ACTIVE_PLAN=true
      NEXT=$(jq -r '[.steps[]? | select(.status == "in_progress")][0].name // "unnamed"' "$PROJECT_PLAN_STATE" 2>/dev/null | head -c 120)
      ACTIVE_PLAN_DETAIL="plan-state.json step: $NEXT"
    fi
  fi
fi

# NOTE: No global/cross-project fallback. Per-repo isolation is a SECURITY
# requirement — a plan in project A must never gate Stop events in project B.

# --- Mode A: Excuse detection (always on) ---
MATCHED_EXCUSE=""
MATCHED_REBUTTAL=""

if [[ -f "$PATTERNS_FILE" ]]; then
  EXCUSES=$(grep -E '^\|.*\|.*\|.*\|' "$PATTERNS_FILE" \
    | grep -v 'Excuse.*Rebuttal' \
    | grep -v -- '---' \
    | awk -F'|' '{print $3}' \
    | sed 's/^ *//;s/ *$//' \
    | grep -v '^$' \
    | sort -u)

  while IFS= read -r excuse; do
    [[ -z "$excuse" ]] && continue
    if echo "$INPUT" | grep -qiF -- "$excuse"; then
      MATCHED_EXCUSE="$excuse"
      ESC_EXCUSE=$(printf '%s' "$excuse" | sed 's/[][\.*^$/]/\\&/g')
      MATCHED_REBUTTAL=$(grep -E "^\|.*\|.*${ESC_EXCUSE}.*\|" "$PATTERNS_FILE" \
        | head -1 \
        | awk -F'|' '{print $4}' \
        | sed 's/^ *//;s/ *$//')
      break
    fi
  done <<< "$EXCUSES"
fi

# Hardcoded parallel-first fallback
if [[ -z "$MATCHED_EXCUSE" ]]; then
  PARALLEL_EXCUSES="Sequential is simpler
hidden dependencies
parallelize in the next
coordination overhead
faster to do it myself
too small for parallelism
already started sequentially
Only one file needs changing"
  while IFS= read -r excuse; do
    [[ -z "$excuse" ]] && continue
    if echo "$INPUT" | grep -qiF -- "$excuse"; then
      MATCHED_EXCUSE="$excuse"
      MATCHED_REBUTTAL="See .claude/rules/parallel-first.md for the rebuttal."
      break
    fi
  done <<< "$PARALLEL_EXCUSES"
fi

# --- Decision: Excuse match wins immediately ---
if [[ -n "$MATCHED_EXCUSE" ]]; then
  NEW_COUNT=$((BLOCK_COUNT + 1))
  echo "{\"blocks\": $NEW_COUNT}" > "$STATE_FILE"
  REASON="Anti-rationalization gate: Detected excuse pattern '$MATCHED_EXCUSE'. $MATCHED_REBUTTAL Provide a factual justification for stopping, not a rationalization. Block $NEW_COUNT/$MAX_BLOCKS."
  echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
  exit 0
fi

# --- Mode B: Confirmation-pattern detection (only when plan is active) ---
if [[ "$HAS_ACTIVE_PLAN" == true ]]; then
  TAIL=$(echo "$INPUT" | tail -c 2000)

  CONFIRMATION_PATTERNS=(
    # ES
    '¿Quieres que continúe'
    '¿Quieres que siga'
    '¿Procedo'
    '¿Sigo'
    '¿Continúo'
    '¿Te parece'
    '¿Avanzo'
    'Confirma si'
    'Dime si quieres'
    'Quieres que siga'
    'Espero tu confirmación'
    # EN
    'Should I proceed'
    'Should I continue'
    'Do you want me to proceed'
    'Do you want me to continue'
    'Let me know if you'
    'Shall I continue'
    'Shall I proceed'
    'Would you like me to continue'
    'Ready to proceed'
    'Waiting for your confirmation'
    'Please confirm'
  )

  MATCHED_CONFIRMATION=""
  for pat in "${CONFIRMATION_PATTERNS[@]}"; do
    if echo "$TAIL" | grep -qiF -- "$pat"; then
      MATCHED_CONFIRMATION="$pat"
      break
    fi
  done

  if [[ -n "$MATCHED_CONFIRMATION" ]]; then
    NEW_COUNT=$((BLOCK_COUNT + 1))
    echo "{\"blocks\": $NEW_COUNT}" > "$STATE_FILE"
    REASON="Plan-immutability gate: Active plan detected ($ACTIVE_PLAN_DETAIL). Transcript ends with confirmation pattern '$MATCHED_CONFIRMATION'. Per .claude/rules/plan-immutability.md, plans are IMMUTABLE during execution — continue the next step without asking. Only pause for destructive actions (rm -rf, git reset --hard, force-push) or when the user explicitly requested a checkpoint. Block $NEW_COUNT/$MAX_BLOCKS."
    echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
    exit 0
  fi
fi

# --- No match: approve ---
  # allow: silent exit 0 (see Format note in the header)
exit 0
