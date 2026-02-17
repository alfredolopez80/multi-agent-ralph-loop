# Action Reports System (v2.93.0)

Sistema unificado de generación de reportes para todas las skills de Multi-Agent Ralph Loop.

## 📋 Propósito

Garantizar que **todas** las skills generen reportes completos y detallados que:
1. ✅ **Siempre visibles en Claude** (stdout)
2. ✅ **Guardados en `docs/actions/{skill}/`** (trazabilidad)
3. ✅ **Funcionan en foreground y background**
4. ✅ **Incluyen metadatos completos** (tiempo, iteraciones, archivos, errores)

## 🏗️ Arquitectura

```
docs/actions/
├── orchestrator/
│   ├── 20260217-154522.md      # Markdown report (legible)
│   └── 20260217-161503.md
├── gates/
│   └── 20260217-152230.md
├── loop/
│   └── 20260217-145510.md
└── security/
    └── 20260217-163345.md

.claude/metadata/actions/
├── orchestrator/
│   └── 20260217-154522.json    # JSON metadata (procesable)
└── gates/
    └── 20260217-152230.json
```

## 🚀 Uso Rápido

### Método 1: Automático (Hook)

El hook `action-report-tracker.sh` genera reportes automáticamente:

```bash
# En settings.json, registrar el hook:
{
  "hooks": {
    "PostToolUse": [
      {
        "path": ".claude/hooks/action-report-tracker.sh",
        "match_tool": "Task"
      }
    ]
  }
}
```

### Método 2: Manual (En Skills)

```bash
# Al inicio de tu skill
source .claude/lib/action-report-lib.sh
start_action_report "orchestrator" "Implementing OAuth2 authentication"

# Durante la ejecución
mark_iteration
mark_file_modified "src/auth/oauth.ts"
record_error "Type mismatch in config"

# Al completar
complete_action_report \
    "success" \
    "OAuth2 implementation completed successfully" \
    "Run tests: npm test"
```

## 📊 Formato del Reporte

Cada reporte incluye:

### Markdown (docs/actions/{skill}/{timestamp}.md)

```markdown
# ✅ Action Report: orchestrator

**Generated**: 2026-02-17T15:45:22Z
**Status**: COMPLETED
**Session**: `session_abc123`

---

## Summary

Implementing OAuth2 authentication with Google provider

---

## Execution Details

| Metric | Value |
|--------|-------|
| **Duration** | 5m 23s |
| **Iterations** | 3 |
| **Files Modified** | 7 |
| **Model** | glm-5 |

### Git State

| Property | Value |
|----------|-------|
| **Branch** | `feature/oauth2` |
| **Commit** | `a1b2c3d` |
| **Changed Files** | 7 |

---

## Results

### Errors
```
None
```

### Recommendations
Run security audit: /security src/

---

## Next Steps

1. Review the changes made
2. Run quality gates: `/gates`
3. Run security audit: `/security`
4. Commit changes if verified
```

### JSON Metadata (.claude/metadata/actions/{skill}/{timestamp}.json)

```json
{
  "skill_name": "orchestrator",
  "status": "completed",
  "description": "Implementing OAuth2 authentication",
  "details": {
    "duration": "5m 23s",
    "iterations": 3,
    "files_modified": 7,
    "errors": "None",
    "recommendations": "Run /security"
  },
  "timestamp": "2026-02-17T15:45:22Z",
  "report_file": "docs/actions/orchestrator/20260217-154522.md",
  "version": "2.93.0"
}
```

## 🔧 Integración en Skills

### Ejemplo: /orchestrator

Al final de `orchestrator/SKILL.md`, agregar:

```markdown
## Action Reporting (v2.93.0)

El orchestrator genera automáticamente reportes completos:

1. **Durante la ejecución**: Progreso visible en Claude
2. **Al completar**: Reporte final en:
   - Conversación de Claude (stdout)
   - `docs/actions/orchestrator/{timestamp}.md`
   - `.claude/metadata/actions/orchestrator/{timestamp}.json`

### Generación Manual

Si necesitas generar un reporte manualmente:

```bash
source .claude/lib/action-report-lib.sh
start_action_report "orchestrator" "Task description"
# ... ejecución ...
complete_action_report "success" "Summary" "Recommendations"
```

### Ver Reportes Anteriores

```bash
# Listar todos los reportes del orchestrator
ls -lt docs/actions/orchestrator/

