# Multi-Agent-Ralph

![Version](https://img.shields.io/badge/version-2.49.1-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)

> "Me fail English? That's unpossible!" - Ralph Wiggum

---

## Overview

**Multi-Agent-Ralph** es un sistema de orquestacion sofisticado para Claude Code y OpenCode que coordina multiples modelos de IA para entregar codigo validado de alta calidad mediante ciclos de refinacion iterativa.

El sistema aborda el desafio fundamental de la programacion asistida por IA: **asegurar calidad y consistencia en tareas complejas**. En lugar de confiar en la salida de un solo modelo de IA, Ralph orquesta multiples agentes especializados trabajando en paralelo, con puertas de validacion automaticas y debates adversarials para requisitos rigurosos.

### Lo Que Hace

- **Orquesta Multiples Modelos de IA**: Coordina Claude (Opus/Sonnet), OpenAI Codex, Google Gemini, y MiniMax en flujos de trabajo paralelos
- **Refinacion Iterativa**: Implementa el patron "Ralph Loop" - ejecutar, validar, iterar hasta que las puertas de calidad pasen
- **Assurance de Calidad**: Puertas de calidad en 9 lenguajes (TypeScript, Python, Go, Rust, Solidity, Swift, JSON, YAML, JavaScript)
- **Refinamiento Especificacion Adversarial**: Debate adversarial para endurecer especificaciones antes de la ejecucion
- **Preservacion Contexto Automatica**: Sistema 100% automatico ledger/handoff preserva estado de sesion (v2.35)
- **Auto-Mejoramiento**: Analisis retrospectivo despues de cada tarea para proponer mejoras de flujo de trabajo

### Por Que Usarlo

| Desafio | Solucion Ralph |
|---------|---------------|
| Salida de IA varia en calidad | Debate multi-modelo via adversarial-spec |
| Un solo paso frecuentemente insuficiente | Ciclos iterativos (15-60 iteraciones) hasta VERIFIED_DONE |
| Revision manual cuello de botella | Puertas de calidad automaticas + humano en decisiones criticas |
| Limites de contexto | MiniMax (1M tokens) + Context7 MCP para documentacion |
| Perdida de contexto en compactacion | Preservacion automatica ledger/handoff (85-90% reduccion tokens) |
| Costos API altos | Enrutamiento optimizado (WebSearch FREE, MiniMax 8%, Opus estrategico) |

---

## Arquitectura

### Diagrama General del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RALPH v2.49.1 COMPLETE ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    SESSION LIFECYCLE                                  │   │
│  │   [SessionStart]                                                     │   │
│  │       │                                                               │   │
│  │       ▼                                                               │   │
│  │   ┌──────────────────────────────────────────────────────────────┐   │   │
│  │   │           SMART MEMORY SEARCH (PARALLEL) v2.47                │   │   │
│  │   │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐    │   │   │
│  │   │  │claude-mem │ │  memvid   │ │ handoffs  │ │  ledgers  │    │   │   │
│  │   │  │  (MCP)    │ │  (HNSW)   │ │ (30 days) │ │CONTINUITY │    │   │   │
│  │   │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘    │   │   │
│  │   │        │ PARALLEL    │ PARALLEL    │ PARALLEL    │ PARALLEL  │   │   │
│  │   │        └─────────────┴─────────────┴─────────────┘           │   │   │
│  │   │                            │                                    │   │   │
│  │   │                            ▼                                    │   │   │
│  │   │                   ┌─────────────────┐                          │   │   │
│  │   │                   │   MEMORY CONTEXT │                          │   │   │
│  │   │                   └─────────────────┘                          │   │   │
│  │   └──────────────────────────────────────────────────────────────┘   │   │
│  │                                    │                                  │   │
│  │                                    ▼                                  │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │              ORCHESTRATOR WORKFLOW (12 Steps) v2.46             │  │   │
│  │  │                                                               │  │   │
│  │  │  0.EVALUATE ───► 1.CLARIFY ───► 2.CLASSIFY ───► 3.PLAN ───►   │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       │                │               │              ▼        │  │   │
│  │  │       │                │               │      ┌────────────┐   │  │   │
│  │  │       │                │               │      │   Claude   │   │  │   │
│  │  │       │                │               │      │    Code    │   │  │   │
│  │  │       │                │               │      │  Plan Mode │   │  │   │
│  │  │       │                │               │      └────────────┘   │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       ▼                ▼               ▼              ▼        │  │   │
│  │  │  ┌────────────────────────────────────────────────────────────────┐│  │   │
│  │  │  │              EXECUTE-WITH-SYNC (Nested Loop)                   ││  │   │
│  │  │  │  LSA-VERIFY ──► IMPLEMENT ──► PLAN-SYNC ──► MICRO-GATE        ││  │   │
│  │  │  └────────────────────────────────────────────────────────────────┘│  │   │
│  │  │                                    │                               │  │   │
│  │  │                                    ▼                               │  │   │
│  │  │  ┌───────────────────────────────────────────────────────────────┐│  │   │
│  │  │  │              VALIDATE (Multi-Stage)                           ││  │   │
│  │  │  │  CORRECTNESS ──► QUALITY ──► CONSISTENCY ──► ADVERSARIAL     ││  │   │
│  │  │  │       [BLOCKING]      [BLOCKING]     [ADVISORY]   [if >= 7]   ││  │   │
│  │  │  └───────────────────────────────────────────────────────────────┘│  │   │
│  │  │                                    │                               │  │   │
│  │  │                         ┌──────────┴──────────┐                    │  │   │
│  │  │                         │                     │                     │  │   │
│  │  │                         ▼                     ▼                     │  │   │
│  │  │                  ┌─────────────┐      ┌─────────────┐              │  │   │
│  │  │                  │ITERATE LOOP │      │ VERIFIED_   │              │  │   │
│  │  │                  │  (max 25)   │      │    DONE     │              │  │   │
│  │  │                  └─────────────┘      └─────────────┘              │  │   │
│  │  └────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                             │
│  └─────────────────────────────────────────────────────────────────────────────┘
```

> **Diagrama Completo**: Ver `ARCHITECTURE_DIAGRAM_v2.49.1.md` para todos los diagramas detallados (Memory Architecture, Hooks Registry, Tools Matrix, Security Pattern)

---

## Flujo de Trabajo Principal

### 1. El Patron Ralph Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH LOOP PATTERN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ EXECUTE  │───▶│   VALIDATE   │───▶│ Quality Passed? │      │
│   │   Task   │    │ (hooks/gates)│    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                          ┌────────────────┘         │          │
│                          ▼                          ▼          │
│                   ┌─────────────┐          ┌──────────────┐    │
│                   │  ITERATE    │          │ VERIFIED_DONE│    │
│                   │(max 25/50)  │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Flujo de Orquestacion Completo (12 Pasos)

```
0. EVALUATE    → Clasificacion rapida (trivial?)
1. CLARIFY     → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)
2. CLASSIFY    → task-classifier (complejidad 1-10)
3. PLAN        → Diseño detallado
4. PLAN MODE   → EnterPlanMode (lee analisis)
5. DELEGATE    → Enrutar al modelo optimo
6. EXECUTE-WITH-SYNC → Ciclo anidado por paso:
   6a. LSA-VERIFY  → Pre-check arquitectura
   6b. IMPLEMENT   → Ejecutar paso
   6c. PLAN-SYNC   → Detectar drift
   6d. MICRO-GATE  → Calidad por paso (regla 3-fix)
