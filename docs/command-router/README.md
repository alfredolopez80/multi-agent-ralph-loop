# Intelligent Command Router Hook

**Date**: 2026-01-30
**Version**: 1.0.0
**Status**: IMPLEMENTED

## Summary

The **Intelligent Command Router Hook** (`command-router.sh`) analyzes user prompts and suggests the optimal command based on detected patterns. It provides non-intrusive suggestions via `additionalContext` when confidence >= 80%, allowing users to benefit from intelligent routing without interrupting their workflow.

## Architecture

```
User Prompt → Pattern Analysis → Intent Classification → Confidence Check → Suggestion
                ↓                      ↓                      ↓
         Keywords + Word Count     9 Commands             ≥ 80%?
```

## Supported Commands

| Command | Use Case | Trigger Patterns | Confidence |
|---------|----------|------------------|------------|
| **`/bug`** | Systematic debugging | bug, error, fallo, excepción, crash | 90% |
| **`/edd`** | Feature definition | define, specification, capability, requerimiento | 85% |
| **`/orchestrator`** | Complex tasks | implement, create, build, migrate + multi-step | 85% |
| **`/loop`** | Iterative tasks | iterate, loop, until, retry, iterar, hasta | 85% |
| **`/adversarial`** | Spec refinement | spec, refine, edge cases, gaps, especificación | 85% |
| **`/gates`** | Quality validation | quality gates, lint, validation, calidad | 85% |
| **`/security`** | Security audit | security, vulnerability, OWASP, inyección | 88% |
| **`/parallel`** | Comprehensive review | comprehensive review, multiple aspects | 85% |
| **`/audit`** | Quality audit | audit, health check, auditoría, calidad | 82% |

## Features

### 1. Multilingual Support

The hook detects patterns in both **English** and **Spanish**:

```bash
# English
"Implement authentication and then add refresh tokens" → /orchestrator

# Spanish
"Implementa autenticación y luego agrega refresh tokens" → /orchestrator
```

### 2. Confidence-Based Filtering

Only suggests when confidence >= 80%:

```bash
# High confidence (90%)
"Tengo un bug en el login" → Suggests /bug

# Low confidence (< 80%)
"Hola" → No suggestion
```

### 3. Non-Intrusive Integration

Uses `additionalContext` instead of `action: "ask_user"`:

```json
{
    "additionalContext": "💡 **Sugerencia**: Detecté una tarea de debugging...",
    "continue": true
}
```

### 4. Security Features

- **Input validation**: 100KB max input size (SEC-111)
- **Sensitive data redaction**: Passwords, tokens, API keys (SEC-110)
- **Error trap**: Guaranteed JSON output on errors
- **Read-only access**: No filesystem modifications

## Installation

### Hook Registration

The hook is registered in `~/.claude-sneakpeek/zai/config/settings.json`:

```json
{
    "hooks": {
        "UserPromptSubmit": [
            {
                "matcher": "*",
                "hooks": [
                    {
                        "type": "command",
                        "command": "/path/to/command-router.sh"
                    }
                ]
            }
        ]
    }
}
```

### Configuration File

User preferences stored in `~/.ralph/config/command-router.json`:

```json
{
    "enabled": true,
    "confidence_threshold": 80,
    "version": "1.0.0"
}
```

## Usage Examples

### Bug Detection

```bash
# User prompt
"Tengo un bug en el login que no deja entrar a los usuarios"

# Hook response
💡 **Sugerencia**: Detecté una tarea de debugging. Considera usar `/bug` para debugging sistemático: analizar → reproducir → localizar → corregir → validar.
```

### Complex Task Detection

```bash
# User prompt
"Implementa autenticación OAuth y luego agrega refresh tokens"

# Hook response
💡 **Sugerencia**: Detecté una tarea compleja. Considera usar `/orchestrator` para workflow completo: evaluar → clarificar → clasificar → planear → ejecutar → validar.
```

### Iterative Task Detection

```bash
# User prompt
"Itera hasta que pasen todos los tests unitarios"

# Hook response
💡 **Sugerencia**: Detecté una tarea iterativa. Considera usar `/loop` para ejecución repetida hasta que pasen los quality gates.
```

## Testing

Run the validation test suite:

```bash
./tests/test-command-router.sh
```

Test cases include:
- 9 intent classification tests (one per command)
- 3 edge case tests (no match expected)
- Security tests (input size, redaction, error trap)
- JSON output validation

## Disabling the Hook

To disable the router temporarily:

```bash
# Method 1: Via config file
echo '{"enabled": false}' > ~/.ralph/config/command-router.json

# Method 2: Remove from settings.json
# Edit ~/.claude-sneakpeek/zai/config/settings.json and remove the hook entry
```

## Logging

Logs stored in `~/.ralph/logs/command-router.log`:

```
[2026-01-30 15:30:00] [INFO] Processing prompt: Tengo un bug en el login...
[2026-01-30 15:30:00] [DEBUG] Intent: bug, Confidence: 90%
[2026-01-30 15:30:00] [INFO] Suggesting /bug (confidence: 90%)
```

## Performance

- **Execution time**: ~50-100ms per prompt
- **Overhead**: Minimal (grep + jq + word count)
- **User impact**: Optional (can be disabled)

## Integration with Existing Hooks

The hook integrates seamlessly with the existing hook system:

```
UserPromptSubmit Event
    ↓
1. context-warning.sh           (Context monitoring)
2. command-router.sh            (Command suggestions) ← NEW
3. memory-write-trigger.sh      (Memory detection)
4. periodic-reminder.sh          (Task reminders)
5. plan-state-adaptive.sh        (Plan creation)
```

## Future Enhancements

Potential improvements for future versions:

1. **Machine Learning**: Train a classifier on actual usage data
2. **User Preferences**: Learn from user's command choices
3. **Context Awareness**: Consider file types, recent commands
4. **Custom Patterns**: Allow users to add custom keywords
5. **Multi-command Suggestions**: Suggest multiple commands when applicable

## Troubleshooting

### Hook Not Suggesting

Check if:
1. Hook is registered in `settings.json`
2. Confidence is >= 80% (check logs)
3. Router is enabled in config
4. Pattern matches the expected keywords

### False Positives

If getting unwanted suggestions:
1. Adjust `confidence_threshold` in config
2. Disable specific commands in config
3. Disable router entirely

### Performance Issues

If experiencing slowdowns:
1. Check log file size (rotate if > 10MB)
2. Reduce regex complexity in patterns
3. Disable router temporarily

## Files

| File | Purpose |
|------|---------|
| `.claude/hooks/command-router.sh` | Main hook script |
| `~/.ralph/config/command-router.json` | User configuration |
| `~/.ralph/logs/command-router.log` | Execution logs |
| `tests/test-command-router.sh` | Validation tests |
| `docs/command-router/README.md` | This documentation |

## References

- **Implementation Plan**: `docs/command-router/IMPLEMENTATION_PLAN.md`
- **CLAUDE.md**: Project documentation
- **CHANGELOG.md**: Version history
- **Hook System**: `.claude/hooks/CLAUDE.md`

---

**Version**: 1.0.0
**Last Updated**: 2026-01-30
**Author**: Claude (GLM-4.7)
