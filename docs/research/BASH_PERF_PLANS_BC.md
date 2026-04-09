# Planes de Optimización Bash/Edit — B y C

**Date**: 2026-04-09
**Branch**: feat/bash-edit-perf-investigation
**Baseline**: 67 hooks, ~2-5s overhead por operación

---

## Plan B: Consolidación Agresiva

**Duración estimada**: 2 horas
**Objetivo**: 67 → ~25 hooks, reducir overhead a ~0.5-1s por operación

### Fase B1: Eliminación de duplicados (30 min)

#### B1.1 — Security hooks: 4 → 2

**Mantener**:
- `audit-secrets.js` — escaneo de secretos, 20+ patterns
- `sec-context-validate.sh` — validación de contexto

**Eliminar** (registrados en settings.json):
- `security-full-audit.sh` — 80% overlap con sec-context
- `security-real-audit.sh` — 70% overlap con sec-context

**Acción**: Comment out en `~/.claude/settings.json` en la sección PostToolUse:
```json
// ELIMINADO: security-full-audit.sh (duplicado de sec-context-validate.sh)
// ELIMINADO: security-real-audit.sh (duplicado de sec-context-validate.sh)
```

**Ahorro**: ~0.3-0.6s por operación

#### B1.2 — Plan-state hooks: 7 → 1

**Consolidar en un solo hook** `plan-state-manager.sh`:
- `auto-plan-state.sh` → merge
- `plan-state-adaptive.sh` → merge
- `plan-state-lifecycle.sh` → merge
- `plan-sync-post-step.sh` → merge
- `todo-plan-sync.sh` → merge
- `task-plan-sync.sh` → merge
- `auto-migrate-plan-state.sh` → merge

**Nuevo script** `plan-state-manager.sh`:
```bash
#!/usr/bin/env bash
umask 077
INPUT=$(cat)
# Detect what changed and sync accordingly
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Edit|Write) # After file changes → sync plan state
    ;;
  Task*) # Task events → sync plan
    ;;
esac

echo '{"continue":true}'
```

**Ahorro**: ~0.2s por operación (6 menos process spawns)

#### B1.3 — TypeScript checking: 2 → 1

**Eliminar**: `typescript-quick-check.sh`
**Mantener**: `quality-gates-v2.sh` (ya incluye tsc check)

**Ahorro**: ~0.3s por Edit en archivos TS

### Fase B2: Hooks async (30 min)

