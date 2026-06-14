#!/usr/bin/env bash
set -euo pipefail

# validate-hooks-v2.sh — Valida hooks de Claude Code contra la API actual
# Detecta: JSON invalido, campos inexistentes, sintaxis rota, umask faltante

HOOKS_DIR="${1:-.claude/hooks}"
EXIT_CODE=0
ISSUES=0

echo "🔍 Validando hooks en: $HOOKS_DIR"
echo "================================"

# 1. Patrones JSON invalidos en CODIGO ACTIVO (excluye comentarios)
echo ""
echo "[1] Patrones JSON invalidos en codigo activo..."
while IFS= read -r line; do
  [ -z "$line" ] && continue
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  content=$(echo "$line" | cut -d: -f3-)
  # Skip if line is a comment or already FIXED
  if echo "$content" | grep -qE '^\s*#' ; then continue; fi
  if echo "$content" | grep -q 'FIXED'; then continue; fi
  echo "  ❌ $(basename "$file"):$lineno → $content"
  EXIT_CODE=1; ISSUES=$((ISSUES+1))
done < <(grep -rn '"decision"[[:space:]]*:[[:space:]]*"approve"' "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.py "$HOOKS_DIR"/*.js 2>/dev/null || true)

while IFS= read -r line; do
  [ -z "$line" ] && continue
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  content=$(echo "$line" | cut -d: -f3-)
  if echo "$content" | grep -qE '^\s*#' ; then continue; fi
  if echo "$content" | grep -q 'FIXED'; then continue; fi
  echo "  ❌ $(basename "$file"):$lineno → campo 'decision: continue' invalido"
  EXIT_CODE=1; ISSUES=$((ISSUES+1))
done < <(grep -rn '"decision"[[:space:]]*:[[:space:]]*"continue"' "$HOOKS_DIR"/*.sh 2>/dev/null || true)

# 2. Campos JSON inexistentes (feedback, cleanup en outputs con decision)
echo ""
echo "[2] Campos JSON inexistentes..."
while IFS= read -r line; do
  [ -z "$line" ] && continue
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  content=$(echo "$line" | cut -d: -f3-)
  if echo "$content" | grep -qE '^\s*#' ; then continue; fi
  if echo "$content" | grep -q 'FIXED'; then continue; fi
  # Only flag if in an echo/printf context (actual JSON output)
  if echo "$content" | grep -qE '(echo|printf)'; then
    echo "  ❌ $(basename "$file"):$lineno → campo 'feedback' invalido en JSON output"
    EXIT_CODE=1; ISSUES=$((ISSUES+1))
  fi
done < <(grep -rn '"feedback"' "$HOOKS_DIR"/*.sh 2>/dev/null | grep 'decision' || true)

# 3. Sintaxis bash
echo ""
echo "[3] Verificando sintaxis..."
for f in "$HOOKS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  if ! bash -n "$f" 2>/dev/null; then
    echo "  ❌ Sintaxis: $(basename "$f")"
    EXIT_CODE=1; ISSUES=$((ISSUES+1))
  fi
  [ -x "$f" ] || echo "  ⚠️  No ejecutable: $(basename "$f")"
done

# 4. umask 077 (defense in depth)
echo ""
echo "[4] Verificando umask 077..."
for f in "$HOOKS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  grep -q 'umask 077' "$f" 2>/dev/null || echo "  ⚠️  Falta umask 077: $(basename "$f")"
done

# Resumen
echo ""
echo "================================"
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✅ Validacion pasada. $ISSUES problemas criticos."
else
  echo "❌ $ISSUES problemas encontrados."
  echo "   Ejecuta: bash fix-hook-formats.sh $HOOKS_DIR"
fi
exit "$EXIT_CODE"
