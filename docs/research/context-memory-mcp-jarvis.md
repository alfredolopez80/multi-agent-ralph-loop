# Contexto, Memoria y Cerebro del Agente via MCP
## Análisis: "Obsidian + Claude Code = JARVIS Personal" — @cyrilXBT

> **Fuente**: Tweet https://x.com/cyrilXBT/status/2034282316411879917
> **Video**: 58:57 min | 18 Mar 2026 | 364K vistas | Basado en curso @gregisenberg
> **Doc técnico**: Personal AI Employee Hackathon 0 — @panaversity_ / @ziakhan
> **Propósito de este doc**: Extraer patrones para construir contexto/memoria via MCP en Claude o cualquier agente

---

## 1. El Problema Central que Resuelve

> *"El combo Markdown + Claude Code funciona porque resuelve el **problema de persistencia de contexto** que la mayoría de setups de agentes ignora. El sentimiento de 'JARVIS' viene de la **continuidad**, no del modelo en sí."*
> — @Navam_io (reply)

Los LLMs son **stateless por naturaleza** — cada sesión empieza desde cero. El sistema Obsidian + Claude Code resuelve esto convirtiendo el filesystem local en una capa de memoria persistente y estructurada.

### El problema en términos técnicos:

```
Sin memoria persistente:
  Sesión 1: "Construye X" → Claude trabaja → sesión termina → todo olvidado
  Sesión 2: Claude no sabe nada de X

Con memoria persistente (vault Obsidian):
  Sesión 1: "Construye X" → Claude trabaja → escribe progreso en vault → sesión termina
  Sesión 2: Claude lee vault → sabe exactamente dónde estaba → continúa
```

---

## 2. Arquitectura: Percepción → Memoria → Razonamiento → Acción

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERSONAL AI EMPLOYEE / JARVIS                │
├──────────────────┬──────────────────────────────────────────────┤
│  PERCEPCIÓN      │  Python Watchers (Gmail, WhatsApp, FS)       │
│  MEMORIA/GUI     │  Obsidian Vault (Markdown local)             │
│  CEREBRO         │  Claude Code (razonamiento + planificación)  │
│  MANOS           │  MCP Servers (email, browser, pagos)         │
│  PERSISTENCIA    │  Ralph Wiggum Loop (Stop hook)               │
└──────────────────┴──────────────────────────────────────────────┘
```

### Analogía con el cerebro humano:

| Componente | Analogía Humana | Implementación Técnica |
|-----------|-----------------|------------------------|
| Memoria de trabajo | RAM / contexto activo | Window de contexto del LLM |
| Memoria episódica | Recuerdos de eventos | `/Episodes/YYYY-MM-DD.md` |
| Memoria semántica | Conocimiento general | `Company_Handbook.md`, `CLAUDE.md` |
| Memoria procedimental | Habilidades automáticas | `SKILL.md` / comandos custom |
| Memoria declarativa | Hechos y datos | `Business_Goals.md`, `Dashboard.md` |

---

## 3. El Vault como MCP Filesystem — Estructura Completa

El vault de Obsidian es esencialmente un **MCP filesystem server** con estructura semántica impuesta por el diseñador del sistema.

### Estructura del vault recomendada:

```
/AI_Employee_Vault/
│
├── 📊 DASHBOARD (Memoria de trabajo actual)
│   ├── Dashboard.md          ← Estado en tiempo real
│   └── Company_Handbook.md   ← "Reglas de Engagement" / CLAUDE.md del agente
│
├── 📥 INBOX (Percepción — creado por Watchers)
│   └── Needs_Action/
│       ├── EMAIL_<id>.md
│       ├── WHATSAPP_<id>.md
│       └── FILE_<nombre>.md
│
├── 🧠 PLANES (Razonamiento activo)
│   ├── Plans/
│   │   └── PLAN_<tarea>_<fecha>.md
│   └── In_Progress/<agente>/   ← claim-by-move para evitar doble trabajo
│
├── 🔐 APROBACIONES (Human-in-the-Loop)
│   ├── Pending_Approval/
│   ├── Approved/
│   └── Rejected/
│
├── ✅ COMPLETADO
│   └── Done/
│
├── 📈 OBJETIVOS (Memoria a largo plazo)
│   ├── Business_Goals.md
│   └── Briefings/YYYY-MM-DD_Monday_Briefing.md
│
├── 💰 DATOS FINANCIEROS
│   └── Accounting/Current_Month.md
│
└── 📋 AUDIT TRAIL
    └── Logs/YYYY-MM-DD.json   ← retener 90 días mínimo
