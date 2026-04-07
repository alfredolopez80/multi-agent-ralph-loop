# Multi-Agent Ralph Loop

Autonomous orchestration framework for Claude Code with MemPalace-inspired memory, parallel-first Agent Teams, Aristotle First Principles methodology, and quality gates.

## What It Does

Ralph extends Claude Code into a multi-agent development framework with a structured memory system inspired by the [Memory Palace technique](https://en.wikipedia.org/wiki/Method_of_loci). Every task is analyzed from first principles, decomposed into parallel subtasks, assigned to specialized teammates, and validated through quality gates before completion.

| Capability | Description |
|---|---|
| **MemPalace Memory** | 4-layer memory stack (L0-L3) with 818-token wake-up, Obsidian vault KG, learned rules taxonomy |
| **Parallel-First** | All independent tasks execute in parallel via Agent Teams (mandatory for complexity >= 3) |
| **6 Teammates** | ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher, ralph-frontend, ralph-security |
| **22 Active Hooks** | Pre/post tool validation, quality gates, secret sanitization, security guards |
| **Aristotle Analysis** | 5-phase first principles deconstruction before every non-trivial task |
| **Quality Gates** | 4-stage blocking validation: correctness, quality, security, consistency |
| **925+ Tests** | Full test suite covering layers, hooks, security, skills, and pipeline |

## MemPalace Memory System

Inspired by the [MemPalace repository](https://github.com/tcsenpai/mempalace) (Memory Palace technique for LLM agents), Ralph implements a layered memory architecture with key differences based on our implementation findings.

### Layer Stack (Session Wake-up)

| Layer | File | Tokens (cl100k) | Purpose |
|-------|------|-----------------|---------|
| L0 | `~/.ralph/layers/L0_identity.md` | ~239 | Agent identity + principles |
| L1 | `~/.ralph/layers/L1_essential.md` | ~579 | 9 actionable rules (filtered from 1003) |
| L2 | `.claude/rules/learned/{halls,rooms,wings}/` | on-demand | Project-specific taxonomy |
| L3 | Obsidian vault grep | on-demand | Full knowledge base queries |

**Wake-up cost**: ~818 real BPE tokens (tiktoken cl100k_base), not the 19K pathological baseline.

### Learned Rules Taxonomy

Rules organized in 3 dimensions for flexible retrieval:

| Dimension | Directory | Organization |
|-----------|-----------|--------------|
| **Halls** (by type) | `.claude/rules/learned/halls/` | decisions, patterns, anti-patterns, fixes |
| **Rooms** (by topic) | `.claude/rules/learned/rooms/` | hooks, memory, agents, security, testing |
| **Wings** (by scope) | `.claude/rules/learned/wings/` | `_global/`, `multi-agent-ralph-loop/` |

### Key Implementation Findings

These findings emerged during our MemPalace implementation and may be relevant to others building LLM memory systems:

| Finding | Detail | ADR |
|---------|--------|-----|
| **Encoding doesn't reduce tokens** | AAAK (Unicode PUA encoding) increased cl100k_base tokens by +19.8%. `wc -w` falsely reported -86% reduction. | [AAAK_LIMITATIONS_ADR](docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md) |
| **Selection beats encoding** | Choosing fewer rules (27/1003) achieved the target; compressing the same rules did not. | Same ADR |
| **BPE splits unknown codepoints** | Unicode PUA characters (U+E000-U+F8FF) not in GPT-4/Claude vocabulary are split into 2-3 byte tokens each. | Same ADR |
| **Lossless codecs grow, never shrink** | Storing `symbolic + separator + original` means total size >= original. Only lossy compression reduces size. | Same ADR |
| **Taxonomy needs noise filtering** | 46% of auto-learned rules were noise (cross-domain repeats, vague bundles). Filtering is essential. | [TAXONOMY_RESTRUCTURE](docs/refactor/TAXONOMY_RESTRUCTURE_2026-04-07.md) |

### Learning Pipeline (Automatic)

```
SESSION (any repo)
  |
  +-- Stop --> continuous-learning.sh --> vault + procedural memory
  +-- PostToolUse --> semantic-realtime-extractor.sh --> vault facts
  +-- PostToolUse --> decision-extractor.sh --> vault decisions
  +-- SessionStart --> vault-graduation.sh --> promote to local rules
  +-- SessionEnd --> vault-index-updater.sh --> update indices
  |
FRIDAY CRON (6PM)
  |
  +-- vault-weekly-compile.sh --> sync to global + git commit
```

All learning flows project -> global -> vault without leaking repo-specific sensitive data. Only GREEN-classified (universal) patterns graduate to global scope.

## Quick Start

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Validate global infrastructure (36 checks)
bash scripts/validate-global-infrastructure.sh

# Run tests
python3 -m pytest tests/ -q

# Use
/orchestrator "Create a REST API endpoint"
/iterate "Fix all lint errors"
/security src/
```

## Agent Teams

6 specialized teammates for parallel execution:

| Teammate | Role | Tools |
|---|---|---|
| `ralph-coder` | Implementation | Read, Edit, Write, Bash |
| `ralph-reviewer` | Code review (OWASP) | Read, Grep, Glob |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) |
| `ralph-researcher` | Research (Zai MCP) | Read, Grep, Glob, WebSearch |
| `ralph-frontend` | Frontend (WCAG 2.1 AA) | LSP, Read, Edit, Write, Bash |
| `ralph-security` | Security (6 pillars) | LSP, Read, Grep, Glob, Bash |

## Core Skills

| Skill | Purpose |
|---|---|
| `/orchestrator` | Full 10-step workflow: evaluate, clarify, classify, plan, execute, validate, retrospect |
| `/iterate` | Iterative execution until VERIFIED_DONE (max 15/30 iterations) |
| `/parallel` | Run multiple independent tasks concurrently |
| `/task-batch` | Autonomous batch execution from PRD files |
| `/gates` | Multi-language quality gate validation |
| `/security` | Multi-agent security audit (OWASP, semgrep, gitleaks) |
| `/autoresearch` | Autonomous experimentation loop with Smart Setup |
| `/adversarial` | Spec refinement with multi-model cross-validation |

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
    ralph-coder ---+     CORRECTNESS ok
    ralph-tester --+     QUALITY ok
    ralph-reviewer-+     SECURITY ok
    ralph-security-+     CONSISTENCY ok
        |                       |
        +-----------+-----------+
                    |
              VERIFIED_DONE
                    |
            MemPalace Learning
            (session -> vault -> global)
```

## Security

| Hook | Trigger | Purpose |
|---|---|---|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard, command chaining |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents operations outside current repo |
| `sanitize-secrets.js` | PostToolUse | Redacts 20+ secret patterns |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Blocks idle with secrets/debug code |
| `task-completed-quality-gate.sh` | TaskCompleted | 7 quality gates before completion |

## Requirements

| Tool | Version | Required |
|---|---|---|
| Claude Code | v2.1.42+ | Yes |
| Bash | 4.0+ | Yes |
| jq | 1.6+ | Yes |
| git | 2.0+ | Yes |
| python3 | 3.8+ | Yes (for tests) |
| Obsidian | Any | Optional (for vault KG) |

## Testing

```bash
python3 -m pytest tests/ -q                           # 925+ tests
bash tests/unit/test-skills-unification-v2.87.sh      # 327 skills tests
bash scripts/validate-global-infrastructure.sh         # 36 infra checks
```

## Configuration

The system is **model-agnostic** — all skills and agents inherit the configured model from settings, no per-command flags required.

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Documentation

| Topic | Location |
|---|---|
| Architecture | `docs/architecture/` |
| AAAK Limitations ADR | `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md` |
| Memory Migration Map | `docs/architecture/MEMORY_LEARNING_MIGRATION_MAP_2026-04-07.md` |
| Anti-Rationalization | `docs/reference/anti-rationalization.md` |
| Aristotle Methodology | `docs/reference/aristotle-first-principles.md` |
| Security | `docs/security/` |
| Hooks Reference | `docs/hooks/` |
| Benchmarks | `docs/benchmark/` |

## Acknowledgments

- **[MemPalace](https://github.com/tcsenpai/mempalace)** — Original Memory Palace technique research for LLM agents that inspired our layered memory architecture. Our implementation diverges in key areas (encoding strategy, token measurement methodology, taxonomy filtering) documented in [AAAK_LIMITATIONS_ADR](docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md).
- **[Claude Code](https://code.claude.com)** — Base orchestration platform with hooks, skills, and Agent Teams APIs.
- **[karpathy/autoresearch](https://github.com/karpathy/autoresearch)** — Inspiration for the autonomous experimentation loop.

## License

MIT License - see LICENSE file.