7. VALIDATE    → Validacion multi-etapa:
   7a. QUALITY-AUDITOR → Auditoria pragmatica
   7b. GATES → Puertas de calidad (9 lenguajes)
   7c. ADVERSARIAL-SPEC → Refinamiento especificacion
   7d. ADVERSARIAL-PLAN → Validacion cruzada Opus+Codex
8. RETROSPECT  → Auto-mejoramiento
```

---

## Caracteristicas Clave

### Orquestacion Multi-Agente

| Caracteristica | Descripcion |
|----------------|-------------|
| **14 Agentes Especializados** | 9 nucleo + 5 revision auxiliary |
| **12-Paso Workflow** | Evaluar → Clarificar → Planificar → Ejecutar → Validar |
| **Ejecucion Paralela** | Multiples agentes trabajan simultaneamente |
| **Enrutamiento Modelos** | Seleccion automatica: Opus (critico), Sonnet (estandar), MiniMax (extendido) |

**Agentes Nucleo (9)**:
`orchestrator`, `security-auditor`, `code-reviewer`, `test-architect`, `debugger`, `refactorer`, `docs-writer`, `frontend-reviewer`, `minimax-reviewer`

### Memoria Inteligente (v2.49)

```
SMART MEMORY SEARCH (PARALLEL)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │  ledgers │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
```

**Tres Tipos de Memoria**:
| Tipo | Proposito | Almacenamiento |
|------|-----------|----------------|
| **Semantica** | Hechos, preferencias | `~/.ralph/memory/semantic.json` |
| **Episodica** | Experiencias (TTL 30 dias) | `~/.ralph/episodes/` |
| **Procedural** | Comportamientos aprendidos | `~/.ralph/procedural/rules.json` |

### Validacion Calidad-Primero (v2.46)

```
Stage 1: CORRECTNESS  → Errores sintaxis (BLOQUEANTE)
Stage 2: QUALITY      → Errores tipos (BLOQUEANTE)
Stage 2.5: SECURITY   → semgrep + gitleaks (BLOQUEANTE)
Stage 3: CONSISTENCY  → Linting (CONSULTIVO - no bloqueante)
```

### Clasificacion 3-Dimension (RLM)

| Dimension | Valores |
|-----------|---------|
| **Complejidad** | 1-10 |
| **Densidad Informacion** | CONSTANT / LINEAR / QUADRATIC |
| **Requisito Contexto** | FITS / CHUNKED / RECURSIVE |

---

## Instalacion Rapida

```bash
# Clonar repositorio
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Instalar
chmod +x install.sh
./install.sh
source ~/.zshrc

