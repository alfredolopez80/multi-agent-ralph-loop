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
# Idempotent: node ids are deterministic (derived from rule_id); re-running updates
# nodes in place, never duplicates.
#
# Usage:
#   scripts/memory/seed-dev-prohibitions.sh            # apply into current repo's tree
#   scripts/memory/seed-dev-prohibitions.sh --dry-run  # validate only, write nothing
#
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SEED_FILE="${SEED_FILE:-$HOME/.ralph/procedural/seed-dev-prohibitions.json}"

MIGRATE="$SCRIPT_DIR/migrate_rules_to_nodes.py"
PROJECT_MEMORY="$SCRIPT_DIR/project_memory.py"

# Fail loud and fast if any prerequisite is missing — never pretend success.
[[ -f "$SEED_FILE" ]]       || { echo "FATAL: seed file not found: $SEED_FILE" >&2; exit 1; }
[[ -f "$MIGRATE" ]]         || { echo "FATAL: migrator not found: $MIGRATE" >&2; exit 1; }
[[ -f "$PROJECT_MEMORY" ]]  || { echo "FATAL: project_memory not found: $PROJECT_MEMORY" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 not on PATH" >&2; exit 1; }

MODE="--apply"
if [[ "${1:-}" == "--dry-run" ]]; then
  MODE="--dry-run"
fi

echo "==> Migrating dev-prohibition rules into the Ralph Memory Tree ($MODE)"
python3 "$MIGRATE" --rules "$SEED_FILE" "$MODE"

if [[ "$MODE" == "--apply" ]]; then
  echo "==> Refreshing the read-only GREEN projection in MEMORY.md"
  python3 "$PROJECT_MEMORY" --apply

  echo "==> Verifying recall_v2 surfaces the new nodes"
  RECALL="$SCRIPT_DIR/recall_v2.py"
  [[ -f "$RECALL" ]] || { echo "FATAL: recall_v2 not found: $RECALL" >&2; exit 1; }
  MISSING=0
  for q in "placeholder in code" "unrequested fallback error handling" \
           "production code to pass a test" "e2e test minikube fail loud fail fast"; do
    if ! python3 "$RECALL" --query "$q" --limit 3 2>/dev/null \
         | grep -qE "rule_(dev-no-|testing-fail-loud)"; then
      echo "FAIL: no dev-prohibition node recalled for query: '$q'" >&2
      MISSING=1
    fi
  done
  [[ "$MISSING" -eq 0 ]] || { echo "FATAL: recall verification failed — nodes not surfaced" >&2; exit 1; }
  echo "OK: all 4 dev-prohibition rules are recallable in this project's tree."
fi
