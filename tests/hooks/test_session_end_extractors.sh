#!/usr/bin/env bash
# test_session_end_extractors.sh — T95/C9 v4 (RETURN 3): verdict channel is
# a PRIVATE per-invocation file, not the machine-shared module logs.
#
# T1 COLD FUNCTIONALITY — committed files are extracted via transcript, with
#    PER-FILE assertions (order_service AND big.ts each proven) and the
#    SEM-exclusive marker "[code_structure]" (decision-extractor also writes
#    facts-*.md, so counting entries is not attribution). Dedupe is asserted
#    on the CONTENT of facts-*.md (md5 + line count) — never on file counts.
# T2 REGISTRY GUARD — as v2 (existence + executability, hot events incl.
#    PreToolUse/PreCompact, cold path registered, safety guards present).
# T3 CONCURRENCY (the reviewer's repro) — two wrappers at once, shared HOME
#    (shared module logs), one extractable file + one file the modules
#    reject by extension. Pre-fix (v3) the wrappers steal verdict lines from
#    the shared log and record a hash for the rejected file with ZERO
#    extraction of it (permanent false dedupe). v4 waits on its private
#    RALPH_VERDICT_FILE, so the rejected file must produce NO state hash and
#    the real file must still extract.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EXAMPLE="$REPO/.claude/settings.json.example"
WRAPPER="$REPO/.claude/hooks/session-end-extractors.sh"

