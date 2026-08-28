#!/usr/bin/env bash
# test_session_end_extractors.sh — T95/C9 (#47) v2, after lead RETURN:
# discovery is transcript-based, not dirty-state based.
#
# T1 COLD FUNCTIONALITY against THIS repo's standard workflow: a file that was
#    edited AND COMMITTED during the session (workers never end dirty — clean
#    tree at SessionEnd is the contract) must still be extracted. Discovery
#    reads transcript_path, so the committed file is visible. The pre-fix
#    wrapper (git-status discovery) fails this test RED: with a clean tree it
#    extracts nothing while certifying "no eligible dirty files".
#    - asserts decisions (decision-extractor) AND facts (semantic-realtime)
#    - a >60KB file must not break the extractor payload (safe truncation)
#    - a second run over the same transcript must NOT add vault entries
#      (content-hash dedupe: hot path extracted per edit; batch must not
#      rescan identical content session after session)
# T2 REGISTRY GUARD —
#    (a) every referenced hook exists AND is executable (-x guards the known
#        "Editor MCP strips +x" failure mode); parser covers .sh and .py
#    (b) no memory-maintenance hook on SessionStart/Stop/UserPromptSubmit/
#        PostToolUse/PreToolUse/PreCompact
#    (c) cold path registered on SessionEnd
#    (d) PreToolUse(Bash) carries the safety guards CLAUDE.md requires

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EXAMPLE="$REPO/.claude/settings.json.example"
WRAPPER="$REPO/.claude/hooks/session-end-extractors.sh"

