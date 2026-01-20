#!/bin/bash
# orchestrator-helper.sh - Orquestación multi-agente con Codex-First
# Se activa SOLO cuando el usuario confirma modo plan/orquestación

# Parámetros:
# $1 = tipo de tarea (technical_complex | strategic_complex | ultra_complex)
# $2 = path absoluto del proyecto
# $3 = instrucción del usuario

# VERSION: 2.57.4
TASK_TYPE="${1:-technical_complex}"
PROJECT_PATH="${2:-$(pwd)}"
USER_INSTRUCTION="$3"

# Directorio temporal para resultados
TMP_DIR="/tmp/claude-orchestrator-$$"
mkdir -p "$TMP_DIR"

# Función de limpieza
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Logging
log() {
  echo "[orchestrator] $1" >&2
}

log "Iniciando orquestación multi-agente"
log "Tipo: $TASK_TYPE"
log "Proyecto: $PROJECT_PATH"

# ============================================================================
# CASO 1: Tarea Técnica Compleja (Codex como technical heavy lifter)
# ============================================================================
if [[ "$TASK_TYPE" == "technical_complex" ]]; then
  log "Ejecutando flujo TÉCNICO COMPLEJO"

  # 1. Lanzar Codex (Technical Heavy Lifter) - Background
  log "Lanzando Codex (gpt-5.2-codex) para análisis técnico..."
  cd "$PROJECT_PATH" && \
    codex exec -m gpt-5.2-codex --reasoning medium \
    "$USER_INSTRUCTION" > "$TMP_DIR/codex-output.json" 2>&1 &
  CODEX_PID=$!

  # 2. Lanzar Sonnet 4.5 para validación secundaria - Background
  log "Lanzando Sonnet 4.5 para validación..."
  cd "$PROJECT_PATH" && \
    claude --print -m sonnet \
    "Validación rápida: $USER_INSTRUCTION" > "$TMP_DIR/sonnet-validation.txt" 2>&1 &
  SONNET_PID=$!

  # 3. Esperar resultados
  log "Esperando resultados de Codex..."
  wait $CODEX_PID
  CODEX_EXIT=$?

  log "Esperando resultados de Sonnet..."
  wait $SONNET_PID
  SONNET_EXIT=$?

  # 4. Síntesis con Claude Opus
  log "Síntesis final con Claude Opus..."
  claude --print -m opus <<EOF
Sintetiza los siguientes análisis técnicos:

## Análisis Técnico (Codex):
$(cat "$TMP_DIR/codex-output.json" 2>/dev/null || echo "Error: Codex falló con código $CODEX_EXIT")

## Validación (Sonnet 4.5):
$(cat "$TMP_DIR/sonnet-validation.txt" 2>/dev/null || echo "Error: Sonnet falló con código $SONNET_EXIT")

## Tarea del Usuario:
$USER_INSTRUCTION

Genera un reporte final consolidado para el usuario.
EOF

# ============================================================================
# CASO 2: Tarea Estratégica Compleja (Opus como main driver)
# ============================================================================
elif [[ "$TASK_TYPE" == "strategic_complex" ]]; then
  log "Ejecutando flujo ESTRATÉGICO COMPLEJO"

  # 1. Lanzar Codex para análisis técnico - Background
  log "Lanzando Codex para análisis técnico de opciones..."
  cd "$PROJECT_PATH" && \
    codex exec -m gpt-5.2-codex --reasoning medium \
    "Análisis técnico de: $USER_INSTRUCTION" > "$TMP_DIR/codex-analysis.json" 2>&1 &
  CODEX_PID=$!

  # 2. Esperar resultado de Codex
  log "Esperando análisis técnico de Codex..."
  wait $CODEX_PID
  CODEX_EXIT=$?

  # 3. Opus sintetiza y decide (con ayuda de Sonnet para síntesis)
  log "Claude Opus realizando análisis estratégico..."
  claude --print -m opus <<EOF
Análisis estratégico basado en datos técnicos:

## Datos Técnicos (Codex):
$(cat "$TMP_DIR/codex-analysis.json" 2>/dev/null || echo "Error: Codex falló con código $CODEX_EXIT")

## Tarea del Usuario:
$USER_INSTRUCTION

Evalúa trade-offs, pros/cons y recomienda la mejor estrategia.
EOF

# ============================================================================
# CASO 3: Tarea Ultra-Compleja (Opus + UltraThink)
# ============================================================================
elif [[ "$TASK_TYPE" == "ultra_complex" ]]; then
  log "Ejecutando flujo ULTRA-COMPLEJO (UltraThink activado)"
  log "⚠️  ADVERTENCIA: Alto costo de procesamiento"

  # 1. Lanzar Codex (Security + Architecture) - Background
  log "Lanzando Codex para security audit + architecture review..."
  cd "$PROJECT_PATH" && \
    codex exec -m gpt-5.2-codex --reasoning high \
    "Security audit + architecture review: $USER_INSTRUCTION" > "$TMP_DIR/codex-security.json" 2>&1 &
  CODEX_PID=$!

  # 2. Lanzar Gemini (Long context) - Background
  log "Lanzando Gemini para análisis de contexto largo..."
  cd "$PROJECT_PATH" && \
    gemini -m gemini-2.5-pro \
    "Analizar contexto histórico, logs y documentación para: $USER_INSTRUCTION" > "$TMP_DIR/gemini-context.json" 2>&1 &
  GEMINI_PID=$!

  # 3. Lanzar Sonnet para validación - Background
  log "Lanzando Sonnet para validación..."
  cd "$PROJECT_PATH" && \
    claude --print -m sonnet \
    "Validación preliminar: $USER_INSTRUCTION" > "$TMP_DIR/sonnet-validation.txt" 2>&1 &
  SONNET_PID=$!

  # 4. Esperar todos los resultados
  log "Esperando resultados de Codex (security)..."
  wait $CODEX_PID
  CODEX_EXIT=$?

  log "Esperando resultados de Gemini (contexto)..."
  wait $GEMINI_PID
  GEMINI_EXIT=$?

  log "Esperando resultados de Sonnet (validación)..."
  wait $SONNET_PID
  SONNET_EXIT=$?

  # 5. Síntesis FINAL con UltraThink
  log "Síntesis ULTRA-COMPLEJA con Opus + UltraThink..."
  claude --print -m opus --extended-thinking <<EOF
SÍNTESIS ULTRA-COMPLEJA con UltraThink activado:

## Security Audit + Architecture (Codex):
$(cat "$TMP_DIR/codex-security.json" 2>/dev/null || echo "Error: Codex falló con código $CODEX_EXIT")

## Contexto Histórico y Documentación (Gemini 2.5-pro):
$(cat "$TMP_DIR/gemini-context.json" 2>/dev/null || echo "Error: Gemini falló con código $GEMINI_EXIT")

## Validación Preliminar (Sonnet 4.5):
$(cat "$TMP_DIR/sonnet-validation.txt" 2>/dev/null || echo "Error: Sonnet falló con código $SONNET_EXIT")

## Tarea del Usuario:
$USER_INSTRUCTION

Genera:
1. Análisis profundo y exhaustivo
2. Correlación de findings de múltiples fuentes
3. Roadmap de implementación/remediación priorizado
4. Consideraciones de riesgo y trade-offs
EOF

else
  log "ERROR: Tipo de tarea desconocido: $TASK_TYPE"
  echo "Error: Tipo de tarea no reconocido" >&2
  exit 1
fi

log "Orquestación completada"
