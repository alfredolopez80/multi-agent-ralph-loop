# Multi-Agent Ralph Loop

Autonomous orchestration framework for Claude Code. Parallel-first execution with Agent Teams, Aristotle First Principles methodology, and quality gates.

## What It Does

Ralph extends Claude Code into a multi-agent development framework. Every task is analyzed from first principles, decomposed into parallel subtasks, assigned to specialized teammates, and validated through quality gates before completion.

| Capability | Description |
|---|---|
| **Parallel-First** | All independent tasks execute in parallel via Agent Teams (mandatory for complexity >= 3) |
| **6 Teammates** | ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher, ralph-frontend, ralph-security |
| **59 Skills** | Orchestration, security, testing, research, frontend, blockchain, and more |
| **~85 Hooks** | Pre/post tool validation, quality gates, secret sanitization, security guards |
| **Aristotle Analysis** | 5-phase first principles deconstruction before every non-trivial task |
| **Anti-Rationalization** | 46-entry table preventing agents from cutting corners |
| **Quality Gates** | 4-stage blocking validation: correctness, quality, security, consistency |
| **1023 Tests** | Full test suite, 0 failures |

## Quick Start

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Setup (creates symlinks, registers hooks)
./.claude/scripts/centralize-all.sh

# Verify
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
| `ralph-tester` | Testing (80% coverage) | Read, Edit, Write, Bash(test) |
| `ralph-researcher` | Research (Zai MCP) | Read, Grep, Glob, WebSearch |
| `ralph-frontend` | Frontend (WCAG 2.1 AA) | LSP, Read, Edit, Write, Bash |
| `ralph-security` | Security (6 pillars) | LSP, Read, Grep, Glob, Bash |

Agent Teams is enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json. Teammates are spawned in parallel by the orchestrator, iterate, parallel, security, and task-batch skills.

## Core Skills

| Skill | Purpose |
|---|---|
| `/orchestrator` | Full 10-step workflow: evaluate, clarify, classify, plan, execute, validate, retrospect |
| `/iterate` | Iterative execution until VERIFIED_DONE (max 15/30 iterations) |
| `/parallel` | Run multiple independent tasks concurrently |
| `/task-batch` | Autonomous batch execution from PRD files |
| `/gates` | 9-language quality gate validation |
| `/security` | Multi-agent security audit (OWASP, semgrep, gitleaks) |
| `/adversarial` | Spec refinement with multi-model cross-validation |
| `/bugs` | Systematic bug hunting |
| `/ship` | Pre-launch checklist (gates + security + review) |
| `/spec` | Verifiable technical specification before coding |

## Quality Gates

4-stage validation, all blocking except consistency:

1. **CORRECTNESS** — Syntax valid, logic sound
2. **QUALITY** — Types, no console.log/TODO/debugger
3. **SECURITY** — semgrep + gitleaks + OWASP validation
4. **CONSISTENCY** — Linting and style (advisory)

Hook enforcement: `TeammateIdle` (exit 2 = keep working) and `TaskCompleted` (exit 2 = block completion) ensure no agent completes without passing gates.

## Security Hooks

| Hook | Trigger | Purpose |
|---|---|---|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard, command chaining |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents operations outside current repo |
| `sanitize-secrets.js` | PostToolUse | Redacts 20+ secret patterns (GitHub PAT, AWS, JWT, etc.) |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Blocks idle with secrets/debug code (CWE-798, CWE-321) |
| `task-completed-quality-gate.sh` | TaskCompleted | 7 quality gates including hardcoded secrets + SQL injection |

## Parallel-First Rule

All independent tasks MUST execute in parallel. Sequential execution requires documented dependency.

```
Complexity 1-2: Direct execution (no team required)
Complexity 3+:  Agent Teams with parallel teammates (MANDATORY)
```

See: `.claude/rules/parallel-first.md` and anti-rationalization entries #38-#46.

## Architecture

```
User Request → Claude Code
                  ↓
          Aristotle Analysis (5 phases)
                  ↓
          Task Classification (1-10)
                  ↓
    ┌─────────────┴─────────────┐
    ↓                           ↓
Agent Teams                Quality Gates
(parallel execution)       (blocking validation)
    ↓                           ↓
ralph-coder ──┐         CORRECTNESS ✓
ralph-tester ─┤         QUALITY ✓
ralph-reviewer┤         SECURITY ✓
ralph-security┘         CONSISTENCY ✓
    ↓                           ↓
    └───────────┬───────────────┘
                ↓
         VERIFIED_DONE
```

## Requirements

| Tool | Version | Required |
|---|---|---|
| Claude Code | v2.1.42+ | Yes |
| Bash | 4.0+ | Yes |
| jq | 1.6+ | Yes |
| git | 2.0+ | Yes |
| python3 | 3.8+ | Yes (for tests) |
| GitHub CLI | Any | Optional |
| semgrep | Any | Optional (security) |
| gitleaks | Any | Optional (secrets) |

## Configuration

Primary: `~/.claude/settings.json`

The system is **model-agnostic** (v2.88+). All skills and agents inherit the configured model — no flags required.

```json
{
  "env": {
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "your-model",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Skills are symlinked to 6 platform directories. Source of truth: `.claude/skills/` in this repo.

## Testing

```bash
python3 -m pytest tests/ -q          # 1023 tests
./scripts/validate-hooks-registration.sh  # Hook validation
```

## Documentation

| Topic | Location |
|---|---|
| Changelog | `CHANGELOG.md` |
| Architecture | `docs/architecture/` |
| Anti-Rationalization | `docs/reference/anti-rationalization.md` |
| Aristotle Methodology | `docs/reference/aristotle-first-principles.md` |
| Hooks Reference | `docs/hooks/` |
| Security | `docs/security/` |
| Batch Execution | `docs/batch-execution/` |

## License

MIT License - see LICENSE file.

## References

- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
