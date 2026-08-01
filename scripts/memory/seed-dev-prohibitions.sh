#!/usr/bin/env bash
#
# seed-dev-prohibitions.sh — Graduate the 4 global dev-prohibition rules into the
# Ralph Memory Tree (recall_v2 / Codex recall) for the CURRENT project.
#
# The Memory Tree is PROJECT-SCOPED by design (recall_v2 hard-rejects nodes from a
# different project_id — this is intentional per-project isolation, not a bug).
# Run this from inside any repo where you want Codex recall to surface these rules.
# Global coverage (all projects) is already provided by ~/.claude/CLAUDE.md and
# ~/.claude/rules/proven/*.md — this script only adds the in-repo recall layer.
#
# The rule definitions ship in-repo at scripts/memory/seed-data/dev-prohibitions.json
# so the seeder is reproducible in any clone. Override with SEED_FILE=<path> if needed.
#
# Idempotent: node ids are deterministic (derived from rule_id); re-running updates
# nodes in place, never duplicates.
#
# Usage:
#   scripts/memory/seed-dev-prohibitions.sh            # apply into current repo's tree
#   scripts/memory/seed-dev-prohibitions.sh --dry-run  # validate only, write nothing
#   SEED_FILE=/path/to/rules.json scripts/memory/seed-dev-prohibitions.sh  # custom seed
#
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SEED_FILE="${SEED_FILE:-$SCRIPT_DIR/seed-data/dev-prohibitions.json}"

MIGRATE="$SCRIPT_DIR/migrate_rules_to_nodes.py"
PROJECT_MEMORY="$SCRIPT_DIR/project_memory.py"

# Validate arguments first (fail fast on misuse, before touching anything).
MODE="--apply"
case "${1:-}" in
  ""|--apply) MODE="--apply" ;;
  --dry-run)  MODE="--dry-run" ;;
  *) echo "FATAL: unknown argument: ${1}. Usage: $(basename "$0") [--apply|--dry-run]" >&2; exit 1 ;;
esac

# Fail loud and fast if any prerequisite is missing — never pretend success.
[[ -f "$SEED_FILE" ]]       || { echo "FATAL: seed file not found: $SEED_FILE" >&2; exit 1; }
[[ -f "$MIGRATE" ]]         || { echo "FATAL: migrator not found: $MIGRATE" >&2; exit 1; }
[[ -f "$PROJECT_MEMORY" ]]  || { echo "FATAL: project_memory not found: $PROJECT_MEMORY" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 not on PATH" >&2; exit 1; }

echo "==> Migrating dev-prohibition rules into the Ralph Memory Tree ($MODE)"
python3 "$MIGRATE" --rules "$SEED_FILE" "$MODE"

if [[ "$MODE" == "--apply" ]]; then
  echo "==> Refreshing the read-only GREEN projection in MEMORY.md"
  python3 "$PROJECT_MEMORY" --apply

  echo "==> Verifying recall_v2 surfaces the new nodes"
  RECALL="$SCRIPT_DIR/recall_v2.py"
  [[ -f "$RECALL" ]] || { echo "FATAL: recall_v2 not found: $RECALL" >&2; exit 1; }

  # Derive the rule list from the seed file. A hardcoded set of queries (and a hardcoded
  # "all 4" in the success line) silently stopped covering the seed the moment a fifth
  # rule was added: the check kept passing while verifying less than it claimed. Per
  # `testing-zero-tests-is-never-success`, a verifier must prove it actually checked
  # something, and that the count matches what exists.
  mapfile -t RULE_IDS < <(python3 -c '
import json, sys
for rule in json.load(open(sys.argv[1])):
    print(rule["rule_id"])
' "$SEED_FILE")

  EXPECTED="${#RULE_IDS[@]}"
  [[ "$EXPECTED" -gt 0 ]] || { echo "FATAL: seed file declares zero rules: $SEED_FILE" >&2; exit 1; }

  MISSING=0
  VERIFIED=0
  for rule_id in "${RULE_IDS[@]}"; do
    # Query by rule id: recall_v2 is semantic, and the id carries the rule's own terms.
    if python3 "$RECALL" --query "${rule_id//-/ }" --limit 5 | grep -q "rule_${rule_id}"; then
      VERIFIED=$((VERIFIED+1))
    else
      echo "FAIL: node 'rule_${rule_id}' is not recallable" >&2
      MISSING=$((MISSING+1))
    fi
  done

  [[ "$MISSING" -eq 0 ]] || { echo "FATAL: recall verification failed — $MISSING node(s) not surfaced" >&2; exit 1; }
  [[ "$VERIFIED" -eq "$EXPECTED" ]] || {
    echo "FATAL: verified $VERIFIED of $EXPECTED rules — refusing to report success" >&2
    exit 1
  }
  echo "OK: all $VERIFIED of $EXPECTED seeded rules are recallable in this project's tree."
fi
