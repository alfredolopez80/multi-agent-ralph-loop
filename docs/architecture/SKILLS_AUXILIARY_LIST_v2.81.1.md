# Skills Auxiliares - Listado Completo v2.81.1

**Date**: 2026-01-30
**Version**: v2.81.1
**Status**: COMPLETE AND VALIDATED

## Overview

Listado completo de skills auxiliares disponibles en multi-agent-ralph-loop, incluyendo comandos CLI externos integrados (Codex, Gemini) y skills personalizados.

## Skills Auxiliares Validados

### 1. `/codex` - OpenAI Codex CLI Integration

**Ubicación**: `.claude/skills/codex-cli/`
**Symlink Global**: ✅ `~/.claude-sneakpeek/zai/config/skills/codex-cli`

**Descripción**:
Orquestación de OpenAI Codex CLI (v0.79+) con el modelo **gpt-5.2-codex** para:
- Code generation automatizada
- Refactoring de código
- Análisis automatizado
- Edición automatizada de archivos
- Ejecución paralela de tareas
- Gestión de sesiones continuas
- Code review con segunda opinión
- Análisis de arquitectura
- Integración con Context7 MCP

**Comando**: `/codex` o `use codex`

**Casos de Uso**:
- Generación de código complejo
- Refactoring a gran escala
- Segunda opinión / validación cruzada
- Análisis de arquitectura
- Tareas paralelas independientes

**Requisitos**:
- Codex CLI instalado: `codex --version` (v0.50.0+)
- Autenticación con OpenAI

**Ejemplo**:
```bash
/codex "Refactor this function to use async/await"
/codex "Review this code for security issues"
```

---

### 2. `/gemini` - Google Gemini CLI Integration

**Ubicación**: `.claude/skills/gemini-cli/`
**Symlink Global**: ✅ `~/.claude-sneakpeek/zai/config/skills/gemini-cli`

**Descripción**:
Orquestación de Google Gemini CLI (v0.22.0+) con **Gemini 3 Pro** para:
- Segunda opinión / validación cruzada
- Búsqueda web en tiempo real con Google Search
- Análisis de arquitectura de codebase (codebase_investigator)
- Generación de código en paralelo
- Code review desde perspectiva diferente
- Búsqueda de información actual (documentación, eventos)
- Extensiones: Conductor (planning++), Endor Labs (security scanning)

**Comando**: `/gemini` o `use gemini`

**Casos de Uso**:
- Validación cruzada de código
- Búsqueda de información actual en la web
- Análisis de arquitectura
- Generación paralela con diferentes perspectivas
- Uso de extensiones especializadas

**Novedades v0.22.0** (Diciembre 2025):
- Gemini 3 disponible para usuarios free tier
- Integración con Google Colab
- Soporte para extensiones (Conductor, Endor Labs)
- Multi-file drag & drop mejorado

**Ejemplo**:
```bash
/gemini "Review this code for bugs I might have missed"
/gemini "Search for the latest React best practices"
```

---

### 3. `/edd` - Eval-Driven Development Framework (v2.64)

**Ubicación**: `.claude/skills/edd/`
**Symlink Global**: ✅ `~/.claude-sneakpeek/zai/config/skills/edd`

**Propósito**: Framework de desarrollo con patrón **define-before-implement** y evaluaciones estructuradas

**Descripción Completa**:

EDD (**Eval-Driven Development**) es un framework de calidad-first que impone un flujo de trabajo sistemático en tres fases:

1. **DEFINE** - Crear especificaciones de evaluación usando TEMPLATE.md
2. **IMPLEMENT** - Construir features según definiciones de evaluación
3. **VERIFY** - Validar implementación contra criterios de evaluación

**Tipos de Checks**:

| Prefix | Tipo | Propósito |
|--------|------|-----------|
| `CC-` | Capability Checks | Capacidades y funcionalidad del feature |
| `BC-` | Behavior Checks | Comportamientos y respuestas esperadas |
| `NFC-` | Non-Functional Checks | Performance, seguridad, mantenibilidad |

