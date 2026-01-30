# Skills Globales - Análisis y Solución v2.81.1

**Date**: 2026-01-30
**Version**: v2.81.1
**Status**: PROBLEM IDENTIFIED - SOLUTION PROVIDED

## Problema: `/readme` y skills no disponibles globalmente

### Síntomas

- ❌ El comando `/readme` NO funciona en otros proyectos
- ❌ Los skills de multi-agent-ralph-loop solo funcionan en este proyecto
- ✅ Los skills funcionan DENTRO de multi-agent-ralph-loop

### Causa Raíz

Hay una confusión sobre DÓNDE deben estar los skills para que estén disponibles globalmente:

**Ubicaciones involucradas**:
1. `~/.claude-sneakpeek/zai/skills/` - Skills integrados de Zai (NO editar)
2. `~/.claude-sneakpeek/zai/config/skills/` - Skills del usuario (SÍ editar)
3. `.claude/skills/` - Skills del proyecto local

**El problema**:
```
.readme/skills/readme → apunta → ~/.claude-sneakpeek/zai/skills/readme
                         (INCORRECTO - dirección inversa)
```

**Lo correcto**:
```
~/.claude-sneakpeek/zai/config/skills/readme → apunta → .claude/skills/readme
                                            (CORRECTO - global → local)
```

## Análisis de Symlinks Actuales

### Symlinks en el Directorio Global

```bash
~/.claude-sneakpeek/zai/config/skills/
├── orchestrator → ~/GitHub/multi-agent-ralph-loop/.claude/skills/orchestrator ✅
├── gates → ~/GitHub/multi-agent-ralph-loop/.claude/skills/gates ✅
├── audit → ~/GitHub/multi-agent-ralph-loop/.claude/skills/audit ✅
├── bugs → ~/GitHub/multi-agent-ralph-loop/.claude/skills/bugs ✅
└── readme → (NO EXISTE) ❌
```

### Symlinks en el Proyecto

```bash
.claude/skills/
├── orchestrator/ (directorio real) ✅
├── gates/ (directorio real) ✅
├── readme → ~/.claude-sneakpeek/zai/skills/readme ❌ (DIRECCIÓN INVERSA)
└── compact → ~/.claude-sneakpeek/zai/skills/compact ❌ (fue eliminado)
```

## Patrón Correcto

### Para Skills del Proyecto

```
┌─────────────────────────────────────────────────────────────┐
│  Proyecto: ~/GitHub/multi-agent-ralph-loop/              │
│                                                             │
│  .claude/skills/                                           │
│  ├── orchestrator/         ← Skill real                    │
│  │   └── skill.md                                        │
│  ├── gates/               ← Skill real                    │
│  │   └── skill.md                                        │
│  └── readme/              ← Skill real                    │
│      └── skill.md                                        │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Global: ~/.claude-sneakpeek/zai/config/skills/            │
│                                                             │
│  ├── orchestrator → ../GitHub/multi-agent-ralph-loop/.../orchestrator
│  ├── gates → ../GitHub/multi-agent-ralph-loop/.../gates
│  └── readme → ../GitHub/multi-agent-ralph-loop/.../readme  ← FALTA
└─────────────────────────────────────────────────────────────┘
```

### Para Skills de Zai

Si quieres usar un skill de Zai directamente, crea un symlink en el proyecto:

```bash
.claude/skills/zai-readme → ~/.claude-sneakpeek/zai/skills/readme
```

Y luego en global:
```bash
~/.claude-sneakpeek/zai/config/skills/zai-readme → ../GitHub/.../zai-readme
```

## Solución Paso a Paso

### Paso 1: Verificar si el skill `readme` existe en el proyecto

```bash
ls -la .claude/skills/readme/
```

**Resultado esperado**:
- Si existe: Debería ser un directorio con `skill.md`
- Si es un symlink: Están apuntando al revés (INCORRECTO)

### Paso 2: Crear el skill `readme` en el proyecto

Si NO existe o está mal configurado:

```bash
# Opción A: Copiar desde Zai
cp -r ~/.claude-sneakpeek/zai/skills/readme .claude/skills/

# Opción B: Crear symlink local (si quieres usar el de Zai)
ln -s ~/.claude-sneakpeek/zai/skills/readme .claude/skills/zai-readme
```

### Paso 3: Crear el symlink global

```bash
cd ~/.claude-sneakpeek/zai/config/skills/
ln -s /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills/readme readme
```

### Paso 4: Verificar

```bash
# Verificar symlink global
ls -la ~/.claude-sneakpeek/zai/config/skills/readme

# Verificar que apunta al proyecto
readlink ~/.claude-sneakpeek/zai/config/skills/readme
# Debe mostrar: /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills/readme

# Verificar que el skill existe
cat ~/.claude-sneakpeek/zai/config/skills/readme/skill.md | head -10
```

## Script de Solución Automática

