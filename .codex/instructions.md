# Codex CLI Instructions (v0.79.0)

## Overview
Configuration for Codex CLI (gpt-5.2-codex) as subagent in Ralph Wiggum system.

**Version**: 0.79.0
**Config**: `~/.codex/config.toml` with profiles

## Security Model (v0.79.0)

### Sandbox Modes
- `--sandbox read-only` → Security audits (no modificaciones)
- `--sandbox workspace-write` → Bug fixes, tests (limita escritura)
- `--sandbox danger-full-access` → ⚠️ Solo CI/CD con sandboxing externo

### Approval Policies
- `--ask-for-approval on-request` → Model decides (RECOMENDADO)
- `--ask-for-approval on-failure` → Solo pedir si falla
- `--ask-for-approval untrusted` → Pedir para comandos no-trusted
- `--ask-for-approval never` → ⚠️ No pedir (peligroso)

### Shortcut Flags
- `--full-auto` → Equivalente a `-a on-request --sandbox workspace-write`
- `--dangerously-bypass-approvals-and-sandbox` → ⚠️ Reemplazo de `--yolo`

## Available Skills

Use skills with profiles:
```bash
codex exec --profile security-audit -C /path/to/code \
  "Use security-review skill. [prompt]"
```

### Skills
- `security-review` - Security vulnerability analysis (use profile: security-audit)
- `bug-hunter` - Deep bug detection (use profile: bug-hunting)
- `test-generation` - Unit test creation (use profile: unit-tests)
- `ask-questions-if-underspecified` - Clarification before complex tasks

## Invocation Patterns (v0.79.0)

### Security Review
```bash
# v0.79.0: Profile + output schema + read-only sandbox
codex exec \
  --profile security-audit \
  --output-schema ~/.ralph/schemas/security-output.json \
  -C /path/to/code \
  "Use security-review skill. Analyze: $FILES"
```

### Bug Hunting
```bash
# v0.79.0: --full-auto convenience flag
codex exec \
  --full-auto \
  --output-schema ~/.ralph/schemas/bugs-output.json \
  --enable bug-hunter \
  -m gpt-5.2-codex \
  -C /path/to/code \
  "Use bug-hunter skill. Find bugs in: $FILES"
```

### Test Generation
```bash
# v0.79.0: Profile + full-auto
codex exec \
  --profile unit-tests \
  --full-auto \
  --output-schema ~/.ralph/schemas/tests-output.json \
  -C /path/to/code \
  "Use test-generation skill. Generate tests for: $FILES"
```

### Code Review (Native Command)
```bash
# v0.79.0: Native review command (Git-aware)
codex review \
  --base main \
  --uncommitted \
  --profile code-review \
  "Review changes for logic, performance, security"
```

## Output Format

With `--output-schema`, Codex MUST return validated JSON:

```json
{
  "vulnerabilities": [...],  // or "bugs", "tests"
  "summary": {
    "total": N,
    "approved": true|false
  }
}
```

## Integration with Ralph
- Called by Sonnet subagents via bash
- Results parsed and aggregated by orchestrator
- Schemas ensure consistent JSON structure
- Part of adversarial validation (2/3 consensus)

## Features (v0.79.0)

Check enabled features:
```bash
codex features list
```

Commonly used:
- `skills` (experimental) - Enable skill system
- `web_search_request` (stable) - Native web search
- `shell_snapshot` (beta) - Shell environment snapshots
- `unified_exec` (beta) - Unified execution model

## Migration from v2.33 to v2.34

### Breaking Changes
- ~~`--yolo`~~ → `--dangerously-bypass-approvals-and-sandbox`
- Global config now SAFE by default (`approval_policy=on-request`, `sandbox_mode=workspace-write`)
- Use profiles for specialized tasks

### Backward Compatibility
All existing commands work, but with safer defaults. To match old behavior:
```bash
codex exec --dangerously-bypass-approvals-and-sandbox ...
# OR use profile:
codex exec --profile ci-cd ...
```
