#!/bin/bash
# update-skills-with-action-reporting.sh - Add Action Reporting section to all skills
# VERSION: 2.93.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# List of skills to update
SKILLS=(
    "adversarial"
    "bugs"
    "code-reviewer"
    "create-task-batch"
    "curator"
    "curator-repo-learn"
    "edd"
    "glm5-parallel"
    "loop"
    "parallel"
    "quality-gates-parallel"
    "security"
    "task-batch"
)

# Template for Action Reporting section
ACTION_REPORTING_SECTION='
## Action Reporting (v2.93.0)

**Esta skill genera reportes automáticos completos** para trazabilidad:

### Reporte Automático

Cuando esta skill completa, se genera automáticamente:

1. **En la conversación de Claude**: Resultados visibles
2. **En el repositorio**: `docs/actions/{skill-name}/{timestamp}.md`
3. **Metadatos JSON**: `.claude/metadata/actions/{skill-name}/{timestamp}.json`

### Contenido del Reporte

Cada reporte incluye:
- ✅ **Summary**: Descripción de la tarea ejecutada
- ✅ **Execution Details**: Duración, iteraciones, archivos modificados
- ✅ **Results**: Errores encontrados, recomendaciones
- ✅ **Next Steps**: Próximas acciones sugeridas

### Ver Reportes Anteriores

```bash
# Listar todos los reportes de esta skill
ls -lt docs/actions/{skill-name}/

# Ver el reporte más reciente
cat $(ls -t docs/actions/{skill-name}/*.md | head -1)

# Buscar reportes fallidos
grep -l "Status: FAILED" docs/actions/{skill-name}/*.md
```

### Generación Manual (Opcional)

```bash
source .claude/lib/action-report-lib.sh
start_action_report "{skill-name}" "Task description"
# ... ejecución ...
complete_action_report "success" "Summary" "Recommendations"
```

### Referencias del Sistema

- [Action Reports System](docs/actions/README.md) - Documentación completa
- [action-report-lib.sh](.claude/lib/action-report-lib.sh) - Librería helper
- [action-report-generator.sh](.claude/lib/action-report-generator.sh) - Generador
'

echo "=== Updating Skills with Action Reporting Section ==="
echo ""

for skill in "${SKILLS[@]}"; do
    skill_file="${REPO_ROOT}/.claude/skills/${skill}/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
        echo "⚠️  Skipping ${skill}: SKILL.md not found"
        continue
    fi

    # Check if already updated
    if grep -q "Action Reporting (v2.93.0)" "$skill_file"; then
        echo "✓ ${skill}: Already has Action Reporting section"
        continue
    fi

    # Create skill-specific section
    skill_section=$(echo "$ACTION_REPORTING_SECTION" | sed "s/{skill-name}/${skill}/g")

    # Find insertion point (before "References" or at end of file)
    if grep -q "^## References" "$skill_file"; then
        # Insert before "References"
        temp_file="${skill_file}.tmp"
        {
            # Everything before "References"
            sed -e '/^## References/,$d' "$skill_file"
            # New section
            echo "$skill_section"
            # "References" and everything after
            sed -e '1,/^## References/d' "$skill_file"
        } > "$temp_file"
        mv "$temp_file" "$skill_file"
        echo "✓ ${skill}: Added Action Reporting section (before References)"
    else
        # Append to end
        echo "" >> "$skill_file"
        echo "$skill_section" >> "$skill_file"
        echo "✓ ${skill}: Added Action Reporting section (appended)"
    fi
done

echo ""
echo "=== Update Complete ==="
echo ""
echo "Next steps:"
echo "1. Review changes: git diff .claude/skills/"
echo "2. Commit: git add .claude/skills/ && git commit -m 'feat(skills): add Action Reporting section v2.93.0'"
