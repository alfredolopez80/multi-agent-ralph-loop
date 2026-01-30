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

### 3. `/edd` - Custom Skill (Investigación Pendiente)

**Ubicación**: `.claude/skills/edd/`
**Symlink Global**: ✅ `~/.claude-sneakpeek/zai/config/skills/edd`

**Descripción Actual**:
```yaml
name: edd
description: Custom skill for edd
```

**Estado**: ⚠️ INVESTIGACIÓN PENDIENTE

**Análisis Preliminar**:
- Skill personalizado/customizado
- Descripción minimalista en skill.md
- Sin documentación extensa en CLAUDE.md
- Posible skill especializado del proyecto

**Requiere**: Investigación adicional para determinar propósito exacto.

**Acciones Sugeridas**:
1. Buscar referencias a "edd" en el código
2. Revisar comandos o scripts relacionados
3. Documentar su funcionalidad

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

| Skill | Modelo Principal | Propósito | Unic |
|-------|-----------------|----------|-------|
| **codex-cli** | gpt-5.2-codex | Code generation, refactoring, análisis automatizado | OpenAI Codex CLI |
| **gemini-cli** | Gemini 3 Pro | Second opinion, búsqueda web, análisis arquitectura | Google Gemini CLI |
| **edd** | ¿Pendiente? | Custom skill (investigación pendiente) | Ralph personalizado |

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

## Próximos Pasos

### Para `/edd` (Investigación Pendiente)

1. **Buscar referencias en el código**:
   ```bash
   grep -r "edd" .claude/ --include="*.md" --include="*.sh"
   ```

2. **Revisar comandos y scripts**:
   ```bash
   ls -la .claude/commands/ | grep -i edd
   ls -la .claude/scripts/ | grep -i edd
   ```

3. **Documentar funcionalidad**: Una vez identificado, actualizar SKILL.md con descripción completa.

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

**Status**: Skills auxiliares validados y documentados.
**Próxima Actualización**: Investigar y documentar `/edd` completamente.

**Version**: v2.81.1
**Last Updated**: 2026-01-30
