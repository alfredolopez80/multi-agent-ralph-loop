# CRITICAL: Hook Format Analysis and Remediation Plan
## Multi-Agent Ralph Loop v2.70.0

**Date**: 2026-01-27
**Severity**: CRITICAL
**Status**: ANALYSIS COMPLETE - REMEDIATION PENDING

---

## Executive Summary

Se descubrió una **discrepancia crítica** entre la documentación oficial actual de Claude Code y el formato JSON implementado en los hooks PreToolUse. Este análisis documenta el problema, investiga la causa raíz, y propone un plan de remediación.

### Key Findings

| Issue | Current State | Official Docs | Status |
|-------|---------------|---------------|--------|
| **PreToolUse Format** | `{"decision": "allow"}` | `{"hookSpecificOutput": {"permissionDecision": "allow"}}` | ⚠️ MISMATCH |
| **Stop Format** | `{"decision": "approve"}` | `{"decision": "approve\|block"}` | ✅ CORRECT |
| **PostToolUse Format** | `{"continue": true}` | `{"continue": true}` | ✅ CORRECT |

**Impact**: 13 PreToolUse hooks usando formato potencialmente deprecado

---

## Timeline of Events

### v2.53.0 (2026-01-19): Critical Hook Format Fix

**Problema**: Hooks usando `{"decision": "continue"}` (inválido)

**Solución aplicada**:
- Stop hooks: `{"decision": "continue"}` → `{"decision": "approve"}`
- PostToolUse: `{"continue": true}` (verificado correcto)
- PreToolUse: `{"decision": "allow"}` (establecido como correcto)

**Retrospectiva**: `2026-01-19-hook-json-format-critical-fix.md`

### v2.69.0 (2026-01-24): Comprehensive Hook System Remediation

**Fixes aplicados**:
- 44 hooks recibieron ERR EXIT trap
- 24 hooks recibieron fix CRIT-005
- 42 hooks sincronizados a v2.69.0
- Todos los hooks verificados como compliant

**Reporte**: `POST-FIX-STATUS-SUMMARY.md`

### v2.70.0 (2026-01-27): Discovery of Format Discrepancy

**Descubrimiento**: La documentación oficial actual muestra un formato diferente para PreToolUse

**Investigación en curso**: ¿Cuál es el formato correcto?

---

## Root Cause Analysis

### Possible Explanations

#### 1. Deprecated Format Still Functional (Most Likely)

**Hipótesis**: `{"decision": "allow"}` era el formato original y Claude Code mantiene backward compatibility.

**Evidencia**:
- Funciona correctamente en producción desde v2.53
- No hay errores reportados
- Las retrospectivas lo validaron como correcto

**Recomendación**: Migrar al nuevo formato para forward compatibility

#### 2. Documentation Changed, Code Didn't

**Hipótesis**: La documentación se actualizó al nuevo formato `hookSpecificOutput` pero el código no migró.

**Evidencia**:
- Context7 MCP muestra el formato nuevo
- El archivo SKILL.md oficial también muestra el formato nuevo
- No hay evidencia de anuncio de deprecación

**Recomendación**: Migrar urgentemente al formato nuevo

#### 3. Two Valid Formats Exist

**Hipótesis**: Ambos formatos son válidos, pero `hookSpecificOutput` es el "preferido" o "recomendado".

**Evidencia**:
- Ninguna documentación menciona dos formatos
- No hay ejemplos usando `{"decision": "allow"}` en docs actuales

**Recomendación**: Verificar con Claude Code support

---

## Official Hook Formats (Current Documentation)

### PreToolUse Hooks

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow|deny|ask",
    "updatedInput": {"field": "modified_value"}
  },
  "systemMessage": "Explanation for Claude"
}
```

**Key points**:
- `permissionDecision` va DENTRO de `hookSpecificOutput`
- Valores válidos: `allow`, `deny`, `ask`
- `updatedInput` es opcional para modificar tool inputs

### Stop Hooks

```json
{
  "decision": "approve|block",
  "reason": "Explanation",
  "systemMessage": "Additional context"
}
```

**Key points**:
- `decision` está al nivel raíz (NO dentro de `hookSpecificOutput`)
- Valores válidos: `approve`, `block`
- `reason` es opcional

### PostToolUse Hooks

```json
{
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "Feedback for Claude"
}
```

**Key points**:
- `continue` es boolean
- `suppressOutput` es opcional
- No usa `hookSpecificOutput`

### UserPromptSubmit Hooks

```json
{
  "continue": true,
  "systemMessage": "Context to inject"
}
```

### PreCompact Hooks

```json
{
  "continue": true
}
```

---

## Current State Analysis

### Hooks Using `{"decision": "allow"}` (PreToolUse)

```
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/lsa-pre-step.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/repo-boundary-guard.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/fast-path-check.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/smart-memory-search.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/skill-validator.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/procedural-inject.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/checkpoint-smart-save.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/checkpoint-auto-save.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/git-safety-guard.py
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/smart-skill-reminder.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/orchestrator-auto-learn.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/task-orchestration-optimizer.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/inject-session-context.sh
```

**Total**: 13 hooks

### Hooks Using `{"decision": "approve"}` (Stop) ✅ CORRECT

```
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/continuous-learning.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/orchestrator-report.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/project-backup-metadata.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/reflection-engine.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/semantic-auto-extractor.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/sentry-report.sh
/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/stop-verification.sh
```

**Total**: 7 hooks (CORRECT according to official docs)

### Hooks Using `{"continue": true}` (PostToolUse) ✅ CORRECT

**Total**: 34 hooks (CORRECT according to official docs)

---

## Remediation Plan

### Option A: Migrate to New Format (Recommended)

**Pros**:
- Forward compatibility
- Matches current documentation
- Explicit structure with `hookSpecificOutput`
- Better for `updatedInput` capability

**Cons**:
- Requires changing 13 hooks
- Risk of breaking changes
- Need extensive testing

**Implementation**:

```bash
# Old format
echo '{"decision": "allow"}'