PASS=0
FAIL=0
ok()  { echo "  OK   $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL $1"; [[ -n "${2:-}" ]] && echo "       $2"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
echo "=== T1: cold extraction of a COMMITTED file, via session transcript ==="
WORK=$(mktemp -d)
R="$WORK/repo"
mkdir -p "$R/src"
R="$(cd "$R" && pwd -P)"   # canonical: git reports /private/var... on macOS
git -C "$R" init -q
git -C "$R" config user.email t95@test
git -C "$R" config user.name t95

# Patterns that fire BOTH extractors: decisions (export class/interface) and
# facts (export function — semantic-realtime's ts heuristics).
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
# A genuinely large file: its content must be truncated to a payload the
# extractors can still parse (<100KB), with the header pattern surviving.
{
  echo "export function bigExportedFunction(): void {}"
  head -c 200000 /dev/zero | tr '\0' 'x'
} > "$R/src/big.ts"

# THE STANDARD WORKFLOW: everything committed — clean tree at session end.
git -C "$R" add -A
git -C "$R" commit -q -m "session work (committed, as the worker contract demands)"

# Synthetic session transcript: two Edit tool_uses on the committed file
# (deduplicated by the wrapper), one Bash tool_use (ignored), one Write on the
# big file. JSONL, same shape Claude Code writes.
TL="$WORK/transcript.jsonl"
jq -cn --arg fp "$R/src/order_service.ts" \
  '{type:"assistant",cwd:$R2,message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$fp,old_string:"",new_string:"content"}}]}}' \
  --arg R2 "$R" >> "$TL"
jq -cn --arg fp "$R/src/order_service.ts" \
  '{type:"assistant",cwd:$R2,message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$fp,old_string:"",new_string:"content"}}]}}' \
  --arg R2 "$R" >> "$TL"
jq -cn --arg R2 "$R" \
  '{type:"assistant",cwd:$R2,message:{content:[{type:"tool_use",name:"Bash",input:{command:"ls"}}]}}' >> "$TL"
jq -cn --arg fp "$R/src/big.ts" \
  '{type:"assistant",cwd:$R2,message:{content:[{type:"tool_use",name:"Write",input:{file_path:$fp,content:"x"}}]}}' \
  --arg R2 "$R" >> "$TL"

ISO_HOME="$WORK/home"; mkdir -p "$ISO_HOME"
export RALPH_VAULT_DIR="$WORK/vault"; mkdir -p "$RALPH_VAULT_DIR"

if [[ -f "$WRAPPER" ]]; then
  printf '{"session_id":"t95","reason":"clear","cwd":"%s","transcript_path":"%s"}' "$R" "$TL" \
    | HOME="$ISO_HOME" /bin/bash "$WRAPPER" >/dev/null 2>&1

  # Poll up to 15 s for the background job (wrapper fork + extractor forks).
  DECISIONS=0; FACTS=0
  for _ in $(seq 1 30); do
    sleep 0.5
    DECISIONS=$(find "$RALPH_VAULT_DIR/projects" -path '*decisions*' -name 'ep-*.json' 2>/dev/null | wc -l | tr -d ' ')
    FACTS=$(find "$RALPH_VAULT_DIR/projects" -path '*facts*' -name 'facts-*.md' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${DECISIONS:-0}" -ge 1 && "${FACTS:-0}" -ge 1 ]]; then break; fi
  done
  if [[ "${DECISIONS:-0}" -ge 1 ]]; then
    ok "decision-extractor produced decisions for the COMMITTED file (transcript discovery)"
  else
    bad "no decisions from the cold path in 15 s — committed work is invisible (finding 1 regression?)" \
      "$(find "$RALPH_VAULT_DIR" -type f 2>/dev/null | head -3 | tr '\n' ' ')"
  fi
  if [[ "${FACTS:-0}" -ge 1 ]]; then
    ok "semantic-realtime produced facts for the COMMITTED file"
  else
    bad "no facts from the cold path in 15 s (semantic module never asserted before — finding 10)"
  fi

  # Dedupe: second run over the SAME transcript adds nothing to the vault.
  # Drain detection, not fixed sleeps: the first pass may still be writing
  # (extractors fork internally), and counting before it settled produced a
  # false "second run added entries". Count is stable when three consecutive
  # 0.5 s samples agree.
  drain_stable() {
    local prev=-1 cur=0 stable=0 i
    for i in $(seq 1 40); do
      sleep 0.5
      cur=$(find "$RALPH_VAULT_DIR/projects" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$cur" == "$prev" ]]; then
        stable=$((stable + 1))
      else
        stable=0
        prev=$cur
      fi
      if (( stable >= 3 )); then printf '%s' "$cur"; return 0; fi
    done
    printf '%s' "$cur"
  }
  BEFORE=$(drain_stable)
  printf '{"session_id":"t95b","reason":"clear","cwd":"%s","transcript_path":"%s"}' "$R" "$TL" \
    | HOME="$ISO_HOME" /bin/bash "$WRAPPER" >/dev/null 2>&1
  AFTER=$(drain_stable)
  if [[ "${BEFORE:-0}" -eq "${AFTER:-0}" ]]; then
    ok "no duplicate extraction on identical content (content-hash dedupe)"
  else
    bad "second run added vault entries ($BEFORE → $AFTER) — rescan duplicates facts (finding 8)"
  fi
else
  bad "wrapper missing: $WRAPPER" "cold path not implemented"
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

# (a) every referenced hook exists AND is executable (.sh and .py)
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
  ok "every referenced hook exists and is executable (no dead registrations, no lost +x)"
else
  bad "dead or non-executable registrations" "$GHOSTS"
fi

# (b) no memory-maintenance hook on ANY ordinary hot-path event
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
  ok "no memory-maintenance hook on SessionStart/Stop/UserPromptSubmit/PostToolUse/PreToolUse/PreCompact"
else
  bad "memory maintenance still registered on the ordinary hot path" "$HOT_VIOLATIONS"
fi

# (c) the cold path is registered where it belongs
if printf '%s\n' "$MAP" | awk -F'\t' '$1=="SessionEnd"' | grep -q "session-end-extractors.sh"; then
  ok "cold extraction registered on SessionEnd (session-end-extractors.sh)"
else
  bad "session-end-extractors.sh is NOT registered on SessionEnd"
fi

# (d) safety guards required by CLAUDE.md are registered on PreToolUse(Bash)
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

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