PASS=0
FAIL=0
ok()  { echo "  OK   $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL $1"; [[ -n "${2:-}" ]] && echo "       $2"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
echo "=== T1: per-file cold extraction + content dedupe ==="
WORK=$(mktemp -d)
R="$WORK/repo"
mkdir -p "$R/src"
git -C "$R" init -q
git -C "$R" config user.email t95@test
git -C "$R" config user.name t95

cat > "$R/src/order_service.ts" <<'EOF'
export class OrderService {
  private repo: OrderRepository;
  async place(order: Order): Promise<Id> { return this.repo.save(order); }
}
export interface OrderRepository { save(o: Order): Promise<Id>; }
export function placeOrder(svc: OrderService, order: Order): Promise<Id> {
  return svc.place(order);
}
EOF
{
  echo "export function bigExportedFunction(): void {}"
  head -c 200000 /dev/zero | tr '\0' 'x'
} > "$R/src/big.ts"

# Standard workflow: committed — clean tree at session end.
git -C "$R" add -A
git -C "$R" commit -q -m "session work"

TL="$WORK/transcript.jsonl"
jq -cn --arg fp "$R/src/order_service.ts" --arg r "$R" \
  '{type:"assistant",cwd:$r,message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$fp,old_string:"",new_string:"c"}}]}}' >> "$TL"
jq -cn --arg fp "$R/src/big.ts" --arg r "$R" \
  '{type:"assistant",cwd:$r,message:{content:[{type:"tool_use",name:"Write",input:{file_path:$fp,content:"x"}}]}}' >> "$TL"

ISO_HOME="$WORK/home"; mkdir -p "$ISO_HOME"
export RALPH_VAULT_DIR="$WORK/vault"; mkdir -p "$RALPH_VAULT_DIR"

printf '{"session_id":"t95","reason":"clear","cwd":"%s","transcript_path":"%s"}' "$R" "$TL" \
  | HOME="$ISO_HOME" /bin/bash "$WRAPPER" >/dev/null 2>&1

# The wrapper logs "job finished" when its background job drained — wait for
# THAT signal instead of blind sampling (RETURN 3: drain_stable out).
FINISHED=0
for _ in $(seq 1 60); do
  sleep 0.5
  if grep -q "job finished" "$ISO_HOME/.ralph/logs/session-end-extractors.log" 2>/dev/null; then
    FINISHED=1
    break
  fi
done
if [[ "$FINISHED" -eq 1 ]]; then
  ok "background job reports finished (drain by signal, not by sampling)"
else
  bad "no 'job finished' in wrapper log within 30 s" \
    "$(tail -3 "$ISO_HOME/.ralph/logs/session-end-extractors.log" 2>/dev/null | tr '\n' ' ')"
fi

FACTS_FILE=$(find "$RALPH_VAULT_DIR/projects" -name 'facts-*.md' 2>/dev/null | head -1)
if [[ -n "$FACTS_FILE" ]] && grep -q "\[code_structure\]" "$FACTS_FILE"; then
  ok "order_service.ts: SEM-exclusive marker [code_structure] present in facts"
else
  bad "no [code_structure] fact for order_service.ts (semantic verdict unproven)" \
    "${FACTS_FILE:+$(head -3 "$FACTS_FILE")}"
fi
if [[ -n "$FACTS_FILE" ]] && grep -q "bigExportedFunction" "$FACTS_FILE"; then
  ok "big.ts: header pattern survived the content cap (per-file assertion)"
else
  bad "big.ts fact missing — 60KB+ file lost in the payload path" \
    "${FACTS_FILE:+$(head -3 "$FACTS_FILE")}"
fi
EP_N=$(find "$RALPH_VAULT_DIR/projects" -name 'ep-*.json' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${EP_N:-0}" -ge 1 ]]; then
  ok "decision-extractor produced episode(s) for the committed file(s) ($EP_N)"
else
  bad "no decisions from the cold path"
fi

# Dedupe on CONTENT: rerun the same transcript; facts-*.md bytes and episode
# count must not change (RETURN 3: never assert on file counts).
FACTS_MD5_BEFORE=$(md5 -q "$FACTS_FILE" 2>/dev/null || md5sum "$FACTS_FILE" 2>/dev/null | awk '{print $1}')
FACTS_LINES_BEFORE=$(wc -l < "$FACTS_FILE" 2>/dev/null | tr -d ' ')
printf '{"session_id":"t95b","reason":"clear","cwd":"%s","transcript_path":"%s"}' "$R" "$TL" \
  | HOME="$ISO_HOME" /bin/bash "$WRAPPER" >/dev/null 2>&1
FINISHED=0
for _ in $(seq 1 60); do
  sleep 0.5
  FINISHED_LINES=$(grep -c "job finished" "$ISO_HOME/.ralph/logs/session-end-extractors.log" 2>/dev/null)
  [[ "${FINISHED_LINES:-0}" -ge 2 ]] && { FINISHED=1; break; }
done
FACTS_MD5_AFTER=$(md5 -q "$FACTS_FILE" 2>/dev/null || md5sum "$FACTS_FILE" 2>/dev/null | awk '{print $1}')
FACTS_LINES_AFTER=$(wc -l < "$FACTS_FILE" 2>/dev/null | tr -d ' ')
EP_N_AFTER=$(find "$RALPH_VAULT_DIR/projects" -name 'ep-*.json' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FACTS_MD5_BEFORE" == "$FACTS_MD5_AFTER" && "$FACTS_LINES_BEFORE" == "$FACTS_LINES_AFTER" && "${EP_N_AFTER:-0}" -eq "${EP_N:-0}" ]]; then
  ok "content dedupe: facts-*.md unchanged ($FACTS_LINES_BEFORE lines) and episodes stable ($EP_N) on rerun"
else
  bad "rerun mutated the vault: facts $FACTS_LINES_BEFORE→$FACTS_LINES_AFTER lines, episodes $EP_N→$EP_N_AFTER"
fi
unset RALPH_VAULT_DIR
rm -rf "$WORK"

# ---------------------------------------------------------------------------
echo "=== T2: registry guard over .claude/settings.json.example ==="
if [[ ! -f "$EXAMPLE" ]]; then
  bad "settings.json.example not found at $EXAMPLE"
  echo "Passed: $PASS | Failed: $FAIL"
  exit $FAIL
fi

MAP=$(jq -r '.hooks | to_entries[] | .key as $ev | .value[] | .matcher as $m | .hooks[]? | "\($ev)\t\($m)\t\(.command)"' "$EXAMPLE" 2>/dev/null)

GHOSTS=$(printf '%s\n' "$MAP" | while IFS=$'\t' read -r ev mt cmd; do
  [[ -z "$ev" ]] && continue
  base=$(printf '%s' "$cmd" | grep -oE '[A-Za-z0-9._-]+\.(sh|py)' | head -1)
  [[ -z "$base" ]] && continue
  if [[ ! -f "$REPO/.claude/hooks/$base" ]]; then
    printf 'missing: %s (%s)\n' "$base" "$ev"
  elif [[ ! -x "$REPO/.claude/hooks/$base" ]]; then
    printf 'not-executable: %s (%s)\n' "$base" "$ev"
  fi
done | sort -u)
if [[ -z "$GHOSTS" ]]; then
  ok "every referenced hook exists and is executable"
else
  bad "dead or non-executable registrations" "$GHOSTS"
fi

MAINT="decision-extractor.sh semantic-realtime-extractor.sh semantic-auto-extractor.sh episodic-auto-convert.sh reflection-engine.sh memory-write-trigger.sh vault-fact-extractor.sh vault-graduation.sh vault-promotion.sh dream-consolidate.sh vault-writeback.sh memory-projection.sh vault-index-updater.sh vault-log-writer.sh vault-weekly-compile.sh session-end-extractors.sh"
HOT_VIOLATIONS=$(printf '%s\n' "$MAP" | while IFS=$'\t' read -r ev mt cmd; do
  case "$ev" in
    SessionStart|Stop|UserPromptSubmit|PostToolUse|PreToolUse|PreCompact) ;;
    *) continue ;;
  esac
  base=$(printf '%s' "$cmd" | grep -oE '[A-Za-z0-9._-]+\.(sh|py)' | head -1)
  for m in $MAINT; do
    if [[ "$base" == "$m" ]]; then
      printf '%s on %s [%s]\n' "$m" "$ev" "$mt"
    fi
  done
done | sort -u)
if [[ -z "$HOT_VIOLATIONS" ]]; then
  ok "no memory-maintenance hook on the ordinary hot-path events"
else
  bad "memory maintenance still registered on the ordinary hot path" "$HOT_VIOLATIONS"
fi

if printf '%s\n' "$MAP" | awk -F'\t' '$1=="SessionEnd"' | grep -q "session-end-extractors.sh"; then
  ok "cold extraction registered on SessionEnd"
else
  bad "session-end-extractors.sh is NOT registered on SessionEnd"
fi

BASH_HOOKS=$(printf '%s\n' "$MAP" | awk -F'\t' '$1=="PreToolUse" && $2=="Bash"' | grep -oE '[A-Za-z0-9._-]+\.(sh|py)' | sort -u)
MISSING_GUARDS=""
for g in git-safety-guard.py repo-boundary-guard.sh; do
  printf '%s\n' "$BASH_HOOKS" | grep -q "^$g$" || MISSING_GUARDS="$MISSING_GUARDS $g"
done
if [[ -z "$MISSING_GUARDS" ]]; then
  ok "PreToolUse(Bash) carries git-safety-guard.py and repo-boundary-guard.sh"
else
  bad "safety guards missing from PreToolUse(Bash):$MISSING_GUARDS"
fi

# ---------------------------------------------------------------------------
echo "=== T3: concurrency — simultaneous SessionEnds, shared HOME (reviewer repro) ==="
# A steals-verdict race is timing-dependent on a single shot: the test runs
# FOUR concurrent A(NOTES)+B(real) rounds and fails if ANY round records a
# hash for the rejected file or logs it as "extracted".
W3=$(mktemp -d)
R3="$W3/repo"
mkdir -p "$R3/src"
git -C "$R3" init -q
git -C "$R3" config user.email t95@test
git -C "$R3" config user.name t95
cat > "$R3/src/real_service.ts" <<'EOF'
export class RealService { }
export interface RealRepo { save(o: R): Promise<Id>; }
export function realFunction(s: RealService): void {}
EOF
# NOTES.md is the rejected-by-extension file AND its content is engineered to
# break the pre-fix payload: 55KB of quote characters expand past the 100KB
# stdin guard once jq escapes them (measured >1.66x), so the modules parse a
# CUT-OFF JSON and emit NO verdict of their own. The pre-fix verdict wait
# then stays open for its whole timeout on the SHARED module log — the window
# in which the OTHER wrapper's "Created episode" line gets stolen and
# recorded as NOTES.md (zero extraction of NOTES.md itself).
{
  echo "# notes: markdown the modules reject by extension"
  python3 -c "print('\"' * 55000)"
} > "$R3/src/NOTES.md"
git -C "$R3" add -A
git -C "$R3" commit -q -m w
R3=$(cd "$R3" && pwd -P)
TL3A="$W3/transcript-notes.jsonl"    # wrapper A: ONLY the rejected file
TL3B="$W3/transcript-real.jsonl"     # wrapper B: ONLY the real file
jq -cn --arg fp "$R3/src/NOTES.md" --arg r "$R3" \
  '{type:"assistant",cwd:$r,message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$fp,old_string:"",new_string:"c"}}]}}' >> "$TL3A"
jq -cn --arg fp "$R3/src/real_service.ts" --arg r "$R3" \
  '{type:"assistant",cwd:$r,message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$fp,old_string:"",new_string:"c"}}]}}' >> "$TL3B"

CONTAMINATED=0
REAL_OK=0
for attempt in 1 2 3 4; do
  H3="$W3/home-$attempt"; mkdir -p "$H3"   # shared per-round: module logs are per-machine
  VD3="$W3/vault-$attempt"; mkdir -p "$VD3"
  printf '{"session_id":"cA-%s","reason":"clear","cwd":"%s","transcript_path":"%s"}' "$attempt" "$R3" "$TL3A" \
    | HOME="$H3" RALPH_VAULT_DIR="$VD3" /bin/bash "$WRAPPER" >/dev/null 2>&1 &
  printf '{"session_id":"cB-%s","reason":"clear","cwd":"%s","transcript_path":"%s"}' "$attempt" "$R3" "$TL3B" \
    | HOME="$H3" RALPH_VAULT_DIR="$VD3" /bin/bash "$WRAPPER" >/dev/null 2>&1 &
  wait $! 2>/dev/null
  # Drain by signal: both background jobs report finished (timeout 30 s).
  for _ in $(seq 1 60); do
    sleep 0.5
    [[ "$(grep -c "job finished" "$H3/.ralph/logs/session-end-extractors.log" 2>/dev/null)" -ge 2 ]] && break
  done
  sleep 1
  STATE_FILE=$(find "$H3/.ralph/state/session-end-extractors" -name '*.hashes' 2>/dev/null | head -1)
  NSIZE=$(wc -c < "$R3/src/NOTES.md" 2>/dev/null | tr -d ' ')
  NCONTENT=$(head -c 30000 "$R3/src/NOTES.md" 2>/dev/null)
  NHASH=$(printf '%s:%s' "$NSIZE" "$NCONTENT" | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | awk '{print $1}')
  if [[ -n "$STATE_FILE" ]] && grep -qxF "$NHASH" "$STATE_FILE" 2>/dev/null; then
    CONTAMINATED=$((CONTAMINATED + 1))
  fi
  grep -q "extracted.*NOTES.md" "$H3/.ralph/logs/session-end-extractors.log" 2>/dev/null \
    && CONTAMINATED=$((CONTAMINATED + 1))
  find "$VD3/projects" -name 'ep-*.json' 2>/dev/null | grep -q . && REAL_OK=$((REAL_OK + 1))
  rm -rf "$H3" "$VD3"
done

if [[ "$CONTAMINATED" -eq 0 ]]; then
  ok "4 concurrent rounds: rejected-by-extension file never hashed nor logged as extracted"
else
  bad "verdict theft under concurrency: $CONTAMINATED/4 rounds contaminated NOTES.md" \
    "reviewer finding — private verdict channel not in effect"
fi
if [[ "$REAL_OK" -ge 1 ]]; then
  ok "real file extracted in $REAL_OK/4 concurrent rounds"
else
  bad "real file never extracted under concurrency"
fi
rm -rf "$W3"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
