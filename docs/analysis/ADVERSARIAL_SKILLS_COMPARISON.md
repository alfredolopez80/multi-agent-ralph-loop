# Comparación de Skills Adversariales

## Resumen Ejecutivo

| Aspecto | `/adversarial` | `/adversarial-code-analyzer` |
|---------|----------------|------------------------------|
| **Tamaño** | 46 líneas | 302 líneas |
| **Complejidad** | Simple | Multi-agent complejo |
| **Arquitectura** | Dual-model | ZeroLeaks multi-agent |
| **Commando** | `/adversarial` | `/adversarial-analyze` |
| **Uso de CLIs** | Sí (codex, gemini) | Sí (codex, gemini) |

---

## `/adversarial` - Simple Dual-Model Cross-Validation

**Ubicación:** `.claude/skills/adversarial/SKILL.md` (46 líneas)

**Propósito:**
Validación adversarial simple usando 2 modelos AI que analizan código de forma independiente.

**Cómo Funciona:**
```
1. Modelo A analiza el código
2. Modelo B analiza el mismo código
3. Comparan findings
4. Solo reportan consenso
```

**Modelos Usados:**
- `/codex-cli` (gpt-5.2-codex)
- `/gemini-cli` (Gemini 3)
- Modelo nativo (GLM-4.7)

**Trigger Words:**
- "adversarial review"
- "validate with adversarial"
- "cross-validation"
- "adversarial testing"

**Comandos:**
```bash
/adversarial "Review this authentication code"
/adversarial "Validate this payment processing"
```

**Salida:**
- Consensus findings (ambos modelos acuerdan)
- Confidence levels
- Recommendations
- Validation status

---

## `/adversarial-code-analyzer` - Multi-Agent ZeroLeaks System

**Ubicación:** `.claude/skills/adversarial-code-analyzer/SKILL.md` (302 líneas)

**Propósito:**
Sistema multi-agent avanzado inspirado en ZeroLeaks para análisis exhaustivo de vulnerabilidades.

**Arquitectura:**
```
             ORCHESTRATOR (Engine)
                    |
    +---------------+---------------+
    |               |               |
STRATEGIST      ATTACKER        EVALUATOR
    |               |               |
    +-------+-------+-------+-------+
                    |
                MUTATOR
```

**5 Agentes Especializados:**

| Agente | Rol | Enfoque |
|--------|-----|---------|
| **Engine** | Orquestador | Maneja árbol de exploración |
| **Strategist** | Estratega | Selecciona estrategia según codebase |
| **Attacker** | Ofensiva | Genera vectores de ataque |
| **Evaluator** | Evaluación | Analiza respuestas para vulnerabilidades |
| **Mutator** | Variación | Crea variaciones de test cases |

**Fases de Análisis:**
1. **Reconnaissance** → Entender estructura
2. **Profiling** → Perfil de defensa
3. **Soft Probe** → Análisis suave
4. **Escalation** → Intensificar análisis
5. **Exploitation** → Búsqueda activa de vulnerabilidades
6. **Persistence** → Análisis persistente

**Comandos:**
```bash
/adversarial-analyze src/auth/
/adversarial-analyze --target security src/api/
/adversarial-analyze --depth 5 --branches 4 src/
```

**Salida:**
- Árbol de exploración completo
- Vectores de ataque generados
- Vulnerabilidades encontradas
- Test cases mutados
- Reporte exhaustivo

---

## ¿Por qué aparece `/adversarial-code-analyzer` primero?

**Causa probable:** Coincidencia de palabras clave

Cuando escribes "adversar", el sistema busca coincidencias en:
1. **Nombres de archivos** → `adversarial-code-analyzer` contiene "adversarial"
2. **Descripciones** → Ambos tienen "adversarial" en description
3. **Triggers** → Ambos responden a "adversarial"

**Prioridad del autocompletado:**
```
/adversarial-code-analyzer  ← Más específico (más palabras)
/adversarial                ← Más genérico
```

---

## Diferencias Clave

### 1. Uso de CLIs

**Ambos usan:** `/codex-cli` y `/gemini-cli`

**`/adversarial`:**
- Llama CLIs directamente via Bash
- Más simple, menos overhead

**`/adversarial-code-analyzer`:**
- Usa CLIs dentro de agentes especializados
- Cada agent usa CLIs de forma diferente
- Más complejo, más thorough

### 2. Tiempo de Ejecución

| Skill | Tiempo Estimado | Complejidad |
|-------|------------------|--------------|
| `/adversarial` | ~30-60 segundos | Rápido |
| `/adversarial-code-analyzer` | ~2-5 minutos | Exhaustivo |

### 3. Casos de Uso

**Usa `/adversarial` para:**
- Review rápido de código
- Validación de cambios críticos
- Cross-validation básica
- Decisiones de commit

**Usa `/adversarial-code-analyzer` para:**
- Auditorías de seguridad completas
- Análisis de módulos enteros
- Testing exhaustivo de edge cases
- Análisis de arquitectura

---

## Recomendación de Uso

```bash
# Para reviews rápidos (diario)
/adversarial "Revisa estos cambios"

# Para auditorías profundas (semanal/mensual)
/adversarial-analyze src/auth/

# Para validar antes de commit
/adversarial "¿Es seguro hacer commit?"

# Para análisis exhaustivo de seguridad
/adversarial-analyze --target security --depth 5 src/
```

---

## Conclusión

| Criterio | Ganador |
|-----------|---------|
| **Velocidad** | `/adversarial` |
| **Profundidad** | `/adversarial-code-analyzer` |
| **Simplicidad** | `/adversarial` |
| **Exhaustividad** | `/adversarial-code-analyzer` |
| **Balance** | `/adversarial` |

**Para uso diario:** `/adversarial` es más práctico

**Para auditorías de seguridad:** `/adversarial-code-analyzer` es superior
