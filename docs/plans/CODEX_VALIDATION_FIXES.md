# Plan de Correcciones - Validación Codex-CLI

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

**Fecha**: 2026-01-26
**Puntuación Inicial**: 5.8/10 (Below target)
**Objetivo**: 7+/10

---

## 📊 Resumen Ejecutivo

Análisis técnico exhaustivo de **codex-cli** (Code Reviewer) identificó **4 issues CRITICAL** y **4 issues HIGH PRIORITY** que requieren atención inmediata. Los issues críticos pueden causar crashes, deadlocks y data loss.

---

## 🔴 CRITICAL Fixes (1-2 horas)

### 1. Missing `$RED` variable - statusline-ralph.sh

**Impacto**: HIGH - Crash when context reaches 85%
**Ubicación**: statusline-ralph.sh
**Fix Effort**: 1 línea

**Problema**:
```bash
# La variable $RED se usa pero nunca se define
if [ $percentage -ge 85 ]; then
    COLOR="${RED}"  # CRASH: RED no está definida
fi
```

**Fix**:
```bash
# Agregar al inicio del archivo junto con otras variables de color
RED='\033[0;31m'
```

---

### 2. Lock not released on error - glm-context-tracker.sh

**Impacto**: HIGH - Deadlocks
**Ubicación**: glm-context-tracker.sh, función `add_tokens()`
**Fix Effort**: 3 líneas

**Problema**:
```bash
add_tokens() {
    acquire_lock  # Adquiere lock
    # ... operaciones ...
    # Si hay error aquí, el lock NUNCA se libera
    release_lock  # Solo se alcanza si no hay errores
}
```

**Fix**:
```bash
add_tokens() {
    acquire_lock
    trap 'release_lock' ERR EXIT  # Liberar lock en error o exit
    # ... operaciones ...
    trap - ERR EXIT  # Limpiar trap al final
    release_lock
}
```

---

### 3. Race condition counters - context-warning.sh

**Impacto**: MED - Data loss / inconsistent counters
**Ubicación**: context-warning.sh
**Fix Effort**: 5 líneas

**Problema**:
```bash
# Multiple hooks pueden escribir simultáneamente
echo $((count + 1)) > "${STATE_DIR}/operation-counter"
# Race condition: dos procesos leen el mismo valor, ambos escriben count+1
```

**Fix**:
```bash
# Usar file locking para evitar race conditions
acquire_lock "${STATE_DIR}/operation-counter.lock"
current_count=$(read_counter "${STATE_DIR}/operation-counter")
echo $((current_count + 1)) > "${STATE_DIR}/operation-counter"
release_lock "${STATE_DIR}/operation-counter.lock"
```

---

### 4. Tilde expansion bug - session-start-reset-counters.sh

**Impacto**: MED - Wrong path, counters not reset
**Ubicación**: session-start-reset-counters.sh
**Fix Effort**: 1 palabra

**Problema**:
```bash
# La tilde no se expande correctamente en todos los contexts
STATE_FILE="~/.ralph/state/counters.json"
[ ! -f "$STATE_FILE" ]  # FALLA: la tilde no se expandió
```

**Fix**:
```bash
# Usar $HOME en lugar de tilde
STATE_FILE="${HOME}/.ralph/state/counters.json"
```

---

## 🟠 HIGH PRIORITY Fixes (2-4 horas)

### 5. Stale lock cleanup - glm-context-tracker.sh

**Impacto**: MED - Auto-recovery from stale locks
**Fix Effort**: ~10 líneas

**Problema**: Si un proceso termina abruptamente, el lock file permanece

**Fix**:
```bash
acquire_lock() {
    local lock_file="$1"
    local lock_timeout=5

    # Check for stale lock (older than 10 seconds)
    if [[ -f "$lock_file" ]]; then
        local lock_age=$(($(date +%s) - $(stat -f%m "$lock_file" 2>/dev/null || stat -c%Y "$lock_file")))
        if [[ $lock_age -gt 10 ]]; then
            log "WARN: Removing stale lock (${lock_age}s old)"
            rm -f "$lock_file"
        fi
    fi

    # Try to acquire lock with timeout
    local count=0
    while [[ $count -lt $lock_timeout ]]; do
        if mkdir "$lock_file.lock" 2>/dev/null; then
            echo $$ > "$lock_file"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done

    log "ERROR: Failed to acquire lock after ${lock_timeout}s"
    return 1
}
```

