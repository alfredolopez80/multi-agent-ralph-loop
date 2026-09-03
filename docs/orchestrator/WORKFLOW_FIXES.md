# Plan de Acción - Fixes para Workflow /orchestrator

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

**Fecha**: 2026-01-26
**Problema**: Workflow se estanca sin visibilidad ni informe
**Estado**: 🔧 Soluciones Propuestas

## Resumen Ejecutivo

El usuario reporta:
1. ✅ **Task estancada**: "Complete Papermark Docker setup analysis"
2. ✅ **Errores repetitivos**: "PreToolUse:Task hook error" (7+ veces)
3. ✅ **Sin visibilidad**: No se sabe qué están haciendo los subagentes
4. ✅ **Sin informe final**: No hay reporte del estado o acciones a seguir

## Diagnóstico Completado

### ✅ Hooks PreToolUse para Task (7 hooks totales)

| Hook | Timeout | Estado | Observación |
|------|---------|--------|-------------|
| orchestrator-auto-learn.sh | 10s | ✅ OK | Funciona correctamente |
| fast-path-check.sh | 5s | ✅ OK | Funciona correctamente |
| inject-session-context.sh | 15s | ✅ OK | Funciona correctamente |
| smart-memory-search.sh | 30s | ✅ OK | Funciona, pero puede tener timeout de red |
| procedural-inject.sh | 10s | ✅ OK | Funciona correctamente |
| agent-memory-auto-init.sh | 5s | ✅ OK | Funciona correctamente |
| task-orchestration-optimizer.sh | 30s | ✅ OK | Funciona correctamente |

**Total teórico**: 105 segundos (casi 2 minutos)

### 🔍 Problema Identificado

**"PreToolUse:Task hook error"** puede ocurrir cuando:
1. **Timeout**: Un hook excede su tiempo límite
2. **Red**: Las llamadas a MCP fallan por problemas de red
3. **JSON inválido**: El hook retorna algo que no es JSON válido
4. **Interacción**: Múltiples hooks causan conflicto

### 📊 Análisis de Logs

```
smart-memory-search logs muestran:
- GLM web search: API call failed (network) ⚠️
- GLM docs search: API call failed (network) ⚠️
```

Esto indica que **las llamadas a MCP pueden fallar**, pero el hook maneja esto correctamente retornando `{"decision": "allow"}`.

## Soluciones Propuestas

### 🔧 Fase 1: Fixes Inmediatos (Implementar Hoy)

#### 1. Reducir Timeout de smart-memory-search.sh

**Problema**: 30 segundos puede ser mucho cuando hay problemas de red

**Solución**: Reducir a 15 segundos y hacer más robusto el manejo de errores

```bash
# En ~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {
            "command": "${HOME}/.claude/hooks/smart-memory-search.sh",
            "timeout": 15,  # REDUCIDO de 30 a 15
            "type": "command"
          }
        ]
      }
    ]
  }
}
```

#### 2. Agregar Hook de Visibilidad

**Crear**: `~/.claude/hooks/subagent-progress.sh`

```bash
#!/bin/bash
# Hook: PostToolUse (Task, TaskUpdate)
# Purpose: Mostrar progreso de subagentes al usuario

INPUT=$(head -c 100000)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Task)
    SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')
    MODEL=$(echo "$INPUT" | jq -r '.model // ""')
    if [[ -n "$SUBAGENT_TYPE" ]]; then
      echo "{\"continue\": true, \"systemMessage\": \"🔄 Iniciando: $SUBAGENT_TYPE ($MODEL)...\"}"
    fi
    ;;
  TaskUpdate)
    STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // ""')
    TASK_ID=$(echo "$INPUT" | jq -r '.tool_input.taskId // ""')
    if [[ "$STATUS" == "completed" ]]; then
      echo "{\"continue\": true, \"systemMessage\": \"✅ Task $TASK_ID completada\"}"
    fi
    ;;
esac

echo '{"continue": true}'
```