Marcar hooks idempotentes como `async: true` en settings.json:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "...audit-secrets.js...",
            "async": true  // ← AGREGAR
          },
          {
            "type": "command",
            "command": "...universal-step-tracker.sh...",
            "async": true  // ← AGREGAR
          },
          {
            "type": "command",
            "command": "...decision-extractor.sh...",
            "async": true  // ← AGREGAR
          },
          {
            "type": "command",
            "command": "...semantic-realtime-extractor.sh...",
            "async": true  // ← AGREGAR
          },
          {
            "type": "command",
            "command": "...console-log-detector.sh...",
            "async": true  // ← AGREGAR
          },
          {
            "type": "command",
            "command": "...ai-code-audit.sh...",
            "async": true  // ← AGREGAR
          }
        ]
      }
    ]
  }
}
```

**Nota**: `async: true` significa que Claude Code NO espera el resultado del hook. El hook corre en background y no bloquea la operación.

**Ahorro**: ~1-2s por operación (hooks async no bloquean)

**Hooks que NO pueden ser async** (deben bloquear):
- `git-safety-guard.py` — debe bloquear comandos peligrosos
- `repo-boundary-guard.sh` — debe bloquear operaciones fuera del repo
- `quality-gates-v2.sh` — calidad blocking
- `teammate-idle-quality-gate.sh` — quality gate

### Fase B3: Deshabilitar el mayor ofensor (5 min)

**Deshabilitar** `quality-parallel-async.sh`:
- Timeout de 60s
- Duplica el trabajo de sec-context + quality-gates
- No agrega valor sobre los hooks que ya tenemos

```json
// ELIMINADO: quality-parallel-async.sh (60s timeout, duplica quality-gates)
```

**Ahorro**: ~1s por operación + elimina riesgo de 60s hang

### Fase B4: Deshabilitar plugins no usados (15 min)

Plugins que requieren auth y no están autenticados:

```json
// DESHABILITAR (requieren auth, no configurados):
// - plugin:atlassian:atlassian
// - plugin:supabase:supabase
// - plugin:stripe:stripe
// - plugin:sentry:sentry
// - plugin:Notion:notion
```

**Ahorro**: ~1s en startup de sesión

### Fase B5: Timeouts para todos los hooks (10 min)

Agregar timeouts explícitos a hooks que no los tienen:

```json
{
  "type": "command",
  "command": ".../quality-gates-v2.sh",
  "timeout": 10000  // 10s max
}
```

**Regla**: Ningún hook debería exceder 10s. Críticos: 5s max.

### Resumen Plan B

| Fase | Acción | Ahorro | Esfuerzo |
|------|--------|--------|----------|
| B1 | Eliminar duplicados (security, plan-state, TS) | ~0.8s | 30 min |
| B2 | async:true en 6 hooks idempotentes | ~1-2s | 30 min |
| B3 | Deshabilitar quality-parallel-async | ~1s | 5 min |
| B4 | Deshabilitar plugins no usados | ~1s startup | 15 min |
| B5 | Timeouts explícitos | Prevención | 10 min |
| **Total** | **67 → ~25 hooks** | **~3-4s/op** | **~2 horas** |

### Resultado Esperado Plan B

```
ANTES:  67 hooks → ~2-5s overhead → percepción 6-10s por operación
DESPUÉS: 25 hooks → ~0.5-1s overhead → percepción 4-5s por operación
```

### Riesgos Plan B

| Riesgo | Mitigación |
|--------|-----------|
| Perder cobertura de seguridad | audit-secrets.js + sec-context-validate.sh cubren los mismos patterns |
| async hooks pierden errores | Solo se hacen async los idempotentes; blocking hooks se mantienen |
| Plan-state race conditions | El consolidado plan-state-manager.sh maneja todos los casos |
| Plugins necesarios después | Se pueden re-habilitar fácilmente (solo quitar comment) |

---

## Plan C: Reestructuración Completa

**Duración estimada**: 1 día completo
**Objetivo**: 67 → ~15 hooks, overhead <500ms, sistema monitoreable

### Incluye todo el Plan B, más:

### Fase C1: Hook Priority System (3 horas)

Crear un sistema de prioridad para hooks:

**Nuevo archivo**: `.claude/hooks/lib/hook-priority.sh`
```bash
#!/usr/bin/env bash
# Hook Priority System
# P0 = CRITICAL (must run, must block) — security, safety
# P1 = IMPORTANT (should run, can be async) — quality, validation
# P2 = NICE-TO-HAVE (best effort, always async) — tracking, metrics

PRIORITY_FILE=".claude/hooks/priority.conf"

get_priority() {
  local hook_name="$1"
  local priority=$(grep "^${hook_name}=" "$PRIORITY_FILE" | cut -d= -f2)
  echo "${priority:-P2}"  # Default to P2
}

should_run() {
  local hook_name="$1"
  local priority=$(get_priority "$hook_name")

  case "$priority" in
    P0) return 0 ;;  # Always run, always block
    P1) return 0 ;;  # Always run, async
    P2)
      # Skip if context > 80% (performance mode)
      if [ -f "/tmp/ralph-context-high" ]; then
        return 1  # Skip
      fi
      return 0
      ;;
  esac
}
```

**Nuevo archivo**: `.claude/hooks/priority.conf`
```
# Hook Priority Configuration
# P0 = CRITICAL, P1 = IMPORTANT, P2 = NICE-TO-HAVE

