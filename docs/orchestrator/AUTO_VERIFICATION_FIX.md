# Fix Integral para Workflow /orchestrator - v2.70.1

**Fecha**: 2026-01-26
**Problema**: El workflow se estanca sin coordinación automática de verificaciones
**Estado**: 🔧 Solución Integral Diseñada

## Problema Raíz Identificado

### 🔴 CAUSA RAÍZ: Falta de Coordinación Automática

El hook `code-review-auto.sh` v2.70.0 tiene dos modos:

1. **AUTO MODE** (`RALPH_AUTO_MODE=true`):
   - Guarda marcador en `~/.ralph/markers/review-pending-{session}.txt`
   - Output silencioso (no bloquea)
   - Espera que el orchestrator lea los marcadores y ejecute

2. **MANUAL MODE** (default):
   - Muestra mensaje "AUTO-INVOKE REQUIRED: Code Review"
   - Requiere intervención manual del usuario
   - **ESTE ES EL MODO QUE SE ESTÁ ACTIVANDO**

### ❌ El Orchestrator NO Está Coordinando

El orchestrator **NO**:
- ❌ Configura `RALPH_AUTO_MODE=true` al iniciarse
- ❌ Lee los marcadores de `review-pending-*.txt`
- ❌ Ejecuta automáticamente las verificaciones pendientes
- ❌ Continúa al siguiente step después de verificaciones

### 📊 Flujo Roto Actual

```
Step Completo → code-review-auto.sh
                  ↓
            MANUAL MODE activado (no hay RALPH_AUTO_MODE)
                  ↓
      Mensaje "AUTO-INVOKE REQUIRED" mostrado
                  ↓
         ❌ ORCHESTRATOR NO ACTÚA
                  ↓
           Workflow se ESTANCA
```

### ✅ Flujo Esperado

```
Step Completo → code-review-auto.sh
                  ↓
         AUTO MODE (RALPH_AUTO_MODE=true)
                  ↓
    Marcador guardado en review-pending-*.txt
                  ↓
    Orchestrator lee marcadores
                  ↓
     Ejecuta code-reviewer automáticamente
                  ↓
     Verificación completa → Continúa next step
```

## Solución Integral

### 🔧 Componente 1: Orchestrator Auto-Detection

**Modificar**: `.claude/agents/orchestrator.md`

Agregar al inicio del agent (en el section de ejecución):

```markdown
## Step 6.5: AUTO-VERIFICATION COORDINATION (v2.70.1 - CRITICAL)

**ANTES de continuar al siguiente step, ejecutar verificaciones pendientes:**

### Detect Pending Reviews

```bash
# Check for pending review markers
MARKERS_DIR="${HOME}/.ralph/markers"
SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
REVIEW_MARKER="${MARKERS_DIR}/review-pending-${SESSION_ID}.txt"

if [[ -f "$REVIEW_MARKER" ]]; then
  # Leer marcador y ejecutar reviews pendientes
  while IFS= read -r changed_files; do
    if [[ -n "$changed_files" ]]; then
      # Ejecutar code-reviewer automáticamente
      Task:
        subagent_type: "code-reviewer"
        model: "sonnet"
        run_in_background: false
        prompt: |
          Review the recent changes for quality issues:
          - Runtime errors (exceptions, null checks)
          - Performance (O(n^2), N+1 queries)
          - Security (injection, XSS, auth)
          - Test coverage gaps

          Changed files:
          $changed_files

      # Marcar como review-done
      touch "${MARKERS_DIR}/review-done-${SESSION_ID}-${step_id}"
    fi
  done < "$REVIEW_MARKER"

  # Limpiar marcador
  rm -f "$REVIEW_MARKER"
fi
```

### Integration with Main Loop

**DESPUÉS de cada step completion**, antes de continuar:

1. Check for pending review markers
2. Execute verification if found
3. Wait for verification to complete
4. Only then continue to next step

**This ensures automatic verification without manual intervention.**
```

### 🔧 Componente 2: Hook Orchestrator Auto-Mode