```

### Schemas clave de archivos:

#### `Dashboard.md` — Estado en tiempo real
```markdown
---
last_updated: 2026-03-20T22:00:00Z
agent_version: 1.0
---

## Estado Actual
- Balance banco: $X,XXX
- Mensajes pendientes: 3
- Proyectos activos: 2

## Actividad Reciente
- [2026-03-20 10:45] Factura enviada a Cliente A ($1,500)
- [2026-03-19 09:00] Suscripción Notion marcada para cancelación
```

#### `Company_Handbook.md` — Reglas de Engagement
```markdown
# Reglas del Agente

## Comunicación
- Siempre ser cortés en WhatsApp
- Nunca enviar a contactos nuevos sin HITL

## Pagos
- Auto-aprobar pagos recurrentes < $50
- SIEMPRE HITL para pagos > $100 o destinatarios nuevos

## Estilo
- Idioma: Español en WhatsApp, Inglés en email formal
- Tono: Profesional pero accesible
```

#### `Needs_Action/EMAIL_<id>.md` — Item de acción
```markdown
---
type: email
from: cliente@ejemplo.com
subject: Solicitud de propuesta
received: 2026-03-20T10:30:00Z
priority: high
status: pending
---

## Contenido
[snippet del email]

## Acciones Sugeridas
- [ ] Responder con propuesta
- [ ] Crear tarea de seguimiento
```

---

## 4. Patrones de Memoria para Cualquier Agente via MCP

### Patrón 1: MCP Filesystem como Memoria Persistente

**Principio**: El MCP filesystem server built-in de Claude Code ya es suficiente para implementar memoria persistente. No se necesita una base de datos.

```python
# Configuración MCP para acceso al vault
{
  "servers": {
    "memory-vault": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/vault"]
    }
  }
}
```

**Cómo el agente lee su contexto al inicio de cada sesión:**
```
1. Lee Dashboard.md → estado actual del sistema
2. Lee Company_Handbook.md → sus reglas y personalidad
3. Lee Business_Goals.md → objetivos activos
4. Lista Needs_Action/ → tareas pendientes
5. Lista In_Progress/<self>/ → trabajo propio en curso
→ Agente ya tiene contexto completo sin que el humano explique nada
```

### Patrón 2: Comandos de Contexto (Front-loading)

Un solo comando carga todo el contexto relevante instantáneamente:

```bash
# Ejemplo de comando custom en CLAUDE.md
/morning-briefing:
  - Lee Dashboard.md
  - Lista Needs_Action/ con timestamps
  - Lee últimas 3 entradas de Logs/
  - Lee Business_Goals.md → métricas actuales
  → Output: resumen ejecutivo + lista de tareas priorizadas
```

### Patrón 3: Memoria Episódica — Daily Notes

```markdown
# /Daily/2026-03-20.md

## Reflexiones del día
- Completé propuesta para Cliente B (más rápido de lo esperado)
- Cyril mencionó que la integración con Notion podría ser útil

## Ideas generadas
- Automatizar el envío de facturas cada primer día del mes
- Conectar LinkedIn para publicar automáticamente

## Personas relevantes
- @clienteB — muy receptivo a propuestas detalladas
- @contadorX — necesita CSV en formato específico
```

La IA usa estas notas para generar ideas personalizadas, recomendar herramientas, y sugerir conexiones relevantes.

### Patrón 4: Memoria Procedimental — SKILL.md

Cada habilidad del agente se define como un archivo `.md`:

```markdown
# /Skills/enviar-factura/SKILL.md

## Cuándo usar
Cuando detectas una solicitud de factura en Needs_Action/

## Pasos
1. Busca datos del cliente en /Clients/<nombre>.md
2. Calcula monto según /Accounting/Rates.md
3. Genera factura PDF via invoice-mcp
4. Crea /Pending_Approval/EMAIL_factura_<id>.md
5. Espera a que humano mueva a /Approved/
6. Envía via email-mcp
7. Registra en /Logs/ y actualiza Dashboard.md

## Errores comunes
- Si cliente no existe → crear /Clients/nuevo.md primero
- Si monto > $1000 → SIEMPRE requiere HITL extra
```

### Patrón 5: Knowledge Graph via Backlinks de Obsidian

```markdown
# /Clients/ClienteA.md
---
tags: [cliente, activo, facturación-mensual]
---

Relacionado con: [[Proyecto Alpha]], [[Factura 2026-01]], [[Contrato-2025]]