# Verificar
ralph integrations
```

### Requisitos

| Herramienta | Requerida | Proposito |
|-------------|-----------|-----------|
| Claude CLI | Si | Orquestacion base |
| jq | Si | Procesamiento JSON |
| git | Si | Control de versiones |
| GitHub CLI | Para PRs | Creacion/revision PR |

---

## Comandos Esenciales

```bash
# Orquestacion
/orchestrator "Implementar OAuth2 con Google"
ralph orch "task"              # Orquestacion completa
ralph loop "fix errors"        # Loop hasta VERIFIED_DONE
/clarify                       # Clarificacion intensiva

# Calidad
/gates                         # Puertas de calidad
/adversarial                   # Refinamiento especificacion

# Memoria (v2.49)
ralph memory-search "query"    # Busqueda paralela
ralph fork-suggest "task"      # Sugerir sesiones

# Seguridad
ralph security src/            # Auditoria seguridad
ralph security-loop src/       # Auditoria iterativa

# Worktree Git
ralph worktree "feature"       # Crear worktree aislado
ralph worktree-pr <branch>     # PR con revision

# Contexto
ralph ledger save              # Guardar estado sesion
ralph handoff create           # Crear handoff
ralph compact                  # Guardado manual (extensiones)
```

---

## Arquitectura de Modelos

```
┌────────────────────────────────────────────────────────────┐
│  PRIMARY (Sonnet gestiona)  │  SECONDARY (8% costo)       │
├────────────────────────────┼───────────────────────────────┤
│  Claude Opus/Sonnet        │  MiniMax M2.1                │
│  Codex GPT-5               │  (Segunda opinion)           │
│  Gemini 2.5 Pro            │  (Validacion independiente)  │
├────────────────────────────┼───────────────────────────────┤
│  Implementacion            │  Validacion                  │
│  Testing                   │  Captar problemas perdidos   │
│  Documentacion             │  Calidad Opus al 8% costo    │
└────────────────────────────┴───────────────────────────────┘
```

### Optimizacion Costos

| Modelo | Max Iteraciones | Costo vs Claude | Caso Uso |
|--------|-----------------|-----------------|----------|
| Claude Opus | 25 | 100% | Revision critica, arquitectura |
| Claude Sonnet | 25 | 60% | Implementacion estandar |
| MiniMax M2.1 | 50 | 8% | Loops extendidos, segunda opinion |
| MiniMax-lightning | 100 | 4% | Tareas muy largas |

---

##Hooks (29 Registrados)

| Tipo Evento | Proposito |
|-------------|-----------|
| SessionStart | Preservacion contexto al inicio |
| PreCompact | Guardar estado antes de compactacion |
| PostToolUse | Puertas de calidad despues Edit/Write |
| PreToolUse | Guardias de seguridad antes Bash/Skill |
| UserPromptSubmit | Advertencias contexto, recordatorios |
| Stop | Reportes sesion |

---

## Documentacion Adicional

| Documento | Proposito |
|-----------|-----------|
| [`CHANGELOG.md`](./CHANGELOG.md) | **Historia completa de versiones** (mejores practicas) |
| [`ARCHITECTURE_DIAGRAM_v2.49.1.md`](./ARCHITECTURE_DIAGRAM_v2.49.1.md) | Diagramas completos arquitectura |
| [`CLAUDE.md`](./CLAUDE.md) | Referencia rapida (compacta) |
| `tests/HOOK_TESTING_PATTERNS.md` | Patrones testing hooks |

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
