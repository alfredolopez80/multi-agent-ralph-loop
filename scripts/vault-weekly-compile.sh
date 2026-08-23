#!/usr/bin/env bash
# vault-weekly-compile.sh — Weekly vault compilation and backup
# VERSION: 3.0.0
#
# Se dispara desde el hook SessionEnd, no desde cron: macOS (TCC) niega a cron
# el acceso a ~/Documents, asi que las 22 ejecuciones desde abril fallaron con
# 'Operation not permitted' sin ejecutar una linea. El guard semanal sigue
# vigente: solo hace trabajo una vez por semana.
#
# What it does:
# 1. Check if vault exists
# 2. Count new lessons since last compile
# 3. Update vault indices
# 4. Git commit + push to private repo
# 5. Log results
#
# Cron schedule (installed by this script):
#   Friday 6PM:   0 18 * * 5
#   Saturday 9AM: 0 9 * * 6 (catch-up if Friday missed)
#   Sunday 9AM:   0 9 * * 0 (catch-up if Saturday missed)

set -euo pipefail

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
# Raiz del repo derivada de la ubicacion real de este script, ANTES de cualquier cd.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$HOME/.ralph/logs"
LOG_FILE="$LOG_DIR/vault-compile.log"
LOCK_FILE="/tmp/vault-weekly-compile.lock"
LAST_RUN_FILE="$VAULT_DIR/.last-compile"

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        log "SKIP: Another compile is running (PID $pid)"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Check if vault exists
if [ ! -d "$VAULT_DIR" ]; then
    log "ERROR: Vault not found at $VAULT_DIR"
    exit 1
fi

# Check if already compiled this week
if [ -f "$LAST_RUN_FILE" ]; then
    last_run=$(cat "$LAST_RUN_FILE")
    current_week=$(date +%Y-W%V)
    if [ "$last_run" = "$current_week" ]; then
        log "SKIP: Already compiled this week ($current_week)"
        exit 0
    fi
fi

log "=== Weekly Vault Compile ==="

# Count new lessons
cd "$VAULT_DIR"
new_lessons=0
for project_dir in projects/*/lessons/; do
    if [ -d "$project_dir" ]; then
        count=$(find "$project_dir" -name "*.md" -newer "$LAST_RUN_FILE" 2>/dev/null | wc -l || echo 0)
        new_lessons=$((new_lessons + count))
    fi
done
log "New lessons since last compile: $new_lessons"

# Los indices (_vault-index.md, wiki/_index.md, projects/_project-index.md) los
# mantiene el hook registrado vault-index-updater.sh en SessionEnd. Este bloque
# los regeneraba por duplicado; ademas nunca corrio: el cron fallaba antes de
# ejecutar una sola linea (22 disparos, 22 'Operation not permitted').

# ──────────────────────────────────────────────
# Sync learned rules to global (MemPalace v3.2)
# Ensures Friday cron propagates local learnings to ~/.claude/rules/learned/
# ──────────────────────────────────────────────
if [[ -f "${REPO_ROOT}/.claude/scripts/sync-rules-from-source.sh" ]]; then
    log "Syncing learned rules to global..."
    # El `2>/dev/null || true` anterior era un fallback silencioso: aunque la ruta
    # se hubiera arreglado, un fallo del sync habria quedado enmascarado.
    # NO bloqueante por contrato (el cron aun tiene que commitear el vault), pero
    # el `2>/dev/null || true` anterior tampoco dejaba rastro del fallo. Aqui el
    # error se registra de forma visible y el job continua.
    sync_rc=0
    bash "${REPO_ROOT}/.claude/scripts/sync-rules-from-source.sh" >> "$LOG_FILE" 2>&1 || sync_rc=$?
    if [[ $sync_rc -eq 0 ]]; then
        log "Rules sync complete"
    else
        log "ERROR: rules sync FAILED (exit $sync_rc) — see $LOG_FILE; continuing"
    fi
else
    log "ERROR: sync script missing at ${REPO_ROOT}/.claude/scripts/ — repo layout broken; continuing"
fi

# Git commit + push
if [ -d ".git" ]; then
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "vault: weekly compile $(date '+%Y-%m-%d') ($new_lessons new lessons)"
        git push origin main 2>/dev/null && log "Pushed to GitHub" || log "Push failed (offline?)"
    else
        log "No changes to commit"
    fi
fi

# Record this week's compile
date +%Y-W%V > "$LAST_RUN_FILE"
log "=== Compile Complete ==="