## Historial
- 2026-01-07: Factura $1,500 enviada y pagada en 2 días
- 2025-12-01: Primer contrato firmado
```

Claude Code + Obsidian CLI puede **navegar estos backlinks** para entender contexto relacional que un simple RAG perdería.

---

## 5. El Loop de Persistencia — "Ralph Wiggum" Pattern

> El hackathon referencia explícitamente el **"Ralph Wiggum pattern"** — un Stop hook que intercepta la salida de Claude y re-inyecta el prompt hasta que la tarea esté completa.

Este es el mismo patrón implementado en este repositorio como `/iterate` y los hooks `SubagentStop`/`TeammateIdle`.

### Cómo funciona:

```
┌─────────────────────────────────────────────────────┐
│              RALPH WIGGUM LOOP                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Orchestrator crea: /Plans/TASK_<id>.md             │
│         ↓                                           │
│  Claude trabaja en la tarea                         │
│         ↓                                           │
│  Claude intenta salir (Stop event)                  │
│         ↓                                           │
│  Stop Hook intercepta → verifica:                   │
│  ┌─ ¿Archivo en /Done/? ─────────────────────┐      │
│  │  SÍ → Permitir salida ✅                  │      │
│  │  NO → Bloquear salida (exit 2)            │      │
│  │       Re-inyectar prompt                  │      │
│  │       Loop continúa ↺                    │      │
│  └───────────────────────────────────────────┘      │
│                                                     │
│  Máximo: max_iterations (default: 10)               │
└─────────────────────────────────────────────────────┘
```

### Dos estrategias de completion:

```bash
# 1. Promise-based (simple)
# Claude emite en su output:
<promise>TASK_COMPLETE</promise>

# 2. File movement (avanzado — más robusto)
# El completion es parte natural del workflow:
# /Needs_Action/task.md → /In_Progress/claude/ → /Done/
# El Stop hook detecta el movimiento a /Done/
```

---

## 6. Capa de Percepción — Los Watchers

Scripts Python daemon que alimentan el vault con acciones:

### Patrón base (todos los Watchers):

```python
class BaseWatcher(ABC):
    def __init__(self, vault_path: str, check_interval: int = 60):
        self.vault_path = Path(vault_path)
        self.needs_action = self.vault_path / 'Needs_Action'
        self.check_interval = check_interval

    @abstractmethod
    def check_for_updates(self) -> list: ...

    @abstractmethod
    def create_action_file(self, item) -> Path: ...

    def run(self):
        while True:
            try:
                for item in self.check_for_updates():
                    self.create_action_file(item)
            except Exception as e:
                self.logger.error(f'Error: {e}')
            time.sleep(self.check_interval)
```

### Watchers implementados:

| Watcher | Check interval | Fuente | Filtro |
|---------|---------------|--------|--------|
| `GmailWatcher` | 120s | Gmail API | `is:unread is:important` |
| `WhatsAppWatcher` | 30s | Playwright (WhatsApp Web) | keywords: urgent, invoice, payment |
| `FilesystemWatcher` | evento | watchdog (local FS) | drop folder → Needs_Action |
| `FinanceWatcher` | config | Banking APIs / CSV | nuevas transacciones |

### Gestión de procesos (no usar `python watcher.py` crudo):

```bash
# PM2 para mantener Watchers vivos
npm install -g pm2
pm2 start gmail_watcher.py --interpreter python3
pm2 start whatsapp_watcher.py --interpreter python3
pm2 save       # persiste lista
pm2 startup    # arranca en reboot
```

---

## 7. Human-in-the-Loop (HITL) — Seguridad por Diseño

### Patrón de aprobación vía filesystem:

```markdown
# /Pending_Approval/PAYMENT_ClienteA_2026-03-20.md
---
type: approval_request
action: payment
amount: 500.00
recipient: Cliente A
reason: Factura #1234
created: 2026-03-20T10:30:00Z
expires: 2026-03-21T10:30:00Z
status: pending
---

## Para Aprobar → mover a /Approved/
## Para Rechazar → mover a /Rejected/
```

### Matriz de permisos:

| Acción | Auto-aprobar | Siempre HITL |
|--------|-------------|--------------|
| Emails | A contactos conocidos | Nuevos contactos, bulk |
| **Pagos** | < $50 recurrentes | **Todo nuevo, > $100** |
| Redes sociales | Posts programados | Replies, DMs |
| Archivos | Crear, leer | Borrar, mover fuera vault |

---

## 8. Feature Estrella: Monday Morning CEO Briefing

Tarea programada cada domingo por la noche — demuestra el agente **proactivo** (no reactivo):

```python
# cron: 0 20 * * 0  (domingo 8pm)
# Trigger: python orchestrator.py --task weekly-briefing