**Crear**: `.claude/hooks/orchestrator-automode.sh`

```bash
#!/bin/bash
# orchestrator-automode.sh - Configure AUTO mode for orchestrator
# Hook: SessionStart
# VERSION: 1.0.0
#
# Purpose: Set RALPH_AUTO_MODE=true when orchestrator starts
#          Enable automatic verification execution

set -euo pipefail

# Check if this is an orchestrator session
if [[ -f ".claude/orchestrator-active" ]]; then
  # Set AUTO mode environment variable
  export RALPH_AUTO_MODE=true

  # Log for debugging
  echo "[orchestrator-automode] AUTO mode enabled for session" >> ~/.ralph/logs/orchestrator-automode.log

  # Create marker for other hooks to detect
  touch ~/.ralph/markers/automode-active
fi

# SessionStart hooks don't return JSON
exit 0
```

### 🔧 Componente 3: Orchestrator Loop Coordinator

**Modificar**: `.claude/agents/orchestrator.md` - Agregar sección de coordinación:

```markdown
## Step 6b.5: VERIFICATION COORDINATION (NEW v2.70.1)

**CRITICAL**: After implementing each step, check and execute pending verifications:

```yaml
# After marking step as completed
~/.claude/hooks/plan-state-init.sh complete [step_id]

# Check for pending verifications
MARKERS_DIR="${HOME}/.ralph/markers"
REVIEW_MARKER="${MARKERS_DIR}/review-pending-${SESSION_ID}.txt"

if [[ -f "$REVIEW_MARKER" && -s "$REVIEW_MARKER" ]]; then
  # Execute pending code reviews
  while IFS= read -r changed_files; do
    if [[ -n "$changed_files" ]]; then
      # Auto-execute code review
      echo "🔄 Auto-ejecutando code review para cambios: $changed_files"

      # Mark review in progress
      echo "[$(date -Iseconds)] REVIEW: $changed_files" >> .claude/review-log.txt

      # Execute review synchronously (wait for completion)
      REVIEW_OUTPUT=$(Task tool with:
        subagent_type: "code-reviewer"
        model: "sonnet"
        prompt: "Review for quality, security, performance:\\n\\nChanged files:\\n$changed_files"
      )

      # Log completion
      echo "[$(date -Iseconds)] REVIEW COMPLETE: $changed_files" >> .claude/review-log.txt
    fi
  done < "$REVIEW_MARKER"

  # Clear marker after executing
  rm -f "$REVIEW_MARKER"
fi

# Only then continue to next step
```
```

### 🔧 Componente 4: Auto-Verification Hook

**Crear**: `.claude/hooks/auto-verification-coordinator.sh`

```bash
#!/bin/bash
# auto-verification-coordinator.sh - Coordinate automatic verification
# Hook: PostToolUse (TaskUpdate)
# VERSION: 1.0.0
#
# Purpose: When RALPH_AUTO_MODE=true, automatically execute verifications
#          instead of showing manual instructions

INPUT=$(head -c 100000)

set -euo pipefail

# Guaranteed JSON output
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Check if in AUTO mode
if [[ "${RALPH_AUTO_MODE:-false}" == "true" ]]; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

  if [[ "$TOOL_NAME" == "TaskUpdate" ]]; then
    # Check for pending review markers
    MARKERS_DIR="${HOME}/.ralph/markers"
    SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
    REVIEW_MARKER="${MARKERS_DIR}/review-pending-${SESSION_ID}.txt"

    if [[ -f "$REVIEW_MARKER" && -s "$REVIEW_MARKER" ]]; then
      # Read first pending review
      PENDING_REVIEW=$(head -1 "$REVIEW_MARKER")

      if [[ -n "$PENDING_REVIEW" ]]; then
        # Remove from pending list (consumed)
        tail -n +2 "$REVIEW_MARKER" > "${REVIEW_MARKER}.tmp"
        mv "${REVIEW_MARKER}.tmp" "$REVIEW_MARKER"

        # If empty, remove marker file
        if [[ ! -s "$REVIEW_MARKER" ]]; then
          rm -f "$REVIEW_MARKER"
        fi

        # Execute code review automatically
        echo "{\"continue\": true, \"systemMessage\": \"🔄 Auto-ejecutando code review...\"}"

        # Trigger Task for code review
        # (This will be handled by the orchestrator loop coordinator)
        exit 0
      fi
    fi
  fi
fi

echo '{"continue": true}'
```

