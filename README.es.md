# Multi-Agent Ralph Loop

![Versión](https://img.shields.io/badge/version-3.0.0-blue)
![Licencia](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)

Framework de orquestación autónoma para Claude Code con memoria inspirada en MemPalace, Agent Teams y puertas de calidad.

> **Nota**: la documentación principal del repositorio está en INGLÉS. Este README en español es una traducción de [`README.md`](./README.md), que es la fuente de verdad. Para contribuir o consultar detalles técnicos, consulta los documentos en inglés.

## Qué Hace

Ralph extiende Claude Code hasta convertirlo en un framework de desarrollo multi-agente con un sistema de memoria estructurado, inspirado en la [técnica del palacio de la memoria](https://es.wikipedia.org/wiki/Reglas_mnemot%C3%A9cnicas). Cada tarea se analiza desde primeros principios, se descompone en subtareas enfocadas, se asigna a compañeros de equipo especializados y se valida mediante puertas de calidad antes de darse por terminada.

| Capacidad | Descripción |
|---|---|
| **Memoria MemPalace** | Pila de memoria de 4 capas (L0-L3) con grafo de conocimiento en Obsidian y reglas graduadas |
| **6 Compañeros de Equipo** | ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher, ralph-frontend, ralph-security |
| **Sistema de Hooks** | Hooks de ciclo de vida para validación, puertas de calidad, guardias de seguridad y aprendizaje automático |
| **Aristotle (skill opt-in)** | Deconstrucción en 5 fases vía /aristotle para trabajo ambiguo o de alto impacto — retirado de la cadena por defecto por #69 Fase 3 |
| **Puertas de Calidad** | Validación bloqueante en 4 etapas: corrección, calidad, seguridad, consistencia |
| **Tests Exhaustivos** | Suite completa que cubre capas, hooks, seguridad, skills y pipeline |

## Sistema de Memoria MemPalace

Inspirado en el [repositorio MemPalace](https://github.com/tcsenpai/mempalace) (técnica del palacio de la memoria para agentes LLM), Ralph implementa una arquitectura de memoria en capas, con diferencias clave derivadas de los hallazgos de nuestra implementación.

### Pila de Capas (Despertar de Sesión)

| Capa | Fichero | Propósito |
|------|---------|-----------|
| L0 | `~/.ralph/layers/L0_identity.md` | Identidad y principios del agente |
| L1 | `~/.ralph/layers/L1_essential.md` | Reglas accionables (filtradas del corpus) |
| L2 | `.claude/learned-src/learned/*.md` | Reglas graduadas del proyecto, un fichero plano por dominio (bajo demanda) |
| L3 | Grep sobre el vault de Obsidian | Consultas a la base de conocimiento completa (bajo demanda) |

### Hallazgos Clave de la Implementación

Estos hallazgos surgieron durante nuestra implementación de MemPalace y pueden ser relevantes para quien construya sistemas de memoria para LLM:

| Hallazgo | Detalle |
|----------|---------|
| **Codificar no reduce tokens** | La codificación en el área de uso privado de Unicode aumentó los tokens BPE. Las métricas por conteo de palabras reportaban una reducción falsa. |
| **Seleccionar gana a codificar** | Elegir menos reglas alcanzó el objetivo; comprimir las mismas reglas no. |
| **La taxonomía necesita filtrado de ruido** | El 46% de las reglas auto-aprendidas era ruido (repeticiones entre dominios, agregados vagos). Filtrar es imprescindible. |

Análisis completo: [AAAK_LIMITATIONS_ADR](docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md)

### Pipeline de Aprendizaje (Automático)

```
SESIÓN (cualquier repo)
  |
  +-- Stop         --> (aprendizaje automático eliminado por #69 Slice D; las escrituras son explícitas)
  +-- PostToolUse  --> extractores semánticos --> hechos y decisiones al vault
  +-- SessionStart --> (graduación automática eliminada por #69 Slice D)
  +-- SessionEnd   --> (indexado automático eliminado por #69 Slice D)
```

Todo el aprendizaje fluye proyecto -> global -> vault. Solo los patrones universales gradúan al ámbito global.

## Inicio Rápido

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Validar la infraestructura global
bash scripts/validate-global-infrastructure.sh

# Ejecutar los tests
python3 -m pytest tests/ -q

# Usar
/orchestrator "Crear un endpoint de API REST"
/iterate "Arreglar todos los errores de lint"
/security src/
```

## Agent Teams

6 compañeros de equipo especializados para ejecución en paralelo:

| Compañero | Rol | Herramientas |
|---|---|---|
| `ralph-coder` | Implementación | Read, Edit, Write, Bash |
| `ralph-reviewer` | Revisión de código (OWASP) | Read, Grep, Glob |
| `ralph-tester` | Testing | Read, Edit, Write, Bash(test) |
| `ralph-researcher` | Investigación (búsqueda web) | Read, Grep, Glob, WebSearch |
| `ralph-frontend` | Frontend (WCAG 2.1 AA) | LSP, Read, Edit, Write, Bash |
| `ralph-security` | Seguridad (6 pilares) | LSP, Read, Grep, Glob, Bash |

Agent Teams se habilita con `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` en settings.json. Los compañeros pueden ser lanzados por las skills orchestrator, iterate, parallel, security y task-batch cuando la tarea lo justifica.

## Skills Principales

| Skill | Propósito |
|---|---|
| `/orchestrator` | Flujo completo: evaluar, clarificar, clasificar, planificar, ejecutar, validar, retrospectiva |
| `/iterate` | Ejecución iterativa hasta VERIFIED_DONE |
| `/parallel` | Ejecutar varias tareas independientes en paralelo |
| `/task-batch` | Ejecución autónoma por lotes a partir de ficheros PRD |
| `/gates` | Validación de puertas de calidad multi-lenguaje |
| `/security` | Auditoría de seguridad multi-agente (OWASP, semgrep, gitleaks) |
| `/autoresearch` | Bucle de experimentación autónoma con Smart Setup |
| `/adversarial` | Refinamiento de especificación con validación cruzada |
| `/bugs` | Búsqueda sistemática de bugs |
| `/ship` | Checklist de pre-lanzamiento (gates + seguridad + revisión) |
| `/spec` | Especificación técnica verificable antes de programar |

## Flujo de Orquestación

`/orchestrator` ejecuta los pasos 0 a 8. El paso 0 clasifica la tarea en tres dimensiones y la enruta; el paso 6 es un bucle anidado que corre una vez por cada paso del plan.

```
0. EVALUAR    -> Primeros principios (Aristotle) + clasificación en 3 dimensiones
1. CLARIFICAR -> AskUserQuestion (MUST_HAVE bloqueante, NICE_TO_HAVE opcional)
2. CLASIFICAR -> task-classifier (complejidad 1-10)
3. PLANEAR    -> Diseño detallado
4. MODO PLAN  -> EnterPlanMode, el usuario aprueba
5. DELEGAR    -> Asignar a compañeros (por aislamiento y paralelismo, nunca por modelo)
6. EJECUTAR-CON-SINCRONIZACIÓN, por cada paso del plan:
   6a. LSA-VERIFY  -> pre-chequeo de arquitectura
   6b. IMPLEMENTAR -> ejecutar el paso
   6c. PLAN-SYNC   -> detectar desviación respecto al plan
   6d. MICRO-GATE  -> calidad por paso (regla de 3 intentos)
7. VALIDAR    -> quality-auditor, /gates, validación cruzada adversarial de spec y plan
8. RETROSPECTIVA -> auto-mejora
```

### Clasificación en 3 Dimensiones

El paso 0 clasifica antes de planificar, y los tres valores juntos eligen la ruta:

| Dimensión | Valores | Propósito |
|---|---|---|
| Complejidad | 1-10 | Alcance, riesgo, ambigüedad |
| Densidad de Información | CONSTANT / LINEAR / QUADRATIC | Cómo escala la respuesta |
| Requisito de Contexto | FITS / CHUNKED / RECURSIVE | Necesidad de descomposición |

CONSTANT + FITS + complejidad 1-3 toma una ruta rápida de 3 pasos; QUADRATIC descompone recursivamente; LINEAR + CHUNKED se ejecuta en fragmentos paralelos.

### El Ralph Loop

`/iterate` repite ejecutar -> validar -> iterar hasta que las puertas de calidad pasan (`VERIFIED_DONE`) o se agota el presupuesto acotado de iteraciones (`max_iterations`, 15 por defecto). Un bucle sin límite no tiene señal de fallo, así que todo bucle fija uno.

## Comandos Esenciales

```bash
# Orquestación
/orchestrator "Implementar OAuth2 con Google"
ralph orch "tarea"                 # Orquestación completa
ralph loop "arreglar los lint"     # Bucle hasta VERIFIED_DONE
/clarify                           # Clarificación intensiva de requisitos

# Calidad
/gates                             # Puertas de calidad
/adversarial                       # Refinamiento de especificación

# Memoria
ralph memory-search "consulta"     # Búsqueda de memoria en paralelo
ralph fork-suggest "tarea"         # Sugerir sesiones fork

# Seguridad
ralph security src/                # Auditoría de seguridad
ralph security-loop src/           # Auditoría iterativa hasta quedar limpio

# Git worktree
ralph worktree "característica"    # Crear un worktree aislado
ralph worktree-pr <branch>         # PR con revisión

# Contexto
ralph ledger save                  # Guardar el estado de la sesión
ralph handoff create               # Crear un handoff
```

## Observabilidad Local

Observabilidad sin dependencias externas, respaldada por ficheros locales:

```bash
ralph plan status     # Estado actual del plan (lee .claude/plan-state.json)
ralph trace show      # Eventos recientes
ralph trace search    # Buscar eventos
ralph trace timeline  # Línea de tiempo visual
ralph trace export    # Exportar a JSON/CSV
```

| Fuente | Propósito |
|---|---|
| `.claude/plan-state.json` | Estado de orquestación actual |
| `~/.ralph/events/event-log.jsonl` | Historial del bus de eventos |
| `~/.ralph/checkpoints/` | Snapshots de checkpoints |
| `~/.ralph/agent-memory/` | Buffers de memoria por agente |

## Puertas de Calidad

Validación en 4 etapas, todas bloqueantes salvo consistencia:

1. **CORRECCIÓN** -- Sintaxis válida, lógica sólida
2. **CALIDAD** -- Tipos, sin artefactos de depuración
3. **SEGURIDAD** -- semgrep + gitleaks + validación OWASP
4. **CONSISTENCIA** -- Linting y estilo (consultivo)

La aplicación mediante hooks sobre el evento `TaskCompleted` garantiza que ningún agente termine sin pasar las puertas.

## Arquitectura (post-M2)

El repositorio tiene 84 hooks en `.claude/hooks/`. Tras la retirada M2 (T106), se agrupan en cuatro categorías según su **registro por defecto**, no según la existencia del fichero: seguridad siempre activa, canónico #47 activo, hooks retirados a opt-in, y hooks de ruta fría de sesión/planificador.

![Diagrama de arquitectura — cuatro categorías post-M2](docs/assets/mmx-post-m2-architecture.svg)

Fuente de verdad: [`results/T107-inventario.md`](results/T107-inventario.md). Cada fila del inventario apunta a un fichero real del repositorio; si un enlace de origen se rompe, la fila se borra.

### Las Categorías de un Vistazo

| Categoría | Registro por defecto | Forma | Por qué sobrevive (o se retira) |
|---|---|---|---|
| **SEGURIDAD** (siempre activa) | 6 hooks en `PreToolUse` + 1 librería incluida | permission-pipeline, git-safety, repo-boundary, k8s-context, skill-security, worktree-utils | Sobrevive a M2 incondicionalmente. El contrato de fallo abierto / fallo cerrado se verifica de extremo a extremo en `tests/security/SECURITY_BASELINE.json` y lo reproducen las fixtures de regresión. |
| **CANÓNICO #47** (activo) | Escritor y lectores de plan-state, recall bajo demanda, task-state, guardias T101, escritores de estado de subagente | La respuesta a "qué cosa útil y verificada aprendimos, dónde está, y cómo la obtengo sin pagar el coste en cada prompt". Recuperación acotada, escrituras atómicas, recorrido exacto de la cadena. | Sigue activo porque la respuesta canónica a #47 es "recall dirigido por demanda sobre un corpus acotado", no "cargar el vault entero en cada turno". |
| **OPT-IN** (retirado del registro por defecto) | 17 hooks sobreviven solo como opt-in vía `/nombreskill` (aristotle, learning, lifecycle, status, quality-parallel, progress, display, extract-moved) | M2 los quitó de la cadena por defecto de `~/.claude/settings.json`. El usuario los invoca con `/aristotle`, `/format`, `/audit`, etc. | Retirados porque el coste por prompt nunca vino acompañado de evidencia de beneficio material para el caso por defecto. El hook sobrevive en disco para invocación explícita. |
| **RUTA FRÍA** (sesión/planificador) | extractores, dream, consolidación, migración del vault, checkpoint | Corre en `SessionStart` (una vez) / `SessionEnd` / `PostToolUse` (con debounce) — nunca en eventos por prompt. | Se queda porque compactar, consolidar y migrar estado es trabajo asíncrono por naturaleza; ese coste nunca debe aparecer en la ruta caliente por prompt. |

### Por Qué Importa

La cadena de despertar SessionStart/PreToolUse anterior a M2 registraba ~50 hooks; después de M2 registra ~12 (los 6 de SEGURIDAD + ~5 CANÓNICO + el mínimo del ciclo de vida de sesión). Los ~70 restantes pasan a opt-in (invocados por el usuario) o a ruta fría (fin de sesión). El coste por prompt baja de "se disparan todos los hooks" a "se disparan los 12 que importan". La lección arquitectónica es la que T107 deja en el historial de commits: **la arquitectura correcta suele quitar cosas, no añadirlas**.

## Seguridad

El framework incluye varias capas de aplicación de seguridad:

| Capa | Disparador | Propósito |
|---|---|---|
| `git-safety-guard.py` | PreToolUse (Bash) | Bloquea operaciones git destructivas y encadenamiento de comandos |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Impide operaciones fuera del repositorio actual |
| `read-size-guard.sh` | PreToolUse (Read) | Deniega la lectura sin acotar de un fichero de más de 250 líneas; exige `offset`/`limit` |
| `audit-secrets.js` | PostToolUse | Registro de auditoría para más de 20 patrones de secretos |
| `task-completed-quality-gate.sh` | TaskCompleted | Validación multi-puerta antes de completar una tarea |
| `task-plan-sync.sh` | TaskCreated | Sincroniza la creación de tareas con plan-state.json |

## Optimización de Contexto

Ralph usa symlinks (no copias) para todas las reglas, skills y agentes globales. Esto elimina la duplicación de contenido y reduce la sobrecarga de contexto en ~29% (~10K tokens ahorrados por sesión).

```bash
# Sincronizar reglas del repo a global (crea symlinks)
bash scripts/sync-rules.sh

# Previsualizar cambios sin ejecutarlos
bash scripts/sync-rules.sh --dry-run
```

Política de distribución: consulta `docs/architecture/DISTRIBUTION_POLICY.md` para la estrategia symlink vs copia por tipo de componente (Reglas=COPIA, Hooks=COPIA, Agentes=SYMLINK, Skills=MIXTO).

## Requisitos

| Herramienta | Versión | Requerida |
|---|---|---|
| Claude Code | v2.1.42+ | Sí |
| Bash | 4.0+ | Sí |
| jq | 1.6+ | Sí |
| git | 2.0+ | Sí |
| python3 | 3.8+ | Sí (para los tests) |
| Obsidian | Cualquiera | Opcional (para el grafo del vault) |
| GitHub CLI | Cualquiera | Opcional |
| semgrep | Cualquiera | Opcional (seguridad) |
| gitleaks | Cualquiera | Opcional (secretos) |

## Tests

```bash
python3 -m pytest tests/ -q                     # Suite completa
bash scripts/validate-global-infrastructure.sh  # Chequeos de infraestructura
```

## Política de Modelo

El sistema es **agnóstico de modelo** y de proveedor. El modelo es el que ejecuta la sesión: el usuario lo elige con `/model` o nombrándolo expresamente, y los subagentes lo heredan. Nada en este repositorio selecciona, recomienda, enruta ni fija un modelo o proveedor por defecto.

Los umbrales de complejidad disparan **proceso**, nunca un cambio de modelo -- por ejemplo, Plan Mode a partir de complejidad 4. La delegación a subagentes se hace por aislamiento y paralelismo, no por coste.

Las herramientas externas son opt-in y se invocan **solo por nombre explícito** (las skills `codex-cli`, `gemini-cli` y `openai-docs`, y el agente `codex-reviewer`). Ninguna es una ruta por defecto ni un fallback automático.

## Configuración

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Las skills se enlazan por symlink a varios directorios de plataforma. Fuente de verdad: `.claude/skills/` en este repositorio.

## Infraestructura Global

Todas las ventajas de Ralph (Plan Mode, Agent Teams) funcionan en **cualquier proyecto**: reglas, skills y agentes se enlazan globalmente.

```bash
# Validar la infraestructura global
bash scripts/validate-global-infrastructure.sh

# Auto-reparar symlinks rotos
bash scripts/validate-global-infrastructure.sh --fix
```

## Autoresearch

Bucle de experimentación autónoma inspirado en [karpathy/autoresearch](https://github.com/karpathy/autoresearch). Modifica código continuamente, mide métricas y conserva solo las mejoras.

**Smart Setup** reduce la configuración de más de 14 parámetros manuales a 2-3 preguntas guiadas:

| Fase | Nombre | Qué hace |
|---|---|---|
| 0 | **SCOUT** | Autodetección silenciosa del tipo de proyecto, scripts y métricas |
| 1 | **WIZARD** | 2-3 AskUserQuestion con opciones precargadas y vista previa |
| 2 | **VALIDATE** | Verificación en seco (la evaluación funciona, la métrica se extrae, git limpio) |

9 plantillas de dominio: entrenamiento ML, tests de Node.js, tamaño de bundle, tests de Python, ingeniería de prompts, SQL, Rust, Lighthouse y personalizada.

```bash
/autoresearch "optimiza mis tests"    # Modo smart (autodetección)
/autoresearch --manual                # Configuración clásica
```

## Documentación

| Tema | Ubicación |
|---|---|
| Arquitectura | `docs/architecture/` |
| ADR de limitaciones AAAK | `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md` |
| Anti-racionalización | `docs/reference/anti-rationalization.md` |
| Metodología Aristotle | `docs/reference/aristotle-first-principles.md` |
| Seguridad | `docs/security/` |
| Referencia de hooks | `docs/hooks/` |
| Benchmarks | `docs/benchmark/` |
| Ejecución por lotes | `docs/batch-execution/` |

## Agradecimientos

- **[MemPalace](https://github.com/tcsenpai/mempalace)** -- Investigación original sobre la técnica del palacio de la memoria para agentes LLM, que inspiró nuestra arquitectura de memoria en capas. Nuestra implementación diverge en aspectos clave documentados en [AAAK_LIMITATIONS_ADR](docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md).
- **[Claude Code](https://code.claude.com)** -- Plataforma base de orquestación con APIs de hooks, skills y Agent Teams.
- **[karpathy/autoresearch](https://github.com/karpathy/autoresearch)** -- Inspiración para el bucle de experimentación autónoma.

## Licencia

Business Source License 1.1 - consulta el fichero LICENSE.

## Referencias

- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
