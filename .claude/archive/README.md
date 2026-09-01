# Archive — purge policy (política de purga)

> **Policy (English)**: archive files without active callers are **deleted** in
> the next slice; not kept "por si acaso". This **purge** rule replaces the
> old "archive but never remove" habit.

## Propósito

Este directorio contiene snapshots históricos de hooks, skills, scripts y docs del
repo. Por su naturaleza, tiende a acumular residuos: archivos archivados "por si
acaso" cuyos callers activos desaparecieron hace tiempo.

## Política (Slice F, 2026-09-01)

**Archive sin caller activo se elimina en el slice siguiente; no se mantiene por
defecto.** Concreto:

1. **Antes de archivar**, evaluar si vale la pena: si el caller todavía existe y
   el archivo podría volver, archivar; si no, hacer `git rm` directo sin pasar
   por archive.
2. **Después de archivar**, en el siguiente slice de barrido, re-evaluar: ¿el
   caller volvió? Si no, `git rm` sin contemplaciones.
3. **Menciones en audit/benchmark son históricas**, no callers. Un doc en
   `docs/audit/` o `benchmark/` que menciona un archivo archivado NO es razón
   para mantenerlo.
4. **Distributors no deben recrear borrados**: `install.sh`, `sync-rules-from-source.sh`,
   y todos los `validate-*.sh` se auditan por referencias residuales antes de
   cada merge. Una referencia a un archivo borrado es una regresión del
   distributor, no motivo para revertir el borrado.

## Verificación de no-recreación

Tras cualquier `git rm` en archive/:

```bash
for h in <hook-name>; do
  grep -rln "$h" scripts/ .claude/scripts/ install*.sh .claude/skills/ \
    .claude/settings.json.example .claude/hooks/ 2>/dev/null | \
    grep -v "^./.claude/archive/" | \
    grep -v "docs/audit/" | grep -v "benchmark/" || echo "OK: $h no references"
done
```

`OK` significa que ningún distributor, skill, ni hook activo referencia el archivo.
Si el grep devuelve paths, parar y eliminar las referencias antes de hacer merge.

## Survivors (NO se tocan)

- `pre-migration-v2.70.0-20260127-231849/` — contiene snapshots antiguos de
  hooks cuyo código evolucionó a versiones activas. NO es residuo.
- `hooks-audit-20260119/` — auditoría de hooks fechada. NO es residuo.
- `docs/audit/`, `scripts/benchmark_*.py` — referencias a archivos archiveados
  son históricas y permitidas.
- `CHANGELOG.md`, `ARCHIVED_*` files — snapshots explícitamente fechados.

## Slice F — archivos purgados

| archivo | caller eliminado | slice |
|---|---|---|
| `pre-migration-v2.70.0-20260127-231849/memory-write-trigger.sh` | ninguno activo (PR8 verificado) | PR11-EXEC C2 (2026-09-01) |
| `pre-migration-v2.70.0-20260127-231849/semantic-auto-extractor.sh` | ninguno activo (PR8 verificado) | PR11-EXEC C2 |
| `pre-migration-v2.70.0-20260127-231849/episodic-auto-convert.sh` | ninguno activo (PR8 verificado) | PR11-EXEC C2 |
| `pre-migration-v2.70.0-20260127-231849/reflection-engine.sh` | ninguno activo (PR8 verificado) | PR11-EXEC C2 |
| `hooks-audit-20260119/memory-write-trigger.sh` | ninguno activo (segunda copia) | PR11-EXEC C2 |
| `hooks-audit-20260119/reflection-engine.sh` | ninguno activo (segunda copia) | PR11-EXEC C2 |