## Plan de Implementación

### ✅ Fase 1: Fixes Críticos (Hoy)

#### 1.1 Configurar RALPH_AUTO_MODE en Orchestrator

**Modificar**: `.claude/agents/orchestrator.md`

Agregar al principio del archivo:

```markdown
## Environment Variables (CRITICAL for v2.70.0+)

When orchestrator starts, set:

\`\`\`bash
export RALPH_AUTO_MODE=true
\`\`\`

This enables automatic verification coordination.
```

#### 1.2 Crear Hook de Auto-Detección

**Crear**: `.claude/hooks/orchestrator-automode.sh` (ver código arriba)

#### 1.3 Agregar Coordinación en Orchestrator

**Modificar**: `.claude/agents/orchestrator.md` - Agregar Step 6b.5 (ver código arriba)

### ✅ Fase 2: Testing y Validación (Esta Semana)

#### 2.1 Test Case: Auto-Verification Flow

```bash
# 1. Iniciar orchestrator con task simple
/orchestrator "Implement simple feature"

# 2. Verificar que RALPH_AUTO_MODE está activo
echo $RALPH_AUTO_MODE  # Debería ser "true"

# 3. Completar un step
# 4. Verificar que se ejecuta code-reviewer automáticamente
# 5. Verificar que se limpia el marcador review-pending
```

#### 2.2 Verificar Logs

```bash
# Check automode log
tail -20 ~/.ralph/logs/orchestrator-automode.log

# Check review markers
ls -la ~/.ralph/markers/review-pending-*.txt

# Check review log
tail -20 .claude/review-log.txt
```

### ✅ Fase 3: Robustez (Próxima Semana)

#### 3.1 Multiple Verification Types

Extender auto-verification para:
- Security auditor (si hay cambios de auth/seguridad)
- Test architect (si hay archivos de test)
- Frontend reviewer (si hay cambios de UI)

#### 3.2 Parallel Verification

Ejecutar múltiples verificaciones en paralelo cuando sea posible:

```yaml
# If multiple verifications needed, run in parallel
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  run_in_background: true

Task:
  subagent_type: "security-auditor"
  model: "sonnet"
  run_in_background: true

# Wait for both
TaskOutput: task_id=review-task
TaskOutput: task_id=security-task
```

## Recomendaciones para el Usuario

### Mientras se implementa la solución:

1. **Ejecutar verificaciones manualmente** cuando veas "AUTO-INVOKE REQUIRED":

```yaml
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  prompt: |
    Review the recent changes for quality issues:
    - Runtime errors (exceptions, null checks)
    - Performance (O(n^2), N+1 queries)
    - Security (injection, XSS, auth)
    - Test coverage gaps
```

2. **Continuar workflow** después de verificación:

```bash
/loop "continuar con siguiente paso"
```

3. **Monitorear marcadores**:

```bash
# Verificar si hay marcadores pendientes
ls -la ~/.ralph/markers/review-pending-*.txt

# Ver contenido
cat ~/.ralph/markers/review-pending-*.txt
```

## Conclusión

El workflow se estanca porque:
- ❌ El code-review-auto.sh espera `RALPH_AUTO_MODE=true` para modo automático
- ❌ El orchestrator NO configura esta variable
- ❌ El orchestrator NO lee ni ejecuta los marcadores pendientes

**Solución**: Implementar coordinación automática en el orchestrator para que:
- ✅ Configure RALPH_AUTO_MODE=true al iniciarse
- ✅ Lea y ejecute los marcadores de verificación pendientes
- ✅ Continue automáticamente después de verificaciones completas

Esto restaurará el flujo automático del workflow.
