# Survey: Software Engineering Agents - Resumen Comprehensivo

> **Paper**: "Software Engineering Agents" (arXiv:2511.18538v5)
> **Fecha de análisis**: 2026-01-18
> **Páginas**: ~175+ páginas, 4195 líneas de contenido

---

## Tabla de Contenidos

1. [Visión General](#1-visión-general)
2. [Sección 5: Software Engineering Agents](#2-sección-5-software-engineering-agents)
   - [5.1 Agentes en el Ciclo de Vida del Software](#51-agentes-en-el-ciclo-de-vida-del-software)
   - [5.2 Agentes Generales de Código](#52-agentes-generales-de-código)
   - [5.3 Entrenamiento de SWE Agents](#53-entrenamiento-de-swe-agents)
   - [5.4 Tendencias Futuras](#54-tendencias-futuras)
3. [Sección 6: Code as...](#3-sección-6-code-as)
   - [6.1 Code as Interaction Protocols](#61-code-as-interaction-protocols)
   - [6.2 Code as Agentic Capabilities](#62-code-as-agentic-capabilities)
   - [6.3 Code as Environment Interfaces](#63-code-as-environment-interfaces)
4. [Sección 7: Safety of Code LLMs](#4-sección-7-safety-of-code-llms)
   - [7.1 Safety Pre-training](#71-safety-pre-training)
   - [7.2 Safety Post-training](#72-safety-post-training)
   - [7.3 Red-teaming Techniques](#73-red-teaming-techniques)
   - [7.4 Mitigation Strategies](#74-mitigation-strategies)
5. [Sección 8: Training Recipes](#5-sección-8-training-recipes)
   - [8.1 Distributed Training Frameworks](#81-distributed-training-frameworks)
   - [8.2 Pre-Training Guidelines](#82-pre-training-guidelines)
   - [8.3 Supervised Fine-Tuning Guidelines](#83-supervised-fine-tuning-guidelines)
6. [Frameworks y Sistemas Mencionados](#6-frameworks-y-sistemas-mencionados)
7. [Conclusiones Clave](#7-conclusiones-clave)

---

## 1. Visión General

Este survey comprehensivo examina el estado del arte en **Software Engineering Agents** - sistemas autónomos o semi-autónomos basados en LLMs diseñados para soportar, automatizar y mejorar flujos de trabajo tradicionales de ingeniería de software.

### Estructura del Paper

```
Sección 5: Software Engineering Agents
├── 5.1 SWE Agents en Ciclos de Vida
│   ├── 5.1.1 Requirements Engineering
│   ├── 5.1.2 Software Development
│   ├── 5.1.3 Software Testing
│   ├── 5.1.4 Software Maintenance
│   └── 5.1.5 End-to-End Software Agents
├── 5.2 General Code Agents
├── 5.3 Training SWE Agents
│   ├── 5.3.1 Fine-tuning
│   └── 5.3.2 Reinforcement Learning
└── 5.4 Future Trends

Sección 6: Code as...
├── 6.1 Interaction Protocols (Tool Use, MCP)
├── 6.2 Agentic Capabilities (Thinking, Acting, Memory)
└── 6.3 Environment Interfaces (Simulation, Computer-Use)

Sección 7: Safety of Code LLMs
├── 7.1 Safety Pre-training
├── 7.2 Safety Post-training
├── 7.3 Red-teaming Techniques
└── 7.4 Mitigation Strategies

Sección 8: Training Recipes
├── 8.1 Distributed Training Frameworks
├── 8.2 Pre-Training Guidelines
└── 8.3 Supervised Fine-Tuning Guidelines
```

---

## 2. Sección 5: Software Engineering Agents

### 5.1 Agentes en el Ciclo de Vida del Software

Los SWE Agents se organizan según las fases del modelo waterfall:

```
┌────────────────────────────────────────────────────────────────────┐
│                    SWE Agents Taxonomy                              │
├────────────────────────────────────────────────────────────────────┤
│  Requirements Engineering                                           │
│  ├── Acquisition (Elicitron)                                       │
│  ├── Examination & Reconciliation (MARE, MAD)                      │
│  ├── Modeling & Formalization (Progressive Prompting)              │
│  ├── Assurance & Confirmation (SimUser, UXAgent)                   │
│  └── End-to-End RE (MARE, iReDev)                                  │
├────────────────────────────────────────────────────────────────────┤
│  Software Development                                               │
│  ├── Program Synthesis (AlphaCodium, ChatDev, MetaGPT)             │
│  ├── Text-to-SQL (DAIL-SQL, MAC-SQL, CHESS)                        │
│  ├── Comment Generation (DeepCom, RAGcomment)                      │
│  ├── Review Generation (CodeReviewer, Hydra-Reviewer)              │
│  ├── Fault Localization (AutoFL, AgentFL, LLM4FL)                  │
│  ├── Document Generation (RepoAgent, DocAgent)                     │
│  └── Patch Generation (RepairLLaMA, AutoCodeRover)                 │
├────────────────────────────────────────────────────────────────────┤
│  Software Testing                                                   │
│  ├── Unit Test Generation (ChatTester, TestPilot, CoverUp)         │
│  ├── Fuzz Testing (AutoSafeCoder, CKGFuzzer)                       │
│  └── Other Testing Types                                           │
├────────────────────────────────────────────────────────────────────┤
│  Software Maintenance                                               │
│  ├── Log Analysis (LogBERT, ReAct-RCA)                             │
│  ├── Compiler Optimization (CompilerDream)                         │
│  ├── Decompilation (LLM4Decompile)                                 │
│  └── DevOps & CI/CD                                                │
└────────────────────────────────────────────────────────────────────┘
```

#### 5.1.1 Requirements Engineering (RE)

**Adquisición (Acquisition)**:
- **Elicitron**: Genera agentes de usuario simulados que interactúan autónomamente con productos, registran experiencias y proveen feedback estructurado
- Descubre requisitos explícitos y latentes expandiendo la cobertura más allá de la elicitación tradicional

**Examen y Reconciliación**:
- **MAD (Multi-Agent Debate)**: Agentes opuestos debaten interpretaciones de requisitos mientras un agente juez consolida opiniones
- Mejora consistencia y calidad de decisiones

**Modelado y Formalización**:
- **Progressive Prompting**: Mapeo iterativo de requisitos NL a estructuras de código OO
- **PrototypeFlow**: Coordina múltiples agentes de diseño especializados bajo un supervisor
- **DCGen**: Colectivos de agentes multi-modal que interpretan screenshots UI y generan código funcional

**Aseguramiento y Confirmación**:
- **SimUser**: Modela agentes duales (app + usuario persona-based) para validación UX heurística
- **UXAgent**: Despliega miles de usuarios virtuales diversos para feedback de usabilidad a escala

**End-to-End RE**:
- **MARE**: Workspace agéntico donde agentes de adquisición, modelado y validación colaboran
- **iReDev**: Ecosistema de 6 agentes domain-specific (entrevistadores, analistas, revisores)

#### 5.1.2 Software Development

**Program Synthesis - Arquitecturas**:

| Tipo | Descripción | Ejemplos |
|------|-------------|----------|
| **Single-Agent Iterative** | Un modelo mejora iterativamente sus outputs | AlphaCodium, CodeCoT, Self-Refine |
| **Multi-Agent Pipelines** | Roles especializados colaboran | ChatDev, MetaGPT, AgentCoder, MapCoder |

**Program Synthesis - Estrategias de Feedback**:

1. **Parallel Sampling**: Best-of-N sampling (AlphaCode)
2. **Iterative Refinement**: 1-3 rondas de mejora (PyCapsule, CodeCoT)
3. **Hybrid Search**: Combina generación paralela con refinamiento (S* algorithm)
4. **Consistency-based Re-ranking**: MPSC evalúa coherencia entre implementación, spec y tests

**Text-to-SQL Evolution**:
```
Pre-LLM → Prompting/ICL → Schema Grounding → Multi-Agent

Sistemas destacados:
- DAIL-SQL: Selección few-shot basada en queries y SQL
- C3-SQL: Zero-shot prompts + execution voting
- MAC-SQL/MCS-SQL: Multi-agent collaboration
- CHESS: Schema linking con catálogos de BD
- OmniSQL: Pipeline escalable para datos sintéticos
```

**Comment Generation Evolution**:
```
Mapping-Based → Neural Seq2Seq → LLM/Agent-Based

Mapping: AutoComment, CloCom (recuperación de pares código-comentario)
Neural: DeepCom, APIContext2Com, GTrans (Seq2Seq + GNNs)
LLM: SCCLLM, RAGComment (ICL + retrieval augmentation)
Agent: AutoDev (analiza historial, genera/revisa comentarios continuamente)
```

**Fault Localization Approaches**:

| Paradigma | Descripción | Ejemplos |
|-----------|-------------|----------|
| End-to-End Neural | Arquitecturas unificadas para detección + localización + reparación | Restore, FetaFix |
| Optimization | Fine-tuning con datasets domain-specific | DeepDebug, InferFix |
| External Tool Calling | LLMs interactúan con repos via tool calls | AutoFL, FlexFL |
| Multi-Agent | Agentes especializados cooperan en debugging | RING, LLM4FL (tri-agent) |

**Patch Generation Categories**:

```
┌─────────────────────────────────────────────────────────────┐
│                  Patch Generation Taxonomy                   │
├─────────────────────────────────────────────────────────────┤
│  Fine-tuning & Prompting                                    │
│  └── RepairLLaMA, AlphaRepair, CIRCLE, FitRepair, ThinkRepair│
├─────────────────────────────────────────────────────────────┤
│  Task Conversion & Specialized Training                      │
│  └── Recoder, NSEdit, RewardRepair, SeqTrans, KNOD          │
├─────────────────────────────────────────────────────────────┤
│  Static Analysis & Pattern-Guided                           │
│  └── DEAR, Synshine, GAMMA, FLAMES, ESBMC-AI                │
├─────────────────────────────────────────────────────────────┤
│  Retrieval-Augmented                                        │
│  └── InferFix, RAP-Gen, SelRepair, MultiMend, PredicateFix  │
├─────────────────────────────────────────────────────────────┤
│  Conversational & Multi-Agent                               │
│  └── ChatRepair, ITER, RepairAgent, AutoCodeRover, PatchPilot│
└─────────────────────────────────────────────────────────────┘
```

**Issue Resolving - Hierarchical Architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│              Code Agent Hierarchical Architecture            │
├─────────────────────────────────────────────────────────────┤
│  5. Intelligence Layer (Self-Evolution)                      │
│     └── SWE-Exp, SWE-Debate, SE-Agent                       │
├─────────────────────────────────────────────────────────────┤
│  4. Semantic Layer (Intent & Consistency)                    │
│     └── SemAgent, SpecRover, NEMOTRON-CORTEXA               │
├─────────────────────────────────────────────────────────────┤
│  3. Knowledge Layer (Code Knowledge Graphs)                  │
│     └── CODEXGRAPH, KGCompass, CGM, LingmaAgent             │
├─────────────────────────────────────────────────────────────┤
│  2. Architecture Layer (Multi-Agent Collaboration)           │
│     └── MAGIS, CODER, AGENTLESS, SWE-Fixer                  │
├─────────────────────────────────────────────────────────────┤
│  1. Foundation Interface Layer (ACI)                         │
│     └── SWE-Agent, OpenHands                                │
└─────────────────────────────────────────────────────────────┘
```

#### 5.1.3 Software Testing

**Unit Test Generation Evolution**:

```
Generation Capability → Generation Quality → Multi-Step Iterative

Capability: AthenaTest, A3Test
Quality: ChatTester (intent inference), TestPilot (prompt refiner)
         CoverUp, CodaMosa (coverage feedback), MuTAP (mutation feedback)
Iterative: ChatUniTest, TestART, HITS, SlipCover, TELPA
```

**Fuzz Testing Agents**:
- AutoSafeCoder, Mut4All, WhiteFox, CKGFuzzer, ToolFuzz

#### 5.1.4 Software Maintenance

**Log Analysis**:
- LogBERT, LogPrompt, R-Log, ReAct-RCA, LogRESP-Agent, CyberSleuth

**Compiler Optimization**:
- OpenTuner, DeepTune, AutoPhase, CompilerDream

**Decompilation/Deobfuscation**:
- Neutron, BTC, LLM4Decompile, CFADecLLM
- DeGuard, Autonym, DIRE, VarBERT, ALFREDO

#### 5.1.5 End-to-End Software Agents

**Waterfall-based Full-Cycle**:
- AutoDev, GPT-Engineer, CodeAgent

**Agile and Iterative**:
- ChatDev, MetaGPT, AISD, CTC, CodePori
- LCG, AgileCoder, CodeS, IER, Croto

### 5.2 Agentes Generales de Código

Agentes que operan de forma general en ingeniería de software sin especializarse en una fase particular.

### 5.3 Entrenamiento de SWE Agents

#### 5.3.1 Fine-tuning SWE Agents

Técnicas para adaptar modelos pre-entrenados a tareas específicas de SWE.

#### 5.3.2 Reinforcement Learning for SWE Agents

Uso de RL para optimizar comportamiento de agentes en entornos interactivos de desarrollo.

### 5.4 Tendencias Futuras

Hacia ecosistemas de ingeniería de software integrados y autónomos:
- Mayor integración entre fases
- Aprendizaje continuo y auto-mejora
- Colaboración human-AI más sofisticada

---

## 3. Sección 6: Code as...

### 6.1 Code as Interaction Protocols

#### 6.1.1 Tool Use

El código como protocolo de interacción entre agentes y herramientas externas:
- Definición de APIs
- Llamadas a funciones
- Integración con sistemas externos

#### 6.1.2 Model Context Protocol (MCP)

Protocolo estándar para comunicación entre LLMs y herramientas:
- Estructura de contexto
- Gestión de estado
- Intercambio de información

### 6.2 Code as Agentic Capabilities

#### 6.2.1 Thinking in Code

Uso del código como medio de razonamiento:
- Chain-of-thought programático
- Razonamiento estructurado
- Planificación basada en código

#### 6.2.2 Acting in Code

Ejecución de acciones a través de código:
- Generación y ejecución de scripts
- Manipulación de entornos
- Automatización de tareas

#### 6.2.3 Memory With Code

Código como mecanismo de memoria:
- Persistencia de estado
- Recuperación de contexto
- Gestión de conocimiento

### 6.3 Code as Environment Interfaces

#### 6.3.1 Code as Simulation Gym

Uso de código para crear entornos de simulación:
- Entornos de entrenamiento
- Benchmarks interactivos
- Testing de agentes

#### 6.3.2 Computer-Use Agents

Agentes que interactúan con interfaces de usuario:
- Navegación web
- Manipulación de aplicaciones
- Automatización de desktop

---

## 4. Sección 7: Safety of Code LLMs

### 7.1 Safety Pre-training

#### 7.1.1 Data Provenance, Security, and License Compliance

Gestión de datos de entrenamiento:
- Tracking de procedencia
- Cumplimiento de licencias
- Filtrado de contenido sensible

#### 7.1.2 Training-data Auditing and Cleaning

Limpieza y auditoría de datasets:
- Detección de vulnerabilidades
- Eliminación de código malicioso
- Validación de calidad

#### 7.1.4 Robustness Against Adversarial Code Transformations

Resistencia a transformaciones adversarias:
- Obfuscación
- Inyección de código
- Manipulación sintáctica

#### 7.1.5 Privacy Risk Assessment

Evaluación de riesgos de privacidad:
- Memorización de datos
- Filtración de información
- Compliance con regulaciones

#### 7.1.6 Bias Assessment and Mitigation

Evaluación y mitigación de sesgos:
- Sesgos de lenguaje
- Patrones discriminatorios
- Equidad en generación

### 7.2 Safety Post-training

#### 7.2.1 Pre-training Limitations

**Problema Central**: El objetivo de pre-training (likelihood maximization) no se alinea con generación de código seguro.

```
Problemas identificados:
├── Knowledge-behavior disconnect
├── Vulnerabilidades en datasets (~40% de código generado tiene fallas)
├── Hallucinations (APIs inexistentes, uso incorrecto)
└── Patrones inseguros sistémicos (auth, session, input validation)
```

#### 7.2.2 Data Construction for Safety Alignment

**Pipeline de Generación de Datos**:

```
Real-world Repos → Data Filtering → Clean <vuln, fix> pairs
                      ↓
Teacher LLM + CWEs → Data Generation → Synthetic Dataset
                      ↓
LLM Processing → LLM as Judge → Preference Dataset
                      ↓
         Final Code LLM Security Alignment Dataset
```

**Tres Paradigmas**:
1. **Mining real-world**: CVEfixes, BigVul (pares vulnerabilidad-fix reales)
2. **Synthetic Generation**: HexaCoder, ProSec (generación guiada por CWE)
3. **Preference Distillation**: DPO triplets <prompt, chosen, rejected>

#### 7.2.3 Safety Supervised Fine-Tuning

| Tipo | Descripción | Ejemplos |
|------|-------------|----------|
| **Content-based SFT** | Fine-tuning en pares (vuln, fix) | Básico pero limitado |
| **Instruction-based SFT** | Prompts con tareas de seguridad | Mejor transferencia |
| **Feedback-based SFT** | SAST/tests en el loop | INDICT, Tool-in-the-loop |

#### 7.2.4 Localized Preference Optimization (LPO)

Optimización enfocada en tokens específicos que diferencian código seguro de inseguro:
- 19-40% reducción de issues de seguridad
- 3-10% mejora en calidad general
- Previene degradación de capacidades

#### 7.2.5 RL for Coding Safety

**RLHF/RLAIF para Código**:

```
Policy Optimization:
├── RLHF: Human feedback → Reward model → PPO optimization
├── RLAIF: AI teacher feedback → Scalable alignment
└── Safe RLHF: Separate helpfulness/harmlessness models

Reward Signals:
├── Verifiable: Compilation, tests, SAST scores
├── AI-Generated: Judge model with security constitution
└── Hybrid: S-GRPO (compilation + security + format)

Challenges:
├── Reward Hacking: Model modifies/deletes tests
├── Alignment Tax: Over-optimization degrades general capability
└── Mitigation: Constrained optimization, safety editor policy
```

### 7.3 Red-teaming Techniques

#### 7.3.1 Prompt-Level Manipulation

| Técnica | Descripción | Ejemplo |
|---------|-------------|---------|
| **Heuristic Jailbreaking** | Role-playing, prefix injection | DAN persona |
| **Optimization-Based** | Gradient search for adversarial suffixes | GCG algorithm |
| **Generation/Fuzzing** | LLM genera prompts de ataque | GPTFuzz |
| **Multi-Turn** | Debilita guardrails gradualmente | RedCoder |

#### 7.3.2 Semantic and Contextual Manipulation

| Técnica | Descripción |
|---------|-------------|
| **Trust Boundary Exploitation** | Payload en datos, no en instrucción (DeceptPrompt) |
| **Indirect Prompt Injection** | Envenenamiento de fuentes externas |
| **Obfuscation/Cross-Lingual** | Low-resource languages evaden filtros |

#### 7.3.3 Agentic Workflow Manipulation

| Técnica | Descripción |
|---------|-------------|
| **Tool Misuse** | Argumentos maliciosos a herramientas (SQL injection) |
| **Sandbox Escape** | Código que explota el entorno de ejecución |
| **AVDE** | Agente weaponizado como herramienta de pentesting |

**Tabla Comparativa de Red-teaming**:

| Método | Efectividad | Dificultad | Automatización | Costo | Transferibilidad |
|--------|-------------|------------|----------------|-------|------------------|
| Heuristic Jailbreak | Variable | Fácil | Baja | Bajo | Alta |
| GCG Optimization | Alta | Difícil | Alta | Alto | Alta |
| Fuzzing | Alta | Media | Alta | Medio | Media |
| Multi-Turn | Alta | Media | Media | Medio | Baja |
| Trust Boundary | Alta | Media | Media | Bajo | Media |
| Indirect Injection | Alta | Difícil | Baja | Bajo | Alta |
| Tool Misuse | Alta | Difícil | Baja | Bajo | Baja |
| Sandbox Escape | Variable | Muy Difícil | Baja | Alto | Baja |

### 7.4 Mitigation Strategies

**Defense-in-Depth Framework**:

```
┌─────────────────────────────────────────────────────────────────┐
│              Defense-in-Depth Architecture                       │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: Secure Execution Environments                          │
│  ├── OS-level Containers (Docker) - Shared kernel risk          │
│  ├── Process-level Sandboxes (nsjail, seccomp-bpf)              │
│  └── Virtualization (Firecracker, gVisor, Kata)                 │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: Proactive Pre-Execution Validation                     │
│  ├── Modernized SAST/DAST (tool-in-the-loop)                    │
│  ├── Multi-Agent Review (Critic LLM reviews Coder)              │
│  └── Formal Methods (constraints, proofs, invariants)           │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: Runtime Oversight                                      │
│  ├── Guardrail Frameworks (AgentSentinel, GuardAgent)           │
│  ├── Verifiable Policy Enforcement (AgentSpec, ShieldAgent)     │
│  └── Active Control (Ctrl-Z action resampling)                  │
└─────────────────────────────────────────────────────────────────┘
```

**Sistemas de Mitigación Destacados**:

| Sistema | Función |
|---------|---------|
| **AgentSentinel** | Monitoreo de seguridad end-to-end en tiempo real |
| **GuardAgent** | Reasoning habilitado por conocimiento para anticipar acciones dañinas |
| **LlamaFirewall** | Guardrail open-source para inputs/outputs |
| **AgentSpec** | Framework para reglas de enforcement verificables |
| **ShieldAgent** | Reasoning de política de seguridad verificable |
| **Ctrl-Z** | Resampling de acciones si se detectan como inseguras |

---

## 5. Sección 8: Training Recipes

### 8.1 Distributed Training Frameworks

**Comparativa de Frameworks**:

| Framework | Scaling Efficiency | Max Scale | Memory Strategy | Key Innovation |
|-----------|-------------------|-----------|-----------------|----------------|
| **Megatron-LM** | 76% (512 GPUs) | 530B | TP + SP | Overlapped tensor parallel |
| **DeepSpeed** | 10x speedup | 200B | ZeRO-1/2/3 + Offload | Progressive state sharding |
| **Megatron-DS** | High | 530B | ZeRO + TP | Unified 3D parallelism |
| **PyTorch FSDP** | 1.5% over FSDP1 | 70B | Full sharding | Native PyTorch integration |
| **TorchTitan** | 65% speedup (8B) | 405B | FSDP2 + FP8 | 4D parallelism + compile |
| **Colossal-AI** | 2.76x speedup | 175B | Multi-dim TP + Gemini | Flexible TP dimensions |

**Selección de Framework**:
- **Megatron-LM/Megatron-DS**: Clusters premium con NVLink/InfiniBand, >100B params
- **DeepSpeed**: Eficiencia de memoria, entornos limitados
- **PyTorch FSDP/TorchTitan**: Integración nativa PyTorch
- **Colossal-AI**: Máxima flexibilidad en estrategias de paralelismo

### 8.2 Pre-Training Guidelines

**Scaling Laws por Lenguaje de Programación**:

```
L(N, D) = A/N^α + B/D^β + E

donde:
- N = parámetros del modelo
- D = tokens de entrenamiento
- E = loss irreducible (complejidad del lenguaje)
```

| Lenguaje | α | β | E (Irreducible Loss) |
|----------|---|---|----------------------|
| Python | 0.221 | 1.217 | 0.566 |
| Java | 0.447 | 1.129 | 0.397 |
| JavaScript | 0.692 | 1.247 | 0.554 |
| TypeScript | 0.439 | 1.303 | 0.518 |
| C# | 0.321 | 1.350 | 0.288 |
| Go | 0.845 | 1.149 | 0.414 |
| Rust | 0.643 | 1.297 | 0.397 |

**Insights Clave**:
- Lenguajes interpretados (Python) → exponentes más grandes → más beneficio de datos/params
- Lenguajes compilados/tipados (Rust, Go) → exponentes menores → saturan más rápido
- E ordena complejidad: C# < Java = Rust < Go < TypeScript < JavaScript < Python

**Efectos de Mezcla Multilingüe**:
- Java-C# → >20% reducción de loss vs. Java-only
- JavaScript-TypeScript → mejoras consistentes mutuas
- Python → asimétrico (beneficia a otros como auxiliar, pero mezclar daña Python como target)

**Recomendaciones**:

1. **Token Budgets**: Proporcional a exponentes β (más tokens para Python, TypeScript)
2. **Language Pairing**: Priorizar pares sintácticamente similares (Java-C#, JS-TS, Rust-Go)
3. **Compute Allocation**: Más compute para lenguajes con alto E (Python, JavaScript)
4. **Default Strategy**: Multilingüe por defecto para cross-lingual transfer

### 8.3 Supervised Fine-Tuning Guidelines

**Comparativa de Frameworks SFT**:

| Framework | HumanEval | MBPP | Time (64 GPUs) |
|-----------|-----------|------|----------------|
| QwenCoder-SFT (DDP) | 0.848 | 0.857 | 20 min |
| LLaMA-Factory (ZeRO-3) | 0.872 | 0.860 | 50 min |
| MS-Swift (Megatron) | 0.872 | 0.857 | 20 min |
| VERL (FSDP v2) | 0.860 | 0.860 | 2h |

**Sensibilidad de Hiperparámetros**:

| Factor | Impacto | Recomendación |
|--------|---------|---------------|
| **Global Batch Size** | DOMINANTE | 64-256 óptimo, >512 degrada |
| **Learning Rate** | Model-dependent | 2e-6 a 5e-6 (14B), 5e-6 a 1e-5 (30B) |
| **Epochs** | Scale-dependent | 3-5 (14B), 3-10 (30B) |
| **LR Scheduler** | Secundario | Cosine (14B), Constant (30B) |
| **Warmup Ratio** | Secundario | 0.03-0.10 |

**Dense vs MoE Architecture**:

| Característica | Dense (14B) | MoE (30B) |
|----------------|-------------|-----------|
| Robustez | Alta | Baja (varianza alta) |
| Batch Tolerance | Hasta 1024 | Hasta 512 |
| LR Sensitivity | 2e-6 a 5e-6 | Estrecho, evitar <1e-6 |
| Training Length | 3-5 epochs | 5-10 epochs |
| Stability | Amplio basin | Margen estrecho |

---

## 6. Frameworks y Sistemas Mencionados

### Requirements Engineering
- **Elicitron**: Simulación de usuarios para elicitación
- **MARE**: Multi-agent requirements engineering
- **MAD**: Multi-agent debate para reconciliación
- **iReDev**: Ecosistema de 6 agentes para RE

### Program Synthesis
- **AlphaCodium**: YAML outputs, análisis de fallas
- **ChatDev**: Simulación de organización multi-rol
- **MetaGPT**: Meta-programming para colaboración
- **AgentCoder**: Coder + Test writer + Executor
- **MapCoder**: Retriever + Planner + Coder + Debugger

### Issue Resolution
- **SWE-Agent**: Agent-Computer Interface (ACI)
- **OpenHands**: Diversificación de estrategias de reparación
- **AGENTLESS**: 3-stage flow simplificado
- **AutoCodeRover**: Multi-agent con knowledge graphs
- **CODEXGRAPH**: Integración LLM + graph database

### Testing
- **ChatTester**: Intent inference + iterative refinement
- **CoverUp**: Coverage feedback en generation loop
- **HITS**: Multi-step reasoning con slicing

### Safety
- **HexaCoder**: Oracle-guided vulnerability generation
- **ProSec**: Proactive security alignment
- **Safe RLHF**: Separate helpfulness/harmlessness optimization
- **AgentSentinel**: Real-time security monitoring
- **ShieldAgent**: Verifiable safety policy reasoning

---

## 7. Conclusiones Clave

### Evolución del Campo

```
Static Prompting → Single-Agent Iterative → Multi-Agent Collaboration
                                                      ↓
                                           Hierarchical Architectures
                                                      ↓
                                           Self-Evolving Systems
```

### Principios Emergentes

1. **Feedback como motor**: El feedback (tests, SAST, execution) transforma generación en búsqueda guiada

2. **Separación de concerns**: Roles especializados (coder, reviewer, executor) mejoran calidad

3. **Knowledge graphs**: Representación estructurada del código mejora comprensión semántica

4. **Defense-in-depth**: Seguridad requiere múltiples capas (isolation, pre-validation, runtime)

5. **Scaling laws matter**: Cada lenguaje tiene propiedades únicas que afectan entrenamiento

### Desafíos Abiertos

1. **Safety-capability tradeoff**: Más seguridad puede degradar utilidad
2. **Reward hacking**: Modelos explotan métricas de reward
3. **Context limitations**: Repositorios grandes exceden context windows
4. **Evaluation gap**: Benchmarks no capturan complejidad real

### Tendencias Futuras

1. **Self-evolution**: Agentes que aprenden de experiencias pasadas
2. **Semantic understanding**: Alineación con intent del desarrollador
3. **End-to-end autonomy**: Pipelines completamente automatizados
4. **Human-AI collaboration**: Interfaces más sofisticadas de colaboración

---

## Referencias Clave

El paper cita 1300+ referencias. Algunas destacadas:

- [1184] SWE-Agent: Agent-computer interfaces for software engineering
- [812] ChatDev: Communicative agents for software development
- [402] MetaGPT: Meta programming for multi-agent collaborative framework
- [828] DPO: Direct preference optimization
- [834] DeepSpeed: System optimizations for training deep learning models
- [898] Megatron-LM: Training multi-billion parameter language models

---

*Documento generado: 2026-01-18*
*Fuente: arXiv:2511.18538v5*
