# About Multi-Agent Ralph Loop

**Multi-Agent Ralph Loop** is an AI orchestration framework for Claude Code that combines MemPalace-inspired memory, parallel Agent Teams, and Aristotle First Principles methodology to deliver validated, high-quality code.

## What is Multi-Agent Ralph Loop?

An AI-powered development system that:

- **Remembers across sessions** via a 4-layer memory stack (MemPalace architecture)
- **Coordinates multiple AI agents** working in parallel through Agent Teams
- **Validates code** through 4-stage blocking quality gates
- **Learns automatically** from every session, graduating rules to global scope
- **Analyzes from first principles** before every non-trivial task (Aristotle methodology)

## MemPalace Memory System (v3.0)

Ralph's memory architecture is inspired by the [Memory Palace technique](https://en.wikipedia.org/wiki/Method_of_loci) and the [MemPalace project](https://github.com/tcsenpai/mempalace). It uses a 4-layer stack that loads in ~818 real BPE tokens at session start:

| Layer | Content | Tokens |
|-------|---------|--------|
| **L0 Identity** | Agent principles, methodology | ~239 |
| **L1 Essential** | 9 top rules (from 1003 procedural) | ~579 |
| **L2 Taxonomy** | Halls/Rooms/Wings (on-demand) | varies |
| **L3 Vault** | Obsidian knowledge graph (on-demand) | varies |

### What We Learned Implementing MemPalace

Our implementation diverges from the original MemPalace approach in important ways. These findings are documented in detail in [AAAK_LIMITATIONS_ADR](AAAK_LIMITATIONS_ADR_2026-04-07.md):

1. **Token encoding doesn't work** — Unicode PUA encoding (AAAK) increased real BPE tokens by +19.8% despite `wc -w` reporting -86% reduction. LLM tokenizers split unknown codepoints into multiple byte tokens.

2. **Selection beats encoding** — Filtering 1003 rules down to 27 high-value ones achieved the real reduction target. No encoding scheme can match the efficiency of simply choosing fewer things.