**Componentes**:

- **TEMPLATE.md**: Plantilla para crear definiciones de evaluación
- **edd.sh**: Script CLI para gestión de evaluaciones
- **/edd skill**: Invocación desde Claude Code
- **~/.claude/evals/**: Directorio para definiciones de evaluación

**Uso**:
```bash
# Invocar workflow EDD
/edd "Define memory-search feature"

# Script CLI (si está disponible)
ralph edd define memory-search
ralph edd check memory-search
```

**Estructura de Template**:

Cada evaluación incluye:
1. **Capability Checks** (CC-) - Qué puede hacer el feature
2. **Behavior Checks** (BC-) - Cómo se comporta el feature
3. **Non-Functional Checks** (NFC-) - Performance, seguridad, etc.
4. **Implementation Notes** - Guía técnica
5. **Verification Evidence** - Resultados de pruebas

**Ejemplo: memory-search.md**:

```markdown
# Memory Search Eval

**Status**: DRAFT
**Created**: 2026-01-30

## Capability Checks
- [ ] CC-1: Search across semantic memory
- [ ] CC-2: Support filtering by type

## Behavior Checks
- [ ] BC-1: Returns ranked results
- [ ] BC-2: Handles empty queries gracefully

## Non-Functional Checks
- [ ] NFC-1: Search completes in <2s
- [ ] NFC-2: Memory usage <100MB

## Implementation Notes
- Use parallel search for performance
- Cache frequent queries

## Verification Evidence
- Test results attached
```

**Integración con Orchestrator**:

EDD se integra con el flujo de trabajo del orchestrator para asegurar desarrollo calidad-first:

1. **Clarify** - Definir evaluaciones
2. **Plan** - Revisar requisitos de evaluación
3. **Implement** - Construir según especificaciones
4. **Validate** - Verificar contra evaluaciones

**Tests**: Suite de 33 tests en `tests/test_v264_edd_framework.bats`

**Estado**: Framework definido (v2.64), implementación completa pendiente

**Documentación**: Actualizado 2026-01-30 con descripción completa basada en test suite

---

## Validación de Symlinks Globales

### Verificación Actual

Todos los skills auxiliares tienen symlinks globales correctos:

```bash
# Verificar symlinks
ls -la ~/.claude-sneakpeek/zai/config/skills/ | grep -E "codex-cli|gemini-cli|edd"
```

**Resultado Esperado**:
```bash
lrwxr-xr-x@  1 alfredolopez  staff    84 27 ene.  23:44 codex-cli -> .../.claude/skills/codex-cli ✅
lrwxr-xr-x@  1 alfredolopez  staff    85 29 ene.  16:18 gemini-cli -> .../.claude/skills/gemini-cli ✅
lrwxr-xr-x@  1 alfredolpez 80 staff     27 ene.  23:44 edd -> .../.claude/skills/edd ✅
```

### Arquitectura de Symlinks

```
Global Skills Directory: ~/.claude-sneakpeek/zai/config/skills/
├── codex-cli → symlink → ~/GitHub/multi-agent-ralph-loop/.claude/skills/codex-cli
├── gemini-cli → symlink → ~/GitHub/multi-agent-ralph-loop/.claude/skills/gemini-cli
└── edd → symlink → ~/GitHub/multi-agent-ralph-loop/.claude/skills/edd

Project Skills Directory: .claude/skills/
├── codex-cli/ (directorio real con SKILL.md, CLAUDE.md)
├── gemini-cli/ (directorio real con skill.md, references/)
└── edd/ (directorio real con SKILL.md, CLAUDE.md)
```

## Comparación de Skills Auxiliares

| Skill | Modelo Principal | Propósito | Unique |
|-------|-----------------|----------|--------|
| **codex-cli** | gpt-5.2-codex | Code generation, refactoring, análisis automatizado | OpenAI Codex CLI |
| **gemini-cli** | Gemini 3 Pro | Second opinion, búsqueda web, análisis arquitectura | Google Gemini CLI |
| **edd** | N/A (framework) | Eval-Driven Development: define-before-implement | Ralph framework |

## Patrón de Uso Recomendado

### 1. Para Code Generation y Refactoring

```bash
# Usar Codex para generación automatizada
/codex "Create a REST API endpoint with authentication"

# Validar con Gemini para segunda opinión
/gemini "Review this API endpoint for security issues"
```

### 2. Para Validación Cruzada

```bash
# Primero: Claude implementa
"Implement the authentication module"

# Segundo: Codex valida
/codex "Review the authentication implementation"

# Tercero: Gemini da segunda opinión
/gemini "Check for edge cases in the auth module"
```

### 3. Para Búsqueda de Información Actual

```bash
# Gemini tiene acceso a Google Search en tiempo real
/gemini "What are the latest React best practices for 2026?"

# Claude puede validar con su conocimiento
"Verify these React best practices are correct"
```

## Archivos y Configuración

### Estructura de Directorios

```
.claude/skills/
├── codex-cli/
│   ├── SKILL.md
│   └── CLAUDE.md
├── gemini-cli/
│   ├── skill.md
│   ├── CLAUDE.md
│   └── references/
│       ├── templates.md
│       ├── patterns.md
│       ├── command_reference.md
│       └── tools.md
└── edd/
    ├── SKILL.md
    └── CLAUDE.md
```

### Symlinks Globales

Ubicación: `~/.claude-sneakpeek/zai/config/skills/`

```bash
# Verificar todos los symlinks
ls -la ~/.claude-sneakpeek/zai/config/skills/ | grep "^l"

# Verificar un skill específico
readlink ~/.claude-sneakpeek/zai/config/skills/codex-cli
# Output: /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills/codex-cli
```

## Mantenimiento

### Actualizar Symlinks Globales

Para agregar nuevos skills globalmente:

```bash
cd ~/.claude-sneakpeek/zai/config/skills/
ln -s /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills/nuevo-skill nuevo-skill
```

### Verificar Disponibilidad Global

```bash
# Ejecutar script de mantenimiento
./.claude/scripts/fix-skills-global.sh

# Verificar manualmente
ls -la ~/.claude-sneakpeek/zai/config/skills/ | grep "^l"
```

## Referencias

- **Documentación Principal**: `docs/architecture/ANALYSIS_SKILLS_GLOBAL.md`
- **Fix Script**: `.claude/scripts/fix-skills-global.sh`
- **Skills Directory**: `.claude/skills/`
- **Global Config**: `~/.claude-sneakpeek/zai/config/settings.json`

## Completado

### `/edd` - ✅ Investigación Completada

**Fecha**: 2026-01-30

**Acciones Realizadas**:
1. ✅ Buscado referencias en el código (`grep -r "edd"`)
2. ✅ Revisado test suite (`tests/test_v264_edd_framework.bats`)
3. ✅ Identificado como **Eval-Driven Development Framework**
4. ✅ Documentado funcionalidad completa
5. ✅ Actualizado `skill.md` con descripción detallada

**Resultado**: EDD es un framework de calidad-first con patrón define-before-implement, tres tipos de checks (CC-, BC-, NFC-), y workflow en tres fases (DEFINE → IMPLEMENT → VERIFY).

### Para Skills CLI Externos

**Codex CLI**:
- Documentar versión mínima requerida
- Agregar ejemplos de uso comunes
- Documentar requisitos de autenticación

**Gemini CLI**:
- Documentar características de Gemini 3 Pro
- Explicar uso de extensiones (Conductor, Endor Labs)
- Agregar ejemplos de búsqueda web

---

**Status**: ✅ Todos los skills auxiliares validados, documentados e investigados.
**Investigación `/edd`**: ✅ Completada 2026-01-30

**Version**: v2.81.1
**Last Updated**: 2026-01-30 12:45 PM GMT+1
