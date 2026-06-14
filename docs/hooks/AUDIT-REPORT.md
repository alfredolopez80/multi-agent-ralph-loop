# Hook Audit Report — multi-agent-ralph-loop
**Fecha**: 2026-06-14 | **Validator**: API Claude Code actual (docs.claude.com)

## Resumen Ejecutivo

Se encontraron **2 categorias de bugs criticos** causando errores de validacion
en Claude Code:

| Bug | Ocurrencias | Causa | Impacto |
|-----|-------------|-------|---------|
| `{"decision": "approve"}` | 38 en codigo | Formato obsoleto | "Hook JSON output validation failed" |
| Campos `feedback`/`cleanup` | 5 en codigo | Campos inexistentes | JSON validation error adicional |

**Total**: 13 archivos afectados, 43 correcciones aplicadas.

## Root Cause Analysis

### Bug #1: {"decision": "approve"} — Formato Inexistente

La regla SEC-039 del sistema ralph documentaba:
> Stop hooks MUST use {"decision": "approve"} or {"decision": "block"}

Esto era valido en una version anterior de Claude Code. La API actual cambio:
el campo `decision` solo acepta `"block"` o ausente. **No existe "approve"**.

### Bug #2: {"continue": true} — Valido pero Innecesario

~25 hooks emiten `{"continue": true}` que es tecnicamente valido (campo comun)
pero completamente innecesario — `continue: true` es el default. No causa errores.

### Bug #3: Error de Node.js (cjs/loader:1215)

No reproducible en el repo. Probable causa: un hook en `~/.claude/settings.json`
que referencia un script .js inexistente o con un require roto. Revisar settings.

## Archivos Corregidos

1. anti-rationalization-gate.sh (4 fixes)
2. continuous-learning.sh (4 fixes)
3. orchestrator-report.sh (2 fixes)
4. project-backup-metadata.sh (3 fixes)
5. ralph-stop-quality-gate.sh (5 fixes)
6. ralph-subagent-stop.sh (5 fixes: approve + feedback + cleanup)
7. sentry-report.sh (3 fixes)
8. subagent-stop-universal.sh (1 fix)
9. task-completed-quality-gate.sh (1 fix)
10. teammate-idle-quality-gate.sh (1 fix)
11. vault-index-updater.sh (3 fixes)
12. vault-log-writer.sh (3 fixes)
13. vault-wing-compiler.sh (5 fixes)
14. vault-writeback.sh (4 fixes)

## Formato Correcto (Referencia Actual)

### Para PERMITIR/dejar pasar (todos los eventos)
```bash
exit 0  # No emitir JSON. Solo salir limpio.
```

### Stop/SubagentStop — BLOQUEAR
```bash
echo '{"decision":"block","reason":"Razon especifica"}'
exit 0
```

### PreToolUse — DENEGAR
```bash
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Razon"}}'
exit 0
```

### PostToolUse/UserPromptSubmit/SessionStart — AGREGAR CONTEXTO
```bash
echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Contexto"}}'
exit 0
```

## Acciones Recomendadas

1. **YA APLICADO**: fix-hook-formats.sh ejecutado en el repo
2. **Verificar**: Ejecutar validate-hooks-v2.sh antes de cada commit
3. **Actualizar regla SEC-039**: El formato {"decision": "approve"} es INVALIDO
4. **Investigar error Node.js**: Revisar ~/.claude/settings.json por hooks .js rotos
5. **Actualizar tests**: Los tests que esperan {"decision": "approve"} estan mal