git-safety-guard.py=P0
repo-boundary-guard.sh=P0
audit-secrets.js=P0
quality-gates-v2.sh=P1
sec-context-validate.sh=P1
plan-state-manager.sh=P1
wake-up-layer-stack.sh=P1
session-end-handoff.sh=P1
teammate-idle-quality-gate.sh=P0
task-completed-quality-gate.sh=P0
universal-step-tracker.sh=P2
decision-extractor.sh=P2
semantic-realtime-extractor.sh=P2
console-log-detector.sh=P2
ai-code-audit.sh=P2
```

**Efecto**: Cuando el contexto está alto (>80%), solo P0+P1 se ejecutan. P2 se salta.

### Fase C2: Hook Result Caching (2 horas)

Muchos hooks rehacen el mismo trabajo en archivos que no cambiaron:

**Nuevo archivo**: `.claude/hooks/lib/hook-cache.sh`
```bash
#!/usr/bin/env bash
# Hook Result Cache
# Cache key = hook_name + file_hash
# TTL = 300 seconds (5 minutes)

CACHE_DIR="/tmp/ralph-hook-cache"
CACHE_TTL=300

cache_key() {
  local hook="$1"
  local file="$2"
  local hash=$(md5 -q "$file" 2>/dev/null || echo "none")
  echo "${CACHE_DIR}/${hook}_${hash}"
}

