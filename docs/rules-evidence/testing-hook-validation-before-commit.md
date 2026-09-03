> Full text of the global rule ~/.claude/rules/proven/testing-hook-validation-before-commit.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# hook-validation-before-commit

Run validate-hooks.sh to verify all hooks produce valid JSON. Run pytest tests/test_hooks_*.py to verify format expectations. Never commit hooks that fail validation.

**Trigger**: Before committing changes to .claude/hooks/ or ~/.claude/hooks/  
**Domain**: testing  
**Confidence**: 1.0  
**Usage**: 507  