# Claude ejecuta:
# 1. Lee Business_Goals.md → objetivos y métricas Q actual
# 2. Lista Done/ de la semana → tareas completadas
# 3. Lee Accounting/Current_Month.md → transacciones
# 4. Detecta patrones: suscripciones sin uso, bottlenecks
# 5. Genera /Briefings/YYYY-MM-DD_Monday_Briefing.md
```

```markdown
# Output generado:
# /Vault/Briefings/2026-03-17_Monday_Briefing.md

## Monday Morning CEO Briefing

### Resumen Ejecutivo
Semana fuerte. Ingresos 15% sobre objetivo. Un bottleneck.

### Ingresos
- Esta semana: $2,450 | MTD: $4,500 (45% de $10,000)

### Bottlenecks
| Tarea | Esperado | Real | Retraso |
|-------|----------|------|---------|
| Propuesta Cliente B | 2 días | 5 días | +3 días |

### Sugerencias Proactivas
- **Notion**: Sin actividad 45 días ($15/mes) → /Pending_Approval/
- **Project Alpha**: Deadline en 9 días — ¿necesitas ayuda?
```

---

## 9. Flujo End-to-End: Factura por WhatsApp

Ejemplo completo de percepción → memoria → razonamiento → acción:

```
[WhatsApp] "¿Puedes enviarme la factura de enero?"
         ↓
[WhatsAppWatcher @ 30s] detecta keyword "factura/invoice"
Creates: /Needs_Action/WHATSAPP_clienteA_20260320.md
         ↓
[Orchestrator.py] detecta archivo nuevo → llama Claude Code
Claude lee: /Needs_Action/WHATSAPP_clienteA_20260320.md
Claude lee: /Clients/ClienteA.md (contexto del cliente)
Claude lee: /Accounting/Rates.md (tarifas)
Claude crea: /Plans/PLAN_factura_clienteA.md (con checkboxes)
         ↓
[Claude solicita HITL para acción sensible]
Creates: /Pending_Approval/EMAIL_factura_clienteA.md
         ↓
[Humano revisa en Obsidian → mueve a /Approved/]
         ↓
[Orchestrator detecta /Approved/]
Llama: email_mcp.send_email(to=clienteA, attachment=factura.pdf)
         ↓
[Claude actualiza Dashboard.md]
Mueve: todos los archivos de la tarea → /Done/
Logs: /Logs/2026-03-20.json
```

---

## 10. Seguridad y Privacidad

### Reglas de credenciales:
```bash
# NUNCA en el vault de Obsidian
# SIEMPRE en variables de entorno

# .env (nunca en git — añadir a .gitignore)
GMAIL_CLIENT_ID=xxx
GMAIL_CLIENT_SECRET=xxx
BANK_API_TOKEN=xxx
WHATSAPP_SESSION_PATH=/secure/path/session

# Para producción: usar macOS Keychain / 1Password CLI
```

### Dry-run por defecto en desarrollo:
```python
DRY_RUN = os.getenv('DRY_RUN', 'true').lower() == 'true'

def send_email(to, subject, body):
    if DRY_RUN:
        logger.info(f'[DRY RUN] Enviaría email a {to}: {subject}')
        return
    # Lógica real aquí
