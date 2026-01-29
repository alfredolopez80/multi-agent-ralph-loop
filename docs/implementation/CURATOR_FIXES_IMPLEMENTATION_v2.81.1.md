# Curator Fixes Implementation - v2.81.1

**Fecha**: 2026-01-29
**Versión**: v2.81.1
**Estado**: EN PROGRESO

---

## Resumen de Validación (Fase 0)

### Hooks Validation Results

**Total hooks evaluados**: 9
**Hooks CRÍTICOS**: 2 (NO eliminar)
- `plan-state-init.sh` - CRÍTICO
- `orchestrator-auto-learn.sh` - CRÍTICO

**Hooks SAFE para eliminar**: 2
- `semantic-auto-extractor.sh` - Puede ser removido
- `agent-memory-auto-init.sh` - Puede ser removido

**Hooks que requieren REVISIÓN**: 5

### Snapshot del Estado Actual

**Ubicación**: `.claude/snapshots/20260129/`

**Archivos backup**:
- `rules.json.backup` (490KB)
- `plan-state.json.backup` (3.7KB)

**Estadísticas de Reglas Procedimentales**:
```json
{
  "total": 1003,
  "with_id": 1,
  "with_domain": 148,
  "with_usage": 146
}
```

**Problemas identificados**:
- Solo 1 regla tiene ID (0.1%)
- 148 reglas tienen dominio (14.7%)
- 146 reglas tienen uso_count > 0 (14.5%)
- **Utilization rate**: 14.5% (muy bajo)

---

## Fase 1: Fixes Críticos de Curator

### Scripts a Modificar

1. ✅ `curator-scoring.sh` - Análisis completado
2. ⏳ `curator-discovery.sh` - Pendiente
3. ⏳ `curator-rank.sh` - Pendiente
4. ❌ `curator-ingest.sh` - NO EXISTE (ya resuelto)

### Bugs Identificados

#### curator-scoring.sh

**Estado**: ✅ Análisis completado

**Problemas encontrados**:
1. ⚠️ While loop sin error handling (línea 165)
2. ⚠️ Temp file sin cleanup con trap
3. ⚠️ No hay validación de JSON output

**Solución**: Crear versión mejorada con:
- Error handling en while loop
- Trap para cleanup de temp files
- Validación de JSON output
- Logging a stderr

#### curator-discovery.sh

**Estado**: ⏳ Pendiente de análisis

**Problemas esperados** (según CURATOR_FLOW.md):
1. GitHub API rate limiting mal manejado
2. Error en handling de rate limits
3. Fixed 2s sleep (debería ser exponential backoff)

#### curator-rank.sh

**Estado**: ⏳ Pendiente de análisis

**Problemas esperados** (según CURATOR_FLOW.md):
1. MAX_PER_ORG como string literal en lugar de variable
2. No hay error handling en jq operations

---

## Próximos Pasos

1. ✅ Completar análisis de curator-scoring.sh
2. ⏳ Leer y analizar curator-discovery.sh
3. ⏳ Leer y analizar curator-rank.sh
4. ⏳ Implementar fixes para los 3 scripts
5. ⏳ Validar fixes con tests

---

## Notas de Implementación

### Fix #1: Error Handling en While Loops

**Problema actual**:
```bash
while IFS= read -r repo; do
    # Si algo falla aquí, el error se ignora
    score=$(calculate_score "$repo")
done < input
```

**Solución propuesta**:
```bash
set -o pipefail
local tmp_output="${OUTPUT_FILE}.tmp.$$"
while IFS= read -r repo; do
    score=$(calculate_score "$repo" "$CONTEXT") || {
        log_error "Scoring failed for: $repo"
        rm -f "$tmp_output"
        return 1
    }
    # ... procesar ...
done < <(jq -c '.[]' "$INPUT_FILE") > "$tmp_output"
```

### Fix #2: Temp File Cleanup con Trap

**Problema actual**:
```bash
local temp_file="${OUTPUT_FILE}.tmp.$$"
# Si script falla, temp file se queda
```

**Solución propuesta**:
```bash
local temp_file="${OUTPUT_FILE}.tmp.$$"
trap 'rm -f "$temp_file"' EXIT
# Si algo falla, el trap limpia automáticamente
```

### Fix #3: Logging a Stderr

**Problema actual**:
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }  # Va a stdout
```

**Solución propuesta**:
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }  # Va a stderr
# Así no contamina stdout cuando se usa en pipes
```

---

*Última actualización: 2026-01-29 20:55*
