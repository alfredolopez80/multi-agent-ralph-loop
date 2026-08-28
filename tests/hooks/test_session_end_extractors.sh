#!/usr/bin/env bash
# test_session_end_extractors.sh — T95/C9 (#47): memory maintenance out of the
# ordinary hot path, without losing it. Two guarantees:
#
#   T1 COLD FUNCTIONALITY — session-end-extractors.sh (registered on SessionEnd)
#      really runs the extractor modules: decisions land in the sandbox vault
#      for a dirty fixture file. "You didn't break it, you moved it."
#   T2 REGISTRY GUARD —
#      (a) every hook referenced by .claude/settings.json.example exists in
#          .claude/hooks/ (dead registrations fail the run, never silently);
#      (b) NO memory-maintenance hook fires on the ordinary hot-path events
#          (SessionStart / Stop / UserPromptSubmit / PostToolUse);
#      (c) the cold path (session-end-extractors on SessionEnd) IS registered.
#
# T2 runs against the template (the versioned registry the repo ships). The
# user's live ~/.claude/settings.json is out of scope by design (configuration
# belongs to the human); its migration recipe lives in the task report.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EXAMPLE="$REPO/.claude/settings.json.example"
WRAPPER="$REPO/.claude/hooks/session-end-extractors.sh"

PASS=0
FAIL=0
ok()  { echo "  OK   $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL $1"; [[ -n "${2:-}" ]] && echo "       $2"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
echo "=== T1: cold path still extracts (SessionEnd wrapper, sandbox vault) ==="
WORK=$(mktemp -d)
R="$WORK/repo"
mkdir -p "$R"
git -C "$R" init -q
git -C "$R" config user.email t95@test
git -C "$R" config user.name t95
mkdir -p "$R/src"
cat > "$R/src/order_service.ts" <<'EOF'
export class OrderService {
  private repo: OrderRepository;
  async place(order: Order): Promise<Id> { return this.repo.save(order); }
}
export interface OrderRepository { save(o: Order): Promise<Id>; }
EOF
# Dirty worktree: the wrapper extracts from `git status`, so the file must NOT
# be committed. The initial commit gives the repo a valid HEAD.
git -C "$R" add -A
git -C "$R" commit -q -m "init" --allow-empty
printf '\n// t95 touched during session\nexport const marker = 1;\n' >> "$R/src/order_service.ts"
ISO_HOME="$WORK/home"; mkdir -p "$ISO_HOME"
export RALPH_VAULT_DIR="$WORK/vault"; mkdir -p "$RALPH_VAULT_DIR"

if [[ -x "$WRAPPER" || -f "$WRAPPER" ]]; then
  printf '{"session_id":"t95","reason":"clear","cwd":"%s"}' "$R" \
    | HOME="$ISO_HOME" /bin/bash "$WRAPPER" >/dev/null 2>&1
  # The wrapper forks one background job; poll up to 10 s, then fail loud.
  FOUND=0
  for _ in $(seq 1 20); do
    sleep 0.5
    if [[ "$(find "$RALPH_VAULT_DIR/projects" -path '*decisions*' -name 'ep-*.json' 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ]]; then
      FOUND=1
      break
    fi
  done
  if [[ "$FOUND" -eq 1 ]]; then
    ok "decision-extractor produced decisions via the SessionEnd cold path"
  else
    bad "no decisions written by the cold path in 10 s (extraction broken by the move?)" \
      "$(find "$RALPH_VAULT_DIR" -type f 2>/dev/null | head -3 | tr '\n' ' ')"
  fi
else
  bad "wrapper missing: $WRAPPER" "cold path not implemented yet"
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

# (event, command) pairs for every registered hook
MAP=$(jq -r '.hooks | to_entries[] | .key as $ev | .value[] | .hooks[]? | "\($ev)\t\(.command)"' "$EXAMPLE" 2>/dev/null)

# (a) every referenced hook script exists in the repo
GHOSTS=$(printf '%s\n' "$MAP" | while IFS=$'\t' read -r ev cmd; do
  [[ -z "$ev" ]] && continue
  base=$(printf '%s' "$cmd" | grep -oE '[A-Za-z0-9._-]+\.sh' | head -1)
  [[ -z "$base" ]] && continue
  [[ -f "$REPO/.claude/hooks/$base" ]] || printf '%s (%s)\n' "$base" "$ev"
done | sort -u)
if [[ -z "$GHOSTS" ]]; then
  ok "no dead registrations (every referenced .sh exists in .claude/hooks/)"
else
  bad "dead registrations found (hooks that would fork-fail at runtime)" "$GHOSTS"
fi

# (b) no memory-maintenance hook on the ordinary hot-path events
MAINT="decision-extractor.sh semantic-realtime-extractor.sh semantic-auto-extractor.sh episodic-auto-convert.sh reflection-engine.sh memory-write-trigger.sh vault-fact-extractor.sh vault-graduation.sh vault-promotion.sh dream-consolidate.sh vault-writeback.sh memory-projection.sh vault-index-updater.sh vault-log-writer.sh vault-weekly-compile.sh session-end-extractors.sh"
HOT_VIOLATIONS=$(printf '%s\n' "$MAP" | while IFS=$'\t' read -r ev cmd; do
  case "$ev" in
    SessionStart|Stop|UserPromptSubmit|PostToolUse) ;;
    *) continue ;;
  esac
  base=$(printf '%s' "$cmd" | grep -oE '[A-Za-z0-9._-]+\.sh' | head -1)
  for m in $MAINT; do
    if [[ "$base" == "$m" ]]; then
      printf '%s on %s\n' "$m" "$ev"
    fi
  done
done | sort -u)
if [[ -z "$HOT_VIOLATIONS" ]]; then
  ok "no memory-maintenance hook on SessionStart/Stop/UserPromptSubmit/PostToolUse"
else
  bad "memory maintenance still registered on the ordinary hot path" "$HOT_VIOLATIONS"
fi

# (c) the cold path is registered where it belongs
if printf '%s\n' "$MAP" | awk -F'\t' '$1=="SessionEnd"' | grep -q "session-end-extractors.sh"; then
  ok "cold extraction registered on SessionEnd (session-end-extractors.sh)"
else
  bad "session-end-extractors.sh is NOT registered on SessionEnd"
fi

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