#### 3. Agregar Hook de Informe de Errores

**Crear**: `~/.claude/hooks/error-informative.sh`

```bash
#!/bin/bash
# Hook: PostToolUse
# Purpose: Informar al usuario sobre errores con acciones claras

# Este hook se ejecuta DESPUÉS de cualquier tool
# Si detecta errores en los logs recientes, genera informe

LAST_ERRORS=$(tail -20 ~/.ralph/logs/*.log 2>/dev/null | grep -i "error\|fail" | wc -l)
if [[ $LAST_ERRORS -gt 5 ]]; then
  # Generar informe
  cat > .claude/error-reporte.md <<EOF
# ⚠️ Errores Detectados en Workflow

## Qué está pasando

El workflow ha detectado múltiples errores recientes en los logs.
Esto puede indicar:

1. **Problemas de red**: Las llamadas a APIs pueden estar fallando
2. **Timeout**: Algunos hooks pueden estar excediendo su tiempo
3. **Subagente estancado**: Un subagente puede estar esperando input

## Acciones Recomendadas

### Opción 1: Continuar (si los errores son menores)
\`\`\`bash
/loop "continuar desde donde se quedó"
\`\`\`

### Opción 2: Reintentar con menos hooks
\`\`\`bash
# Deshabilitar temporalmente smart-memory-search
mv ~/.claude/hooks/smart-memory-search.sh ~/.claude/hooks/smart-memory-search.sh.disabled
\`\`\`

### Opción 3: Ver logs detallados
\`\`\`bash
tail -50 ~/.ralph/logs/smart-memory-search-*.log
tail -50 ~/.ralph/logs/global-task-sync.log
\`\`\`

## Información del Sistema

**Fecha**: $(date -Iseconds)
**Sesión**: $(cat .claude/session-id 2>/dev/null || echo "desconocida")
**Plan State**: $(cat .claude/plan-state.json 2>/dev/null | jq -r '.task // "Sin plan"' 2>/dev/null)
EOF

  echo "{\"continue\": true, \"systemMessage\": \"⚠️ Se detectaron errores. Ver informe: .claude/error-reporte.md\"}"
fi

echo '{"continue": true}'
```

### 🔧 Fase 2: Mejoras de Visibilidad (Esta Semana)

#### 4. Dashboard de Progreso del Workflow

**Crear**: `~/.claude/hooks/workflow-dashboard.sh`

```bash
#!/bin/bash
# Hook: PostToolUse (TaskUpdate)
# Purpose: Mostrar dashboard de progreso cada 5 operaciones

INPUT=$(head -c 100000)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" == "TaskUpdate" ]]; then
  # Contar operaciones
  COUNTER_FILE=".claude/operation-counter"
  if [[ ! -f "$COUNTER_FILE" ]]; then
    echo "0" > "$COUNTER_FILE"
  fi
  COUNT=$(cat "$COUNTER_FILE")
  COUNT=$((COUNT + 1))
  echo "$COUNT" > "$COUNTER_FILE"

  # Cada 5 operaciones, mostrar dashboard
  if [[ $((COUNT % 5)) -eq 0 ]]; then
    PLAN_STATE=".claude/plan-state.json"
    if [[ -f "$PLAN_STATE" ]]; then
      TOTAL=$(jq '.steps | length' "$PLAN_STATE")
      COMPLETED=$(jq '[.steps[] | select(.status == "completed")] | length' "$PLAN_STATE")
      IN_PROGRESS=$(jq '[.steps[] | select(.status == "in_progress")] | length' "$PLAN_STATE")
      PENDING=$((TOTAL - COMPLETED - IN_PROGRESS))

      PCT=0
      if [[ $TOTAL -gt 0 ]]; then
        PCT=$((COMPLETED * 100 / TOTAL))
      fi

      cat > .claude/workflow-status.md <<EOF
# 📊 Dashboard del Workflow

## Progreso

- **Completados**: $COMPLETED/$TOTAL ($PCT%)
- **En Progreso**: $IN_PROGRESS
- **Pendientes**: $PENDING

## Pasos Completados

$(jq -r '.steps[] | select(.status == "completed") | "- \(.name // .title)"' "$PLAN_STATE")

## Pasos En Progreso

$(jq -r '.steps[] | select(.status == "in_progress") | "- \(.name // .title)"' "$PLAN_STATE")

## Pasos Pendientes

$(jq -r '.steps[] | select(.status == "pending") | "- \(.name // .title)"' "$PLAN_STATE")
EOF

      echo "{\"continue\": true, \"systemMessage\": \"📊 Progreso: $COMPLETED/$TOTAL ($PCT%) - Ver dashboard: .claude/workflow-status.md\"}"
    fi
  fi
fi

echo '{"continue": true}'
```

