# Auditoría del Workflow /orchestrator - v2.70.0

**Fecha**: 2026-01-26
**Problema**: El workflow de /orchestrator se estanca sin informe ni visibilidad
**Estado**: 🔍 Análisis Completo

## Resumen Ejecutivo

El workflow del orchestrator presenta **problemas críticos** que impiden su terminación normal:

1. **Bloqueo silencioso** en quality gates sin feedback al usuario
2. **Sin visibilidad** de las operaciones de subagentes
3. **Sin informe de estado** cuando se detectan errores
4. **Stop hook tardío** - El reporte solo se genera al cerrar la sesión

## Problemas Identificados

### 🔴 CRÍTICO: Bloqueo en Quality Gates

**Archivo**: `.claude/hooks/quality-gates-v2.sh:402-412`

```bash
# Cuando hay errores de calidad
if [[ -n "$BLOCKING_ERRORS" ]]; then
    echo "{
        \"continue\": false,  # ❌ DETIENE LA EJECUCIÓN
        \"reason\": \"Quality gate failed: blocking errors found\",
        \"blocking_errors\": $ERRORS_JSON,
        ...
    }"
```

**Problema**:
- Retorna `{"continue": false}` lo cual **bloquea** la operación
- **NO genera un informe** al usuario sobre qué hacer
- El workflow se estanca sin feedback claro

**Impacto**: El usuario no sabe:
- Qué archivo causó el error
- Qué validación falló (syntax, types, security)
- Qué acciones debe tomar para continuar

### 🟠 ALTO: Subagentes Opacos

**Problema**: Los subagentes se ejecutan con `run_in_background: true` sin visibilidad:

```yaml
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  run_in_background: true  # ❌ Sin visibilidad
  prompt: "Review code quality"
```

**Impacto**:
- El usuario no ve qué está haciendo el subagente
- No hay progreso visible
- Si falla, no hay mensaje de error claro

### 🟡 MEDIO: Sin Informe de Estado Intermedio

**Problema**: El único informe se genera en el Stop event:

**Archivo**: `.claude/hooks/orchestrator-report.sh:4`

```bash
# Hook: Stop
# Purpose: Generate comprehensive session report when user ends session
```

**Problema**:
- Si el workflow se estanca, el usuario nunca ve el informe
- No hay reportes intermedios por step completado
- No hay alertas cuando algo sale mal

### 🔵 BAJO: Mensajes de Sistema No Clarity

**Problema**: Los hooks envían `systemMessage` pero no siempre son claros:

```bash
echo "{\"continue\": true, \"systemMessage\": \"🔍 **Verification Required**...\"}"
```

**Impacto**: Los mensajes pueden ser:
- Demasiados técnicos
- En inglés (el usuario prefirió español)
- Sin acción clara a seguir

## Soluciones Propuestas

### 1. Modo "Graceful Degradation" para Quality Gates

**Crear**: `.claude/hooks/quality-gates-v2.sh` (versión mejorada)

```bash
# EN VEZ DE bloquear completamente:
if [[ -n "$BLOCKING_ERRORS" ]]; then
    # NEW: Generar informe de estado
    STATE_FILE=".claude/quality-state.json"
    cat > "$STATE_FILE" <<EOF
{
  "status": "blocking_errors",
  "timestamp": "$(date -Iseconds)",
  "blocking_errors": $ERRORS_JSON,
  "user_actions": [
    "1. Revisar archivo: $FILE_PATH",
    "2. Corregir errores de: $ERROR_TYPE",
    "3. Ejecutar: /gates para re-validar"
  ]
}
EOF

    # NEW: Mensaje claro al usuario
    echo "{
        \"continue\": false,
        \"systemMessage\": \"⚠️ **Quality Gate Falló**\\n\\nArchivo: $FILE_PATH\\nErrores: $ERROR_COUNT\\n\\n**Acciones**:\\n1. Ver errores arriba\\n2. Corregir archivo\\n3. Continuar con /loop\",
        \"state_file\": \"$STATE_FILE\"
    }"
```

### 2. Visibilidad de Subagentes

**Crear**: `.claude/hooks/subagent-visibility.sh`

```bash
#!/bin/bash
# Hook: PostToolUse (Task)
# Purpose: Mostrar progreso de subagentes

INPUT=$(head -c 100000)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

if [[ "$TOOL_NAME" == "Task" ]]; then
    SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')
    MODEL=$(echo "$INPUT" | jq -r '.model // ""')

    # Mostrar mensaje de inicio
    cat > ".claude/subagent-status.json" <<EOF
{
  "active_subagent": "$SUBAGENT_TYPE",
  "model": "$MODEL",
  "started_at": "$(date -Iseconds)",
  "status": "running"
}
EOF

    # Mensaje al usuario
    echo "{\"continue\": true, \"systemMessage\": \"🔄 Ejecutando: $SUBAGENT_TYPE ($MODEL)...\"}"
fi
```

### 3. Informe de Estado por Step

**Crear**: `.claude/hooks/step-progress-report.sh`

```bash
#!/bin/bash
# Hook: PostToolUse (TaskUpdate)
# Purpose: Informe de progreso cuando un step cambia de estado

INPUT=$(head -c 100000)
NEW_STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // ""')

if [[ "$NEW_STATUS" == "completed" ]]; then
    # Leer plan-state
    PLAN_STATE=".claude/plan-state.json"
    if [[ -f "$PLAN_STATE" ]]; then
        TOTAL=$(jq '.steps | length' "$PLAN_STATE")
        COMPLETED=$(jq '[.steps[] | select(.status == "completed")] | length' "$PLAN_STATE")
        PCT=$((COMPLETED * 100 / TOTAL))

        # Informe de progreso
        echo "{\"continue\": true, \"systemMessage\": \"✅ Progreso: $COMPLETED/$TOTAL steps ($PCT%)\"}"
    fi
fi
```