# New format
echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
```

### Option B: Verify with Official Support (Recommended First)

**Action**: Contact Claude Code support to verify:

1. Is `{"decision": "allow"}` deprecated?
2. Is backward compatibility guaranteed?
3. What is the migration path?
4. Any breaking changes expected?

### Option C: Add Compatibility Layer (Temporary)

Create a wrapper function that handles both formats:

```bash
output_pretool_allow() {
    # Check if we need old or new format
    if [[ "${HOOK_USE_NEW_FORMAT:-true}" == "true" ]]; then
        echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
    else
        echo '{"decision": "allow"}'
    fi
}
```

---

## Lessons from Previous Retrospectives

### From v2.53 (2026-01-19)

> **"The string `"continue"` is NEVER a valid value for the `decision` field in ANY Claude Code hook type!"**

- Stop hooks: Use `"approve"` or `"block"`
- All other hooks: Use `continue` as a **boolean** field (`"continue": true`)

### From v2.55 (2026-01-20)

> **"Aritmética en Bash: Siempre usar `var=$((var + 1))` en lugar de `((var++))` con `set -e`"**

### From v2.56 (2026-01-20)

> **"Hook Matcher Limitations: Not all Claude Code tools expose PostToolUse hooks"**

- Valid matchers: `Edit`, `Write`, `Bash`, `Task`, `Read`, `Grep`, `Glob`, `ExitPlanMode`
- Invalid: `TodoWrite`

### From v2.69 (2026-01-24)

> **"Error Trap Coverage: 100% of execution hooks must have ERR EXIT trap"**

---

## Recommended Actions

### Immediate (Before Next Release)

1. **Verify Format with Official Support**
   - Open issue on Claude Code GitHub
   - Check for migration guides
   - Verify backward compatibility

2. **Document Both Formats**
   - Add CLAUDE.md section explaining both formats
   - Mark which one is "current" vs "legacy"
   - Add migration guide

3. **Add Validation**
   - Create test to verify JSON output
   - Add to CI/CD pipeline

### Short-term (v2.70)

4. **Migrate to New Format** (if confirmed necessary)
   - Update all 13 PreToolUse hooks
   - Update documentation
   - Run full test suite

5. **Update Retrospectives**
   - Document this discovery
   - Add to lessons learned
   - Update CHANGELOG

### Long-term (v2.71+)

6. **Create Hook Format Validator**
   - Automated tool to check JSON formats
   - Part of pre-commit hooks
   - CI/CD integration

7. **Monitor for Deprecation Warnings**
   - Watch Claude Code changelog
   - Subscribe to updates
   - Test with beta versions

---

## Testing Plan

### Phase 1: Verification (Current)

```bash
# Test current format still works
grep -l '{"decision": "allow"}' ~/.claude/hooks/*.sh

# Verify all hooks have ERR trap
grep -l "trap 'output_json' ERR EXIT" ~/.claude/hooks/*.sh
```

### Phase 2: Migration Testing

```bash
# Test new format
echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}' | jq .

# Verify syntax
for hook in ~/.claude/hooks/*-pre*.sh; do
    bash -n "$hook"  # Syntax check
done
```

### Phase 3: Integration Testing

```bash
# Run full test suite
bats tests/test_*.bats

# Test actual Claude Code execution
claude-code --test-hook
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Breaking change from format migration | Medium | High | Verify with support first |
| Current format deprecated without notice | Low | High | Monitor changelog closely |
| Documentation is wrong | Low | Medium | Multiple source verification |
| Both formats valid indefinitely | High | Low | Document both explicitly |

---

## Conclusion

The Multi-Agent Ralph Loop hook system is **functional and production-ready**, but there is a **critical discrepancy** between implemented code and current official documentation for PreToolUse hooks.

**Current Status**: ⚠️ NEEDS VERIFICATION
**Recommended Action**: Verify with Claude Code support before migrating
**Timeline**: 1-2 weeks for verification, 1 week for migration if needed

---

## References

- [Claude Code Hooks Documentation](https://docs.anthropic.com/claude-code/hooks)
- [SKILL.md - Hook Development](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/hook-development/SKILL.md)
- Retrospective: `2026-01-19-hook-json-format-critical-fix.md`
- Retrospective: `2026-01-20-curator-v2.55-critical-fixes.md`
- Retrospective: `2026-01-20-context-compaction-planstate-audit.md`
- Post-Fix Status: `POST-FIX-STATUS-SUMMARY.md`

---

*Generated by Multi-Agent Ralph Loop v2.70.0*
*Analysis Date: 2026-01-27*
*Severity: CRITICAL - Verification Required*