---

### 6. Input validation - glm-context-tracker.sh

**Impacto**: MED - Prevent crashes from invalid input
**Fix Effort**: ~3 líneas

**Problema**: No valida que los tokens sean números válidos

**Fix**:
```bash
add_tokens() {
    local input_tokens="${1:-0}"
    local output_tokens="${2:-0}"

    # Validate input
    if ! [[ "$input_tokens" =~ ^[0-9]+$ ]] || ! [[ "$output_tokens" =~ ^[0-9]+$ ]]; then
        log "ERROR: Invalid token values: input=${input_tokens}, output=${output_tokens}"
        return 1
    fi

    # ... rest of function ...
}
```

---

### 7. Log rotation - All scripts

**Impacto**: LOW - Prevent disk full from growing logs
**Fix Effort**: ~10 líneas

**Fix**:
```bash
# Agregar función de log rotation
log() {
    local message="$1"
    local log_file="${LOG_FILE}"

    # Rotate log if > 10MB
    if [[ -f "$log_file" ]]; then
        local log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file")
        if [[ $log_size -gt 10485760 ]]; then
            mv "$log_file" "${log_file}.1"
            # Keep only last 3 rotated logs
            rm -f "${log_file}.3"
            [[ -f "${log_file}.2" ]] && mv "${log_file}.2" "${log_file}.3"
            [[ -f "${log_file}.1" ]] && mv "${log_file}.1" "${log_file}.2"
        fi
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
}
```

---

### 8. Extract percentage calculation - Multiple files

**Impacto**: LOW - Consistency across scripts
**Fix Effort**: ~15 líneas

**Fix**: Crear helper function compartida

```bash
# ~/.ralph/lib/percentage-utils.sh
calculate_percentage() {
    local current=$1
    local total=$2

    if [[ -z "$current" ]] || [[ -z "$total" ]] || [[ "$total" -eq 0 ]]; then
        echo 0
        return
    fi

    local percentage=$((current * 100 / total))

    # Clamp to 0-100
    if [[ $percentage -lt 0 ]]; then
        echo 0
    elif [[ $percentage -gt 100 ]]; then
        echo 100
    else
        echo $percentage
    fi
}
```

---

## ✅ Checklist de Validación

After implementing fixes, validate:

- [ ] statusline-ralph.sh no crash en 85%
- [ ] No deadlocks en glm-context-tracker
- [ ] Counters consistentes en context-warning
- [ ] Counters reset correctamente en session-start
- [ ] Stale locks se limpian automáticamente
- [ ] Invalid tokens rechazados con error
- [ ] Logs rotan cuando > 10MB
- [ ] Percentage calculation consistente

---

## 📈 Expected Score After Fixes

| Métrica | Before | After (estimado) |
|---------|--------|------------------|
| Security | 7/10 | 8/10 |
| Performance | 8/10 | 8/10 |
| Maintainability | 6/10 | 7/10 |
| Robustness | 5/10 | 8/10 |
| Test Coverage | 0/10 | 0/10 |
| Documentation | 5/10 | 6/10 |
| **Overall** | **5.8/10** | **7.0/10** ✅ |

---

## 🔄 Implementación Order

1. **Critical #1**: Fix `$RED` variable (1 min)
2. **Critical #4**: Fix tilde expansion (1 min)
3. **Critical #2**: Fix lock release error trap (5 min)
4. **Critical #3**: Fix race condition with locking (10 min)
5. **High #5**: Stale lock cleanup (10 min)
6. **High #6**: Input validation (5 min)
7. **High #7**: Log rotation (10 min)
8. **High #8**: Extract percentage helper (15 min)

**Tiempo Total Estimado**: ~1 hora