# Ver el reporte más reciente
cat $(ls -t docs/actions/orchestrator/*.md | head -1)
```
```

### Ejemplo: /gates

```markdown
## Action Reporting (v2.93.0)

Los resultados de `/gates` se guardan en `docs/actions/gates/`:

- **Markdown**: Reporte legible con resultados de validación
- **JSON**: Metadatos procesables para integración CI/CD

### Reporte Automático

```bash
/gates  # Genera reporte automáticamente en docs/actions/gates/
```

### Reporte Manual

```bash
source .claude/lib/action-report-lib.sh
start_action_report "gates" "Running quality gates"

# Run validators
tsc --noEmit
eslint .
npm test

complete_action_report \
    "success" \
    "All quality gates passed" \
    "Safe to commit: git commit -m 'chore: pass quality gates'"
```
```

## 📈 Estadísticas y Consultas

### Ver estadísticas de una skill

```bash
source .claude/lib/action-report-generator.sh

# Estadísticas completas
get_skill_stats "orchestrator"

# Output:
# Skill: orchestrator
# Total Reports: 45
# Completed: 42
# Failed: 3
# Success Rate: 93%
```

### Listar reportes

```bash
source .claude/lib/action-report-generator.sh

# Todos los reportes de una skill
list_reports "orchestrator"

# Último reporte
find_latest_report "orchestrator"
```

### Buscar reportes por criterios

```bash
# Reportes de hoy
find docs/actions/ -name "*.md" -newermt "today" -type f

# Reportes fallidos
grep -r "Status: FAILED" docs/actions/

# Reportes con errores
grep -r "## Errors" docs/actions/ -A 5
```

## 🎯 Mejores Prácticas

### 1. Generar Reportes Siempre

```bash
# ✅ BIEN - Genera reporte
source .claude/lib/action-report-lib.sh
start_action_report "skill" "Description"
# ... trabajo ...
complete_action_report "success" "Done"

# ❌ MAL - No genera reporte
# ... trabajo sin tracking ...
```

### 2. Incluir Contexto Útil

```bash
# ✅ BIEN - Descripción detallada
start_action_report "orchestrator" "Implementing OAuth2 with Google provider for user authentication"

# ❌ MAL - Descripción vaga
start_action_report "orchestrator" "Doing stuff"
```

### 3. Registrar Errores

```bash
# ✅ BIEN - Registra errores específicos
if ! npm test; then
    record_error "Test failed: auth.test.ts::login() expects 200, got 500"
fi

# ❌ MAL - Error genérico
if ! npm test; then
    record_error "Tests failed"
fi
```

### 4. Recomendaciones Accionables

```bash
# ✅ BIEN - Recomendaciones específicas
complete_action_report "partial" "OAuth implemented, tests pending" "
1. Fix test failure: npm test -- auth.test.ts
2. Run security audit: /security src/auth/
3. Review code: /code-reviewer src/auth/
"

# ❌ MAL - Recomendaciones vagas
complete_action_report "partial" "Some work left" "Finish the rest"
```

## 🔄 Integración con Hooks Existentes

### Compatibilidad con orchestrator-report.sh

```bash
# El hook action-report-tracker.sh es COMPLEMENTARIO
# No reemplaza a orchestrator-report.sh, lo extiende

# orchestrator-report.sh → Reportes de sesión en ~/.ralph/reports/
# action-report-tracker.sh → Reportes de acción en docs/actions/
```

### Compatibilidad con progress-tracker.sh

```bash
# progress-tracker.sh → .claude/progress.md (por proyecto)
# action-report-tracker.sh → docs/actions/{skill}/ (por skill)

# Ambos pueden coexistir sin conflictos
```

## 🧪 Testing

### Verificar Sistema de Reportes

```bash
# Test básico
source .claude/lib/action-report-lib.sh
start_action_report "test" "Testing action report system"
mark_iteration
mark_file_modified "test.txt"
complete_action_report "success" "Test completed"

# Verificar archivos creados
ls -la docs/actions/test/
cat docs/actions/test/*.md
ls -la .claude/metadata/actions/test/
cat .claude/metadata/actions/test/*.json
```

### Verificar Hook

```bash
# Simular invocación de skill
echo '{
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "orchestrator",
    "description": "Test task"
  },
  "tool_result": "Success"
}' | .claude/hooks/action-report-tracker.sh

# Verificar reporte creado
ls -lt docs/actions/orchestrator/ | head -5
```

## 📚 Referencias

- **Librería principal**: `.claude/lib/action-report-generator.sh`
- **Librería helper**: `.claude/lib/action-report-lib.sh`
- **Hook automático**: `.claude/hooks/action-report-tracker.sh`
- **Directorio de reportes**: `docs/actions/`
- **Metadatos**: `.claude/metadata/actions/`

## 🆘 Troubleshooting

### Reportes no se generan

```bash
# Verificar permisos
ls -la .claude/lib/*.sh
chmod +x .claude/lib/*.sh

# Verificar hook registrado
cat ~/.claude/settings.json | grep action-report-tracker
```

### Reportes no visibles en Claude

```bash
# Verificar que el reporte se imprime en stdout
# NO usar > /dev/null en generate_action_report
```

### Directorio docs/actions/ no existe

```bash
# Se crea automáticamente al primer uso
# O manualmente:
mkdir -p docs/actions
```

## 📝 Changelog

### v2.93.0 (2026-02-17)
- ✅ Sistema unificado de reportes creado
- ✅ Soporte para todas las skills
- ✅ Reportes visibles en Claude + archivos
- ✅ Metadatos JSON para procesamiento
- ✅ Funciona en foreground y background
- ✅ Integración con hooks existentes