### 4. Reporte de Errores con Acciones Claras

**Crear**: `.claude/hooks/error-action-report.sh`

```bash
#!/bin/bash
# Hook: PostToolUse (quality-gates v2)
# Purpose: Generar informe de errores con acciones claras

# Cuando quality-gates retorna continue=false
if [[ "$CONTINUE" == "false" ]]; then
    # Crear informe en español
    cat > ".claude/error-report.md" <<EOF
# ❌ Quality Gate Falló

**Archivo**: $FILE_PATH
**Hora**: $(date -Iseconds)

## Errores Detectados

$(echo -e "$BLOCKING_ERRORS")

## Acciones Recomendadas

1. **Revisar el archivo** arriba para ver los errores específicos
2. **Corregir los errores** identificados
3. **Re-validar** con: \`/gates\`
4. **Continuar** con: \`/loop "continuar desde donde falló"\`

## Archivos Afectados

- \`$FILE_PATH\`

## Próximo Paso

Ejecuta: \`/loop "corregir errores de calidad y continuar"\`
EOF

    # Mostrar al usuario
    echo "{\"continue\": false, \"systemMessage\": \"⚠️ **Quality Gate Falló**\\n\\nSe generó informe: .claude/error-report.md\\n\\nLee el informe para ver las acciones a seguir.\"}"
fi
```

### 5. Métricas de Visibilidad

**Crear**: `.claude/hooks/orchestrator-metrics.sh`

```bash
#!/bin/bash
# Mostrar métricas en tiempo real del workflow

# Cada 5 operaciones, mostrar estado
if [[ $((OPERATION_COUNT % 5)) -eq 0 ]]; then
    PLAN_STATE=".claude/plan-state.json"
    if [[ -f "$PLAN_STATE" ]]; then
        TOTAL=$(jq '.steps | length' "$PLAN_STATE")
        COMPLETED=$(jq '[.steps[] | select(.status == "completed")] | length' "$PLAN_STATE")
        IN_PROGRESS=$(jq '[.steps[] | select(.status == "in_progress")] | length' "$PLAN_STATE")

        echo "{\"continue\": true, \"systemMessage\": \"📊 Estado: $COMPLETED/$TOTAL completados, $IN_PROGRESS en progreso\"}"
    fi
fi
```

## Plan de Implementación

### Fase 1: Parches Críticos (Inmediato)

1. **Modo Graceful Degradation** en quality-gates-v2.sh
   - Generar informe de errores en `.claude/error-report.md`
   - Mensaje claro al usuario con acciones a seguir
   - **Prioridad**: 🔴 CRÍTICA

2. **Visibilidad de Subagentes**
   - Mensaje cuando se inicia un subagente
   - Mensaje cuando se completa un subagente
   - **Prioridad**: 🟠 ALTA

### Fase 2: Mejoras de Visibilidad (Corto Plazo)

3. **Informe de Progreso por Step**
   - Mostrar progreso después de cada step completado
   - Porcentaje de completion
   - **Prioridad**: 🟡 MEDIA

4. **Reporte de Errores con Acciones**
   - Informe detallado en español
   - Acciones específicas a seguir
   - **Prioridad**: 🟡 MEDIA

### Fase 3: Métricas y Observabilidad (Mediano Plazo)

5. **Métricas en Tiempo Real**
   - Dashboard de estado del workflow
   - Tiempo estimado de completion
   - **Prioridad**: 🔵 BAJA

## Testing

### Caso de Prueba 1: Quality Gate Falla

```bash
# Crear archivo con errores
echo "function bad() {" > test.js

# Ejecutar orchestrator
/orchestrator "implement feature"

# Verificar:
# - Se generó .claude/error-report.md
# - El usuario recibió mensaje claro
# - Se indicaron acciones a seguir
```

### Caso de Prueba 2: Subagent Visibility

```bash
# Ejecutar orchestrator con subagentes
/orchestrator "implement feature"

# Verificar:
# - Mensaje "🔄 Ejecutando: code-reviewer"
# - Mensaje "✅ code-reviewer completado"
# - Informe de progreso visible
```

## Recomendaciones para el Usuario

### Mientras se implementan las soluciones:

1. **Revisar logs manualmente**:
   ```bash
   tail -f ~/.ralph/logs/orchestrator-init.log
   tail -f ~/.ralph/logs/global-task-sync.log
   ```

2. **Verificar plan-state**:
   ```bash
   cat .claude/plan-state.json | jq '.steps[] | select(.status == "in_progress")'
   ```

3. **Quality gates manuales**:
   ```bash
   ralph gates  # Ejecutar manualmente
   ```

4. **Continuar workflow estancado**:
   ```bash
   /loop "continuar desde donde se quedó"
   ```

## Conclusión

El workflow del orchestrator tiene **problemas de visibilidad y feedback** que causan que se estanque sin informe claro. Las soluciones propuestas mejoran significativamente la experiencia del usuario:

- ✅ Informes claros de errores
- ✅ Acciones específicas a seguir
- ✅ Visibilidad de subagentes
- ✅ Progreso visible en tiempo real

**Siguiente paso**: Implementar Fase 1 (Parches Críticos)