```

### Audit log obligatorio:
```json
{
  "timestamp": "2026-03-20T10:30:00Z",
  "action_type": "email_send",
  "actor": "claude_code",
  "target": "cliente@ejemplo.com",
  "approval_status": "approved",
  "approved_by": "human",
  "result": "success"
}
```

---

## 11. Conexión con multi-agent-ralph-loop

El hackathon de Panaversity referencia explícitamente el patrón "Ralph Wiggum" de **este repositorio**. La arquitectura es prácticamente idéntica:

| Concepto del Hackathon | Equivalente en este Repo |
|-----------------------|--------------------------|
| Ralph Wiggum Stop hook | `/iterate` skill + hooks `Stop`/`TeammateIdle` |
| Obsidian vault (memoria) | `.claude/agents/*.md` + `.claude/skills/*.md` |
| `Company_Handbook.md` | `CLAUDE.md` / `.claude/rules/` |
| `Plan.md` con checkboxes | `.claude/plans/` + skill `/create-task-batch` |
| Agentes especializados | `ralph-coder`, `ralph-reviewer`, `ralph-tester` |
| `Orchestrator.py` | `.claude/agents/orchestrator.md` + hooks |
| CEO Briefing semanal | Posible extensión de `/autoresearch` |
| Watchers (Gmail/WhatsApp) | Extensión futura con MCP sentinels |

### Gaps a cubrir para implementar el sistema completo:

1. **MCP Obsidian** — conectar un vault real de Obsidian como memoria externa
2. **Watchers** — scripts Python para Gmail, WhatsApp, filesystem
3. **Orchestrator.py** — proceso Python que orquesta el ciclo Watcher → Claude
4. **PM2** — gestión de procesos para mantener Watchers vivos 24/7
5. **CEO Briefing** — skill `/weekly-briefing` que genera el informe ejecutivo

---

## 12. Tiers de Implementación (Hackathon @panaversity_)

| Tier | Tiempo | Qué construir |
|------|--------|---------------|
| 🥉 Bronze | 8–12 hrs | Vault + 1 Watcher + Claude leyendo/escribiendo MD |
| 🥈 Silver | 20–30 hrs | 2+ Watchers + Plan.md auto + 1 MCP + HITL + cron |
| 🥇 Gold | 40+ hrs | Integración cruzada + Odoo ERP + CEO Briefing + Ralph loop |
| 💎 Platinum | 60+ hrs | Cloud 24/7 + Cloud/Local split + A2A + Odoo en cloud |

---

## 13. Transcripción del Video — Análisis Completo

> ✅ **Transcripción completada** con Whisper `tiny.en` (audio 58:57 min, @cyrilXBT tweet)
> **Formato real**: Podcast de **Greg Eisenberg** entrevistando a **"Vin" (Internet Vin)** — el experto real del sistema.

### Estructura real del video (podcast-demo, no tutorial)

- **Host**: Greg Eisenberg (`@gregisenberg`)
- **Invitado**: "Vin" / Internet Vin — creador y practicante real del sistema
- **Formato**: Demostración en vivo con el vault real de Vin

---

### Sección 1: El Problema Central — El contexto es todo

> *"It's the context right — yes, the whole game is feeding the beast good context."*

El problema: pasas 1 hora explicando un proyecto al agente → abres nueva sesión → todo olvidado. La memoria web de Claude no es controlable. Necesitas pasar información de forma explícita, controlable y rápida.

---

### Sección 2: Obsidian — No es una carpeta, es un vault

- Colección de archivos Markdown **interconectados** via backlinks bidireccionales
- Graph view: visualización de todas las relaciones entre archivos
- La diferencia vs. carpeta: puede ver que "hoy grabé con Greg Eisenberg" → `[[Greg Eisenberg]]` → ese archivo tiene sus propias conexiones
- "Funciona más como el cerebro humano — conecta patrones todo el tiempo"

---

### Sección 3: Obsidian CLI — El puente clave

```
Sin CLI:  Claude Code lee archivos .md (solo texto)
Con CLI:  Claude Code lee archivos .md + INTERRELACIONES entre ellos
```

> *"It can surface patterns about what you're thinking that you are not seeing for yourself. Some idea you might have been writing about for a year — it can immediately say: 'Hey, did you know you've been writing about this same pattern across different domains?'"*

---

### Sección 4: Los 12 Comandos Custom de Vin (demos en vivo)

Creados por Vin, ejecutados desde terminal embebida en Obsidian:

| Comando | Función | Qué lee |
|---------|---------|---------|
| `/context` | Carga contexto completo vida/trabajo | Context files, daily notes, backlinks |
| `/today` | Morning review + plan priorizado | Calendario, tasks, iMessages, semana de daily notes |
| `/close-day` | Fin de día: acciones + connections | Daily notes del día, confidence markers |
| `/ghost` | Responde como Vin respondería | Voice profile del vault |
| `/challenge` | Presiona creencias con historia del vault | Contradicciones y cambios de pensamiento |
| `/emerge` | Superficie ideas latentes nunca declaradas | Premises dispersas → conclusiones |
| `/drift` | Intenciones declaradas vs comportamiento real | 30-60 días de daily notes |
| `/ideas` | Generación cross-domain con graph analysis | Deep scan 30 días |
| `/trace` | Evolución de una idea en el tiempo | Todos los archivos relacionados |
| `/connect` | Conecta dos dominios via link graph | Puentes entre áreas distintas |
| `/schedule` | Scheduling consciente del contexto personal | Daily notes + calendario + prefs |
| `/graduate` | Extrae ideas de daily notes → standalone notes | Recientes + cross-reference vault |

**Cómo se crean:**
> *"You can create them very easily by just asking Claude Code to create a specific command."*
Vin empezó creándolos manualmente, luego le preguntó al agente: *"¿Qué comandos serían interesantes basándote en lo que lees en mi vault?"*

---

### Sección 5: Demo /trace — Lo más impresionante

**Input:** `/trace` — "¿cómo ha evolucionado mi relación con Obsidian?"

**Output generado leyendo el vault completo:**
```
Primera aparición: 11 ene 2025 — Span: 13 meses

FASE 1 Pre-vault (dic 2024): Sin Obsidian
  Audio dumps via Mac Whisperer, LLM loops, Canopia para spatial mapping.

FASE 2 Discovery + escepticismo (ene-may 2025):
  "El bi-directional linking no es tan útil — no sé todavía."

FASE 3 Chosen tool:
  "Realizar: no es útil backlink a términos generales (podcast, fitness).
  Lo importante: crear notas para cada patrón/teoría/proyecto y linkearlos."

FASE 4 Enero 2026 — Building explosivo:
  "Todo aún requiere que yo prompt activamente.
  Next unlock: hacer que los agentes corran automáticamente.
  La fricción ya no es Obsidian — es el boundary entre vault y agent execution."
```

> *"This is something I would never be able to do on my own. To read all these files, know how they're interconnected — not possible for me as a human being."*

---

### Sección 6: Demo /ideas — De reflexión a acción

Output del agente al correr `/ideas` sobre el vault:

```
TOOLS TO BUILD:
  - /graduate command: daily note idea extractor
  - Central vault compartido para el equipo (team shared context)

SYSTEMS TO IMPLEMENT:
  - "One sentence in Obsidian → agent handles the rest"
    (inline delegation como nuevo UX pattern)

CONVERSATIONS TO HAVE (personas reales sugeridas por el agente):
  - Obsidian CEO — sobre "the vault as a place"
  - Aaron (stadium workshop host) sobre programming

TOP 5 HIGH IMPACT DO NOW:
  - Build the /graduate command
  - Set up team vault for New (media company)
```

> *"It's suggesting people I should meet. This is crazy, dude."*

---

### Sección 7: La Regla Más Importante — El Agente NO escribe en el vault

```
SEPARACIÓN ESTRICTA:
✅ Agente PUEDE: leer vault, sugerir, generar output FUERA del vault
❌ Agente NO PUEDE: crear/editar archivos dentro del vault

Razón de Vin: "Cuando el agente encuentra patrones, ¿está encontrando
patrones en cosas que ÉL escribió o en cosas que YO escribí?"
```

> *"I want to control all the files because I always want it to pull from what I think about things — not what it thinks about things."*

---

### Sección 8: El Cambio de Paradigma — Gestionar el vault, no el agente

```
Paradigma viejo:  Humano → gestiona/prompt al agente → agente actúa
Paradigma nuevo:  Humano → gestiona el VAULT → agente lee vault → agente actúa
```

> *"Instead of managing an agent, I just focus on managing this vault. This is the new source. If it's not making the right decisions, I'm changing something in the vault — not working with the agent specifically."*

---

### Sección 9: Citas Clave del Video

> *"If you are not using a centralized note-taking tool that uses Markdown as the foundation — you are not using LLMs properly."*

> *"A file is essentially a perfect memory. The markdown file is perfect — not biased by recall."*

> *"Markdown files are the memories. Tokens are not the oxygen — markdown files are the oxygen."*

> *"If I'm OpenAI or Anthropic, I'm buying Obsidian. It's the missing link."*

> *"Writing right now is a big way of how you delegate things to agents. Develop a writing habit → you have more context to delegate → more things you can build."*

> *"The quality of information the agent has entirely determines what it can do for you."*

---

## 15. Aislamiento de Conocimiento — Seguridad del Vault Global

> **Problema**: Compartir patrones y antipatrones entre proyectos es valioso, pero si el vault global recibe información sensible del proyecto, se convierte en un vector de fuga de datos.

### El Principio Fundamental

El vault **global** solo debe contener conocimiento que puedas publicar en un README de GitHub sin revelar nada del proyecto, cliente, o negocio.

```
Prueba del aislamiento:
  ¿Puedo copiar este texto a un README público sin revelar
  el proyecto / cliente / arquitectura sensible?
    SI → Verde ✅ → vault global
    NO, pero es útil para el repo → Amarillo ⚠️ → vault local
    NO bajo ninguna forma → Rojo ❌ → descartar
```

---

### Modelo de Clasificación: GREEN / YELLOW / RED

```
┌──────────┬──────────────────────────────────────────────────────────┐
│ COLOR    │ DESTINO / REGLA                                          │
├──────────┼──────────────────────────────────────────────────────────┤
│ GREEN    │ Vault GLOBAL — ~/Obsidian/MiVault/Patterns/             │
│          │ Compartible entre todos los repos                        │
├──────────┼──────────────────────────────────────────────────────────┤
│ YELLOW   │ Vault LOCAL — .claude/vault/decisions/ (dentro del repo) │
│          │ Específico del proyecto, no sale de aquí                 │
├──────────┼──────────────────────────────────────────────────────────┤
│ RED      │ NUNCA persiste — descartado al cerrar sesión             │
│          │ Sensible o comprometedor bajo cualquier forma            │
└──────────┴──────────────────────────────────────────────────────────┘
```

---

### GREEN — Vault Global (`~/Obsidian/MiVault/Patterns/`)

Conocimiento **independiente del proyecto** — aplicable a repos futuros:

| Categoría | Ejemplos concretos |
|-----------|-------------------|
| Patrones técnicos validados | "TypeScript: never trust `as` casts en boundaries de API" |
| Antipatrones confirmados | "Claude asume que `npm test` siempre existe — verificar primero" |
| Errores comunes del LLM | "Claude usa `any` en TypeScript cuando está inseguro del tipo" |
| Comportamiento de herramientas | "Whisper falla con audio-only MP4 — necesita video stream" |
| Soluciones de debugging | "ModuleNotFoundError en Whisper → venv, no reinstall system" |
| Preferencias de workflow | "Usuario prefiere confirmación antes de git push" |
| Decisiones genéricas | "Venv isolation para Python evita conflictos con PEP 668" |

### YELLOW — Vault Local (`.claude/vault/decisions/` dentro del repo)

Conocimiento **específico de este proyecto**:

| Categoría | Ejemplos concretos |
|-----------|-------------------|
| Decisiones arquitectónicas del repo | "Usamos glm-4.7 para complejidad 1-4 en este sistema" |
| Estructura específica del proyecto | "Los hooks van en `.claude/hooks/`, no en `scripts/`" |
| Configuraciones locales | "Este repo usa symlinks a 6 directorios de plataformas" |
| Convenciones acordadas | "Versioning semver, commits en conventional commits" |
| Lessons learned del proyecto | "El hook curator-suggestion expone secrets con echo" |

### RED — Nunca persiste

| Categoría | Ejemplos | Razón |
|-----------|----------|-------|
| Credenciales / API keys | `OPENAI_API_KEY=sk-...`, tokens | Exposición directa |
| Nombres de clientes / empresas | "El proyecto para CompañíaX tiene bug..." | PII / NDA |
| Lógica de negocio sensible | Algoritmos de pricing, márgenes, estrategia | Ventaja competitiva |
| Datos de infraestructura | IPs internas, hostnames, ARNs AWS | Attack surface |
| Bugs de seguridad activos | "La validación en `/api/auth` tiene bypass" | Antes de parchear |
| Datos personales | Emails, teléfonos, contratos | GDPR / privacidad |

---

### Reglas de Detección Automática

Claude aplica estas reglas para **pre-clasificar** antes del diálogo de revisión:

```
REGLAS DE AUTO-CLASIFICACIÓN:
────────────────────────────────────────────────────────────
RED (auto-descarta, nunca aparece en el diálogo):
  - Contiene: API_KEY, SECRET, TOKEN, PASSWORD, BEARER
  - Contiene: nombres propios de empresas o clientes
  - Contiene: IPs, hostnames, ARNs, URLs privadas internas
  - Contiene: email addresses, números de teléfono
  - Describe: un bug de seguridad NO resuelto

YELLOW → puede escalar a GREEN si usuario confirma:
  - Menciona nombre del repo o proyecto actual
  - Incluye configuración de herramienta específica
  - Contiene rutas absolutas del sistema de archivos del usuario

GREEN (propone guardar, usuario confirma):
  - Patrón técnico observable sin contexto de proyecto
  - Error de herramienta con solución reproducible verificada
  - Comportamiento del LLM documentado con pasos para reproducir
  - Preferencia de workflow explícita del usuario
```

---

### Integración con el Diálogo de Revisión de Sesión (/exit)

Al cerrar sesión, Claude presenta cada aprendizaje ya pre-clasificado:

```
╔════════════════════════════════════════════════════════════════╗
║  REVISION DE SESION — Aprendizajes para el Vault              ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  1. GREEN [GLOBAL] "Whisper falla con audio-only MP4s —       ║
║        requiere video stream para procesar con Zai"           ║
║     Destino: ~/Obsidian/Patterns/Tools/whisper.md             ║
║     Confirmar? [S/n]                                          ║
║                                                                ║
║  2. GREEN [GLOBAL] "Python PEP 668 bloquea pip en sistema —   ║
║        siempre usar venv aislado para instalar herramientas"  ║
║     Destino: ~/Obsidian/Patterns/Python/pip-isolation.md      ║
║     Confirmar? [S/n]                                          ║
║                                                                ║
║  3. YELLOW [LOCAL:ralph-loop] "Output de autoresearch skill   ║
║        movido de docs/prd a .claude/plans — decisión v2.95"   ║
║     Destino: .claude/vault/decisions/2026-03-21.md            ║
║     Guardar localmente? [S/n]                                 ║
║                                                                ║
║  4. RED [DESCARTADO AUTO] API key detectada en contexto       ║
║     No persistido. OK                                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

---

### La Regla de Sanitización para GREEN

Un aprendizaje GREEN **nunca debe mencionar el proyecto**. Ejemplo de transformación:

```
ENTRADA (contexto del proyecto — no publicable):
  "En ralph-loop, cuando usamos glm-4.7 con el hook
   curator-suggestion.sh, el echo expone el API_KEY al log"

SANITIZADO para vault global (GREEN):
  "En scripts de hook de Claude Code, evitar `echo $VAR`
   cuando $VAR puede contener secrets. Usar redacción
   explícita o eliminación de la variable antes del log."
```

La sanitización elimina: nombres de repos, rutas absolutas, configuraciones específicas, referencias a personas, referencias a clientes.

---

### Estructura de Archivos del Vault Global

```
~/Documents/Obsidian/MiVault/
├── Patterns/
│   ├── Tools/
│   │   ├── whisper.md            ← errores + soluciones Whisper
│   │   ├── ffmpeg.md             ← patrones ffmpeg
│   │   └── claude-code.md        ← comportamientos del LLM
│   ├── Python/
│   │   ├── pip-isolation.md      ← PEP 668, venv patterns
│   │   └── async-patterns.md
│   ├── TypeScript/
│   │   └── type-safety.md
│   └── Git/
│       └── hook-patterns.md
├── Antipatterns/
│   ├── llm-assumptions.md        ← qué asume Claude incorrectamente
│   └── tool-gotchas.md           ← errores silenciosos de herramientas
├── Workflow/
│   └── preferences.md            ← preferencias del usuario
└── _INDEX.md                     ← índice navegable
```

---

### Estructura del Vault Local por Repo

```
.claude/vault/                    ← dentro del repo (gitignored o no)
├── decisions/
│   └── YYYY-MM-DD.md             ← decisiones arquitectónicas del día
├── lessons/
│   └── session-YYYY-MM-DD.md     ← lessons learned de la sesión
└── context/
    └── architecture.md           ← arquitectura actual del proyecto
```

---

## 14. Recursos y Referencias

| Recurso | URL | Tipo |
|---------|-----|------|
| Tweet original | https://x.com/cyrilXBT/status/2034282316411879917 | Video 58:57 |
| Doc hackathon Panaversity | https://docs.google.com/document/d/1ofTMR1IE7jEMvXM-rdsGXy6unI4DLS_gc6dmZo8WPkI | Blueprint técnico |
| Doc Cloud FTE (continuación) | https://docs.google.com/document/d/15GuwZwIOQy_g1XsIJjQsFNHCTQTWoXQhWGVMhiH0swc | Arquitectura cloud |
| Curso @gregisenberg | — | Base del video |
| Panaversity Claude Code | https://agentfactory.panaversity.org/docs/AI-Tool-Landscape/claude-code-features-and-workflows | Docs |
| Ralph Wiggum plugin | https://github.com/anthropics/claude-code/tree/main/.claude/plugins/ralph-wiggum | Referencia |
| MCP filesystem server | https://modelcontextprotocol.io/quickstart | Setup MCP |
| Odoo API (Gold tier) | https://www.odoo.com/documentation/19.0/developer/reference/external_api.html | ERP |

---

*Documento generado: 2026-03-20 | multi-agent-ralph-loop research*
