# Quality Gates Documentation

Documentation for the quality validation system used in Multi-Agent Ralph Loop.

## Overview

The quality gates system ensures all implementations meet strict standards for correctness, security, and code quality before being approved.

## Documents

| File | Description |
|------|-------------|
| [CODEX_VALIDATION_COMPLETE.md](CODEX_VALIDATION_COMPLETE.md) | Codex validation completion report |
| [CODEX_VALIDATION_SUMMARY.md](CODEX_VALIDATION_SUMMARY.md) | Codex validation summary |
| [PLAN_STATE_VALIDATION.md](PLAN_STATE_VALIDATION.md) | Plan state validation report |

## Quality Stages

### Stage 1: CORRECTNESS (BLOCKING)
- Syntax errors
- Logic errors
- Requirements compliance

### Stage 2: QUALITY (BLOCKING)
- Type errors
- Security vulnerabilities
- Test coverage

### Stage 3: CONSISTENCY (ADVISORY)
- Code style
- Pattern adherence
- Documentation

## Adversarial Validation

For complexity >= 7, implementations undergo adversarial validation:
- **Claude Opus**: Independent review
- **Codex GPT-5.2**: Independent review
- **Reconciliation**: Merge agreements, flag disagreements

## Related Documentation

- [../adversarial/](../adversarial/) - Adversarial validation system
- [../audits/](../audits/) - Audit reports and findings