### 🔧 Fase 3: Solución Robusta (Próxima Semana)

#### 5. Modo "Degradado Graceful" para smart-memory-search

**Modificar**: `~/.claude/hooks/smart-memory-search.sh`

Agregar al principio del script:

```bash
# Modo degradado: Si hay problemas de red, deshabilitar búsquedas externas
DEGRADED_MODE=false

# Verificar si las APIs están funcionando
if ! timeout 3s curl -s https://api.z.ai/health >/dev/null 2>&1; then
  echo "[WARNING] GLM API no responde, usando modo degradado" >> "$LOG_FILE"
  DEGRADED_MODE=true
fi

if [[ "$DEGRADED_MODE" == "true" ]]; then
  # Solo usar fuentes locales (sin web search ni docs)
  # Saltar búsquedas externas que pueden fallar
  echo '{"decision": "allow", "additionalContext": "SMART_MEMORY: Modo degradado (solo fuentes locales por problemas de red)"}'
  exit 0
fi
```

## Plan de Implementación

### ✅ Hoy (Inmediato)

1. **Reducir timeout** de smart-memory-search.sh: 30s → 15s
2. **Crear hook de visibilidad** para subagentes
3. **Crear hook de informe** de errores

### ✅ Esta Semana

4. **Dashboard de progreso** del workflow
5. **Modo degradado** para problemas de red

### ✅ Próxima Semana

6. **Sistema de recovery** automático
7. **Métricas detalladas** de performance

## Acciones Inmediatas para el Usuario

### Para la Task Estancada Actual

1. **Verificar estado actual**:
   ```bash
   cat .claude/plan-state.json | jq '.steps[] | select(.status == "in_progress")'
   ```

2. **Ver logs recientes**:
   ```bash
   tail -50 ~/.ralph/logs/smart-memory-search-*.log
   ```

3. **Continuar workflow**:
   ```bash
   /loop "continuar desde donde se quedó"
   ```

4. **Si persiste el error**:
   ```bash
   # Deshabilitar smart-memory-search temporalmente
   mv ~/.claude/hooks/smart-memory-search.sh ~/.claude/hooks/smart-memory-search.sh.disabled

   # Reintentar la task
   /loop "reintentar tarea"
   ```

## Prevención Futura

### Configuración Recomendada

1. **Reducir timeouts** de hooks que hacen llamadas externas
2. **Aumentar visibilidad** con hooks informativos
3. **Implementar modo degradado** para cuando fallen las APIs
4. **Métricas en tiempo real** del estado del workflow

### Monitoreo

```bash
# Ver estado del workflow en tiempo real
watch -n 5 'cat .claude/plan-state.json | jq "{total: .steps | length, completed: [.steps[] | select(.status == \"completed\")] | length, in_progress: [.steps[] | select(.status == \"in_progress\")] | length}"'
```

## Conclusión

Los "PreToolUse:Task hook error" son causados por:
- **Timeout** de hooks con llamadas externas (smart-memory-search)
- **Problemas de red** intermitentes con APIs MCP
- **Falta de visibilidad** del progreso del workflow

**Solución**: Implementar fixes inmediatos para reducir timeouts y agregar visibilidad.