3. **`wc -w` is not a token counter** — Any token reduction claim must use tiktoken cl100k_base (or the actual model's tokenizer). Word count heuristics are misleading for encoded content.

4. **Taxonomy needs noise exclusion** — 46% of auto-learned rules were noise (cross-domain repeats, vague bundles). A mechanical + substantive filter is essential.

5. **Learning must be boundary-safe** — The pipeline flows project -> global -> vault without leaking repo-specific data. Only universal patterns graduate.

### Agent Diaries

Each of the 6 Ralph agents has a diary in the Obsidian vault for tracking behavioral patterns and improvement opportunities across sessions.

## Agent Teams

| Teammate | Role | Specialization |
|---|---|---|
| `ralph-coder` | Implementation | Code changes with quality gates |
| `ralph-reviewer` | Code review | OWASP, anti-patterns |
| `ralph-tester` | Testing (80% coverage) | Unit, integration, coverage |
| `ralph-researcher` | Research | Codebase exploration, web search |
| `ralph-frontend` | Frontend | WCAG 2.1 AA, DESIGN.md compliance |
| `ralph-security` | Security | 6 pillars: input, auth, crypto, logging, config, deps |

All independent tasks execute in **parallel** (mandatory for complexity >= 3). Sequential execution requires documented data dependency.

## Quality Gates

4-stage validation pipeline, all blocking:

1. **CORRECTNESS** — Syntax valid, logic sound
2. **QUALITY** — Types correct, no debug artifacts
3. **SECURITY** — semgrep + gitleaks + OWASP
4. **CONSISTENCY** — Linting and style (advisory)

Hook enforcement via `TeammateIdle` and `TaskCompleted` events ensures no agent completes without passing all gates.

## Parallel-First Rule

All independent tasks MUST execute in parallel using Agent Teams. Sequential execution requires documented data dependency.

```
Complexity 1-2: Direct execution (no team required)
Complexity 3+:  Agent Teams with parallel teammates (MANDATORY)
```

See: `.claude/rules/parallel-first.md` and anti-rationalization entries #38-#46.

## Anti-Rationalization

46-entry table preventing agents from rationalizing suboptimal decisions. Integrated into the orchestrator and iterate skills to ensure agents follow the plan rather than cutting corners.

Reference: `docs/reference/anti-rationalization.md`

## Statistics

| Metric | Value |
|--------|-------|
| **Memory Layers** | 4 (L0-L3) |
| **Wake-up Tokens** | ~818 (cl100k_base) |
| **Active Hooks** | 22 |
| **Skills** | 21 core (globally distributed) |
| **Tests** | 925+ (99.2% pass rate) |
| **Learned Rules** | 14 taxonomy files (46% noise filtered) |
| **Agent Diaries** | 6 (Obsidian vault) |
| **Security Tests** | 19 (claude-mem removal + pipeline) |
| **Anti-Rationalization** | 46 entries |
| **Version** | 3.0.0 |

## Core Skills

| Skill | Purpose |
|---|---|
| `/orchestrator` | Full workflow: evaluate, clarify, classify, plan, execute, validate, retrospect |
| `/iterate` | Iterative execution until VERIFIED_DONE |
| `/parallel` | Concurrent multi-task execution |
| `/task-batch` | Autonomous batch from PRD files |
| `/gates` | Multi-language quality validation |
| `/security` | Multi-agent security audit |
| `/autoresearch` | Autonomous experimentation loop |
| `/adversarial` | Spec refinement with cross-validation |
| `/bugs` | Systematic bug hunting |
| `/ship` | Pre-launch checklist (gates + security + review) |
| `/spec` | Verifiable technical specification before coding |

## Use Cases

### Feature Development
```bash
/orchestrator "Implement OAuth2 with JWT tokens"
# --> Aristotle analysis --> parallel: coder + tester --> quality gates --> VERIFIED_DONE
```

### Security Audit
```bash
/security src/
# --> Spawns ralph-security + ralph-reviewer in parallel
```

### Repository Learning
```bash
/repo-learn https://github.com/fastapi/fastapi
# --> Extracts patterns --> stores in vault --> graduates to global
```

## Architecture

```
User Request --> Claude Code
                    |
            Aristotle Analysis (5 phases)
                    |
            Task Classification (1-10)
                    |
        +-----------+-----------+
        |                       |
    Agent Teams            Quality Gates
    (parallel)             (blocking)
        |                       |
    ralph-coder            CORRECTNESS ok
    ralph-tester           QUALITY ok
    ralph-reviewer         SECURITY ok
    ralph-security         CONSISTENCY ok
        |                       |
        +-----------+-----------+
                    |
              VERIFIED_DONE
                    |
            MemPalace Learning
            (session -> vault -> global)
```

## Technology Stack

- **Claude Code** — Base orchestration (hooks, skills, Agent Teams)
- **Obsidian** — Knowledge graph (vault L3)
- **Bash/zsh** — Hooks and automation scripts
- **Python** — Test suite, AAAK utility, layer logic

## Installation

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Validate infrastructure
bash scripts/validate-global-infrastructure.sh

# Run tests
python3 -m pytest tests/ -q
```

## Documentation

| Document | Description |
|----------|-------------|
| [README.md](../../README.md) | Project overview and quick start |
| [AAAK Limitations ADR](AAAK_LIMITATIONS_ADR_2026-04-07.md) | Why encoding fails for LLM tokens |
| [Memory Migration Map](MEMORY_LEARNING_MIGRATION_MAP_2026-04-07.md) | Full migration from claude-mem |
| [Anti-Rationalization](../reference/anti-rationalization.md) | 46-entry table against agent corner-cutting |
| [Aristotle Methodology](../reference/aristotle-first-principles.md) | First principles analysis framework |
| [Security Reports](../security/) | Security audit documentation |
| [Benchmark Results](../benchmark/) | Memory baselines and wake-up cost |
| [Batch Execution](../batch-execution/) | Batch task execution documentation |

## Acknowledgments

- [MemPalace](https://github.com/tcsenpai/mempalace) — Original research that inspired the memory architecture
- [Claude Code](https://code.claude.com) — Orchestration platform
- [karpathy/autoresearch](https://github.com/karpathy/autoresearch) — Autonomous experimentation inspiration

## License

MIT License - see [LICENSE](../../LICENSE) for details.

---

**Version**: 3.0.0
**Last Updated**: 2026-04-08
