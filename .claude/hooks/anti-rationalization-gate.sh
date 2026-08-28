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
PROJECT_ROOT="$CWD"
if command -v git >/dev/null 2>&1; then
  # stdout+stderr captured together in a variable (success writes no stderr,
  # so rc decides which half of $_T87_OUT is which — no temp file needed).
  _T87_OUT="$(git -C "$CWD" rev-parse --show-toplevel 2>&1)" && _T87_RC=0 || _T87_RC=$?
  if [[ "$_T87_RC" -eq 0 ]]; then
    _T87_ROOT="$_T87_OUT"
    # git reports the PHYSICAL root (/private/var on macOS); the payload cwd
    # arrives in LOGICAL form (/var) — the same symlink pair T87's fixture
    # documents. Compare the walk against the canonical CWD or the loop
    # walks straight past the real root and stops at a phantom boundary.
    _T99_CANON_CWD="$(cd "$CWD" 2>/dev/null && pwd -P || echo "$CWD")"
    _T99_BOUNDARY=""
    _T99_DIR="$_T99_CANON_CWD"
    while [[ -n "$_T99_DIR" && "$_T99_DIR" != "/" && "$_T99_DIR" != "$_T87_ROOT" ]]; do
      if [[ -e "$_T99_DIR/.git" || -d "$_T99_DIR/.claude" ]]; then
        _T99_BOUNDARY="$_T99_DIR"
        break
      fi
      _T99_DIR="${_T99_DIR%/*}"   # parameter expansion: no fork per level
    done
    if [[ -n "$_T99_BOUNDARY" ]]; then
      # T99 RETURN 3: the marked directory IS the nested project's root —
      # staying on raw CWD lost its plan-state when the session sat below
      # the marked dir (the T87 symptom, resurrected one level deeper).
      PROJECT_ROOT="$_T99_BOUNDARY"
    else
      PROJECT_ROOT="$_T87_ROOT"
    fi
  else
    # T99 RETURN 4: broken git (corrupt HEAD, unreadable .git) fails with
    # the SAME "not a git repository" text a true no-git dir emits — the
    # message cannot distinguish them; the presence of a .git on the walk
    # up can. Broken => log it; true no-git => stay silent (normal).
    _T99_HAS_GIT=""
    _T99_DIR="$(cd "$CWD" 2>/dev/null && pwd -P || echo "$CWD")"
    while [[ -n "$_T99_DIR" && "$_T99_DIR" != "/" ]]; do
      if [[ -e "$_T99_DIR/.git" ]]; then _T99_HAS_GIT="$_T99_DIR"; break; fi
      _next="${_T99_DIR%/*}"
      [[ "$_next" == "$_T99_DIR" ]] && break
      _T99_DIR="$_next"
    done
    if [[ -n "$_T99_HAS_GIT" ]]; then
      mkdir -p "${HOME}/.ralph/logs" 2>/dev/null || true
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] git present but broken under $CWD ($_T99_HAS_GIT/.git); treating as no-git: $(head -c 200 "$_T87_OUT" | tr '\n' ' ')" \
        >> "${HOME}/.ralph/logs/anti-rationalization-gate.log" 2>/dev/null || true
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
  if [[ "$UPDATED_EPOCH" -eq 0 ]]; then
    UPDATED_EPOCH=$(stat -f %m "$PROJECT_PLAN_STATE" 2>/dev/null \
      || stat -c %Y "$PROJECT_PLAN_STATE" 2>/dev/null \
      || echo 0)
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
