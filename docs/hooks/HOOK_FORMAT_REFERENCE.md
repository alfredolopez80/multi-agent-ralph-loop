# Hook JSON Format Reference (Actualizado 2026-06-14)

## El Problema

Los hooks de ralph usaban `{"decision": "approve"}` que **NO EXISTE**
en la API actual de Claude Code. Esto causaba:

```
Hook JSON output validation failed — (root): Invalid input
```

## Formato Correcto por Tipo de Evento

### Regla Universal

**Para PERMITIR/dejar pasar: no emitir JSON, solo `exit 0`.**
El JSON solo es necesario cuando quieres cambiar el comportamiento.

### PreToolUse

```bash
# PERMITIR (default):
exit 0

# DENEGAR (bloquear tool call):
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Razón"}}'
exit 0

# O usar exit code 2 (más simple):
echo "Razón del bloqueo" >&2
exit 2
```

### PostToolUse

```bash
# PERMITIR (default):
exit 0

# Enviar feedback a Claude:
echo '{"decision":"block","reason":"Problema encontrado"}'
exit 0

# Agregar contexto:
echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Info extra"}}'
exit 0
```

### Stop / SubagentStop

```bash
# PERMITIR que Claude pare (default):
exit 0

# BLOQUEAR (forzar a continuar):
echo '{"decision":"block","reason":"Aún hay trabajo pendiente"}'
exit 0
```

### UserPromptSubmit

```bash
# PERMITIR (default):
exit 0

# BLOQUEAR prompt:
echo '{"decision":"block","reason":"Prompt no permitido"}'
exit 0

# Agregar contexto:
echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Contexto adicional"}}'
exit 0
```

### SessionStart

```bash
# Solo agregar contexto (no puede bloquear):
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Contexto de inicio"}}'
exit 0
```

### SessionEnd / PreCompact

```bash
# No pueden bloquear. Solo exit 0:
exit 0
```

## Campos Válidos

| Campo | Tipo | Eventos | Descripción |
|-------|------|---------|-------------|
| `continue` | bool | Todos | Si false, Claude se detiene (default: true) |
| `decision` | "block" / undefined | Stop, SubagentStop, PostToolUse, UserPromptSubmit | Bloquear acción |
| `reason` | string | Con `decision: block` | Razón mostrada a Claude |
| `suppressOutput` | bool | Todos | Ocultar stdout del transcript |
| `permissionDecision` | "allow"/"deny"/"ask" | PreToolUse | Control de permisos |
| `additionalContext` | string | UserPromptSubmit, SessionStart, PostToolUse | Contexto para Claude |

## Lo que NUNCA se debe usar

| Patrón | Por qué es inválido |
|--------|---------------------|
| `{"decision": "approve"}` | "approve" NO es un valor válido. Usar exit 0. |
| `{"decision": "continue"}` | "continue" NO es un valor de decision. |
| `{"feedback": "..."}` | Campo inexistente. Usar `reason`. |
| `{"cleanup": "..."}` | Campo inexistente. |
| `{"decision": "allow"}` en Stop hooks | Stop no usa permissionDecision. Usar exit 0. |