cache_valid() {
  local key="$1"
  if [ -f "$key" ]; then
    local age=$(( $(date +%s) - $(stat -f %m "$key" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$CACHE_TTL" ]
    return $?
  fi
  return 1
}

cache_get() {
  local key="$1"
  if cache_valid "$key"; then
    cat "$key"
    return 0
  fi
  return 1
}

cache_set() {
  local key="$1"
  local value="$2"
  mkdir -p "$CACHE_DIR"
  echo "$value" > "$key"
}
```

**Uso en hooks**:
```bash
# En audit-secrets.js o cualquier hook
CACHE_KEY=$(cache_key "audit-secrets" "$FILE_PATH")
if cache_valid "$CACHE_KEY"; then
  cat "$CACHE_KEY"  # Return cached result
  exit 0
fi
# ... do expensive work ...
cache_set "$CACHE_KEY" "$RESULT"
```

**Efecto**: Si editas el mismo archivo varias veces, la segunda validación es instantánea.

### Fase C3: Hook Performance Monitor (1 hora)

**Nuevo archivo**: `.claude/hooks/lib/hook-perf.sh`
```bash
#!/usr/bin/env bash
# Hook Performance Monitor
# Logs execution time per hook for analysis

PERF_LOG="$HOME/.ralph/logs/hook-perf.log"

perf_start() {
  PERF_START_TIME=$(python3 -c "import time; print(time.time())")
}

perf_end() {
  local hook_name="$1"
  local end_time=$(python3 -c "import time; print(time.time())")
  local elapsed=$(python3 -c "print(f'{($end_time - $PERF_START_TIME)*1000:.0f}')")

  mkdir -p "$(dirname "$PERF_LOG")"
  echo "$(date +%Y-%m-%dT%H:%M:%S)|${hook_name}|${elapsed}ms" >> "$PERF_LOG"
}
```

**Uso en cada hook**:
```bash
source "$(dirname "$0")/lib/hook-perf.sh"
perf_start
# ... hook logic ...
perf_end "audit-secrets"
```

**Reporte**: Generar reporte de performance con:
```bash
cat ~/.ralph/logs/hook-perf.log | awk -F'|' '{sum[$2]+=$3; count[$2]++} END {for (h in sum) printf "%s: avg %.0fms (%d calls)\n", h, sum[h]/count[h], count[h]}' | sort -t: -k2 -rn
```

### Fase C4: SessionStart Consolidation (1 hora)

**Actual**: 11 hooks en SessionStart
**Objetivo**: 3 hooks consolidados

| Nuevo Hook Consolidado | Hooks que reemplaza |
|------------------------|-------------------|
| `session-wake-up.sh` | wake-up-layer-stack.sh, status-auto-check.sh, context-monitor-init.sh |
| `session-handoff-restore.sh` | post-compact-restore.sh, session-start-handoff.sh |
| `session-plugins-init.sh` | Todos los plugin init hooks |

### Fase C5: Smart Edit Batching (1 hora)

Agregar lógica al CLAUDE.md o como skill para que el LLM prefiera batching:

**Nueva sección en CLAUDE.md**:
```markdown
## Bash Performance Rules

When running multiple Bash commands that don't depend on each other:
1. COMBINE into single call with `&&` or `;`
2. AVOID sequential Bash calls for simple operations
3. Use batch execution for file operations

GOOD:
  Bash("mkdir -p dir && cp file1 dir/ && cp file2 dir/")

BAD:
  Bash("mkdir -p dir")
  Bash("cp file1 dir/")
  Bash("cp file2 dir/")
```

### Resumen Plan C

| Fase | Acción | Ahorro | Esfuerzo |
|------|--------|--------|----------|
| B1-B5 | Todo el Plan B | ~3-4s | 2 horas |
| C1 | Hook Priority System (P0/P1/P2) | ~1s (skip P2) | 3 horas |
| C2 | Hook Result Caching | ~1-2s (re-edits) | 2 horas |
| C3 | Performance Monitor | Observabilidad | 1 hora |
| C4 | SessionStart consolidation | ~0.5s startup | 1 hora |
| C5 | Smart Edit Batching (CLAUDE.md) | ~2s/batch | 1 hora |
| **Total** | **67 → ~15 hooks** | **~5-8s/op** | **~10 horas** |

### Resultado Esperado Plan C

```
ANTES:  67 hooks → ~2-5s overhead → percepción 6-10s por operación
DESPUÉS: 15 hooks → ~200-500ms overhead → percepción 3-4s por operación
```

Con batching de comandos (C5), la percepción puede bajar a ~2-3s.

### Arquitectura Final Plan C

```
Operación Bash/Edit:
  1. PreToolUse (2 hooks blocking, P0):
     - git-safety-guard.py (P0, ~50ms)
     - repo-boundary-guard.sh (P0, ~30ms)

  2. Execute tool (~instant)

  3. PostToolUse (4 hooks):
     - quality-gates-v2.sh (P1, blocking, ~200ms)
     - audit-secrets.js (P1, async, cached)
     - plan-state-manager.sh (P1, async, cached)
     - sec-context-validate.sh (P1, async, cached)

  4. P2 hooks: SKIPPED when context > 80%

  Total: ~300ms overhead
```

### Riesgos Plan C

| Riesgo | Mitigación |
|--------|-----------|
| Cache invalidation incorrecta | TTL de 5 min + cache busting on file change |
| Priority misconfiguración | P0 hooks son hardcodeados, nunca se saltan |
| Performance monitor overhead | Escribir a archivo es <1ms, insignificante |
| Consolidación introduce bugs | Cada consolidación se prueba individualmente |
| Tiempo de implementación | Cada fase es independiente, se puede hacer incremental |

---

## Comparación Final

| Métrica | Actual | Plan B | Plan C |
|---------|--------|--------|--------|
| Hooks totales | 67 | ~25 | ~15 |
| Overhead por op | 2-5s | 0.5-1s | 0.2-0.5s |
| Percepción usuario | 6-10s | 4-5s | 3-4s |
| Con batching | N/A | 3-4s | 2-3s |
| Esfuerzo | — | 2 horas | 10 horas |
| Riesgo | — | Bajo | Medio |
| Observabilidad | Ninguna | Ninguna | Performance logs |
| Cache | No | No | Sí (5min TTL) |
| Priorización | No | No | Sí (P0/P1/P2) |

---

*Documento generado el 2026-04-09 como parte de la investigación bash-perf-research*