```bash
#!/bin/bash
# fix-skills-global.sh - Fix skill symlinks for global availability

set -euo pipefail

PROJECT_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
GLOBAL_SKILLS_DIR="${HOME}/.claude-sneakpeek/zai/config/skills"
PROJECT_SKILLS_DIR="${PROJECT_DIR}/.claude/skills"

# Skills que deben estar disponibles globalmente
SKILLS=(
    "orchestrator"
    "gates"
    "readme"
    "audit"
    "bugs"
    "clarify"
    "loop"
    "parallel"
    "security"
    "testing-anti-patterns"
)

echo "=== Fixing Skill Symlinks for Global Availability ==="
echo ""

for skill in "${SKILLS[@]}"; do
    SYMLINK="${GLOBAL_SKILLS_DIR}/${skill}"
    TARGET="${PROJECT_SKILLS_DIR}/${skill}"

    # Verificar si el skill existe en el proyecto
    if [ ! -d "$TARGET" ]; then
        echo "⚠️  WARNING: ${skill} does not exist in project"
        echo "   Expected: ${TARGET}"
        continue
    fi

    # Eliminar symlink si ya existe
    if [ -L "$SYMLINK" ]; then
        echo "✅ Removing existing symlink: ${skill}"
        rm "$SYMLINK"
    fi

    # Crear nuevo symlink
    echo "🔗 Creating symlink: ${skill}"
    ln -s "$TARGET" "$SYMLINK"

    # Verificar
    if [ -L "$SYMLINK" ]; then
        echo "   ✅ Success: ${skill} now available globally"
    else
        echo "   ❌ Error: Failed to create symlink for ${skill}"
    fi
    echo ""
done

echo "=== Verification ==="
echo ""
echo "Global skills symlinks:"
ls -la "$GLOBAL_SKILLS_DIR" | grep -E "orchestrator|gates|readme|audit|bugs"
echo ""
echo "All done! Skills should now be available globally."
```

## Verificación de Skills Disponibles

### Para verificar qué skills están disponibles globalmente:

```bash
# Listar todos los symlinks en el directorio global
ls -la ~/.claude-sneakpeek/zai/config/skills/

# Verificar un skill específico
ls -la ~/.claude-sneakpeek/zai/config/skills/readme
```

### Para verificar qué skills están disponibles en el proyecto actual:

```bash
# Listar skills del proyecto
ls -la .claude/skills/

# Verificar si un skill es symlink o directorio real
cd .claude/skills && ls -la | grep readme
```

## Resumen de la Arquitectura Correcta

```
┌──────────────────────────────────────────────────────────────────┐
│                     ARQUITECTURA CORRECTA                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Skills del Proyecto (Código fuente)                         │
│     ~/GitHub/multi-agent-ralph-loop/.claude/skills/             │
│     ├── orchestrator/skill.md  ← Archivo real                   │
│     ├── gates/skill.md         ← Archivo real                   │
│     └── readme/skill.md        ← Archivo real                   │
│                                                                  │
│  2. Symlinks Globales (Referencias)                             │
│     ~/.claude-sneakpeek/zai/config/skills/                      │
│     ├── orchestrator → symlink hacia ~/GitHub/.../orchestrator  │
│     ├── gates → symlink hacia ~/GitHub/.../gates                │
│     └── readme → symlink hacia ~/GitHub/.../readme              │
│                                                                  │
│  3. Skills de Zai (Integrados, NO editar)                      │
│     ~/.claude-sneakpeek/zai/skills/                             │
│     └── readme/ (skill integrado de Zai)                        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Recomendaciones

### 1. Mantener Skills en el Proyecto

Todos los skills de multi-agent-ralph-loop deben:
- Estar en `.claude/skills/<nombre>/`
- Tener un archivo `skill.md`
- Ser código fuente (NO symlinks)

### 2. Crear Symlinks Globales

Para cada skill que quieras disponible globalmente:
- Crear symlink en `~/.claude-sneakpeek/zai/config/skills/<nombre>`
- Apuntar al skill del proyecto
- NO crear symlinks dentro del proyecto que apunten a Zai

### 3. Validar Regularmente

```bash
# Ejecutar después de cambios
./fix-skills-global.sh

# O verificar manualmente
ls -la ~/.claude-sneakpeek/zai/config/skills/ | grep "^l"
```

## Troubleshooting

### Problem: `/readme` no funciona

**Symptom**: El comando `/readme` no está disponible.

**Diagnosis**:
```bash
# Verificar si el symlink global existe
ls -la ~/.claude-sneakpeek/zai/config/skills/readme

# Verificar si apunta al proyecto
readlink ~/.claude-sneakpeek/zai/config/skills/readme
```

**Solution**:
```bash
cd ~/.claude-sneakpeek/zai/config/skills/
ln -s /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills/readme readme
```

### Problem: Symlinks apuntan en dirección incorrecta

**Symptom**: Los symlinks dentro del proyecto apuntan a Zai.

**Diagnosis**:
```bash
cd .claude/skills/
readlink readme
# Muestra: ~/.claude-sneakpeek/zai/skills/readme (INCORRECTO)
```

**Solution**:
```bash
# Eliminar symlink incorrecto
rm .claude/skills/readme

# Copiar skill desde Zai (o crear uno propio)
cp -r ~/.claude-sneakpeek/zai/skills/readme .claude/skills/

# Crear symlink global
ln -s /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills/readme \
      ~/.claude-sneakpeek/zai/config/skills/readme
```

## Referencias

- **Global Skills Dir**: `~/.claude-sneakpeek/zai/config/skills/`
- **Project Skills Dir**: `.claude/skills/`
- **Zai Skills Dir**: `~/.claude-sneakpeek/zai/skills/`
- **Related**: `CLAUDE.md` - Project structure and organization

---

**Status**: READY FOR IMPLEMENTATION
**Priority**: HIGH - Skills should be available globally
**Next Steps**: Run fix-skills-global.sh to correct all symlinks
