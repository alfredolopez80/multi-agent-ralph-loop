#!/usr/bin/env bash
# phase0_inventory.sh — Phase 0 of issue #69 (Ralph-Lite delete-first simplification).
#
# Produces ONE executable inventory of the real runtime:
#   - every registration in the ACTIVE ~/.claude/settings.json
#   - .claude/security/settings.security-only.json
#   - .claude/security/SECURITY_BASELINE.json
#   - versioned installer/sync/validation artifacts
#   - sources under .claude/hooks, .claude/rules-src, .claude/agents, .claude/skills
#
# Every record is classified with exactly one owner:
#   SECURITY-REQUIRED | TASK-STATE-BOUNDARY | EXPLICIT/COLD-PATH | DELETE
#
# Outputs:
#   docs/benchmark/PHASE0_INVENTORY_2026-08-31.md   (baseline report)
#   results/phase0/inventory.tsv                    (raw classified rows)
#   results/phase0/settings-active.snapshot.json    (snapshot of the ACTIVE settings)
#
# Exit codes:
#   0  inventory complete, zero unknown entries
#   2  a required input could not be read/parsed (fail loud)
#   3  classification incomplete: unknown entries remain (fail loud)
#   4  selftest failed (fail loud)
#
# Usage:
#   bash scripts/benchmark/phase0_inventory.sh             # full inventory
#   bash scripts/benchmark/phase0_inventory.sh --selftest  # prove the UNKNOWN path fires
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)" || { echo "FATAL: not inside a git repository" >&2; exit 2; }
exec python3 "$ROOT/scripts/benchmark/phase0_inventory.py" "$ROOT" "$@"
