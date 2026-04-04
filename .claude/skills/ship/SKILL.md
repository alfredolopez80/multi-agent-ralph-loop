---
# VERSION: 3.0.0
name: ship
description: "Pre-launch shipping checklist orchestrating /gates, /security, /browser-test, /perf. Ensures nothing ships without passing all quality checks. Use when: (1) before deploying, (2) before merging to main, (3) before release. Triggers: /ship, 'ship it', 'ready to deploy', 'pre-launch check'."
argument-hint: "[--skip-browser]"
user-invocable: true
---

# Ship — Pre-Launch Checklist v3.0

Orchestrate all quality checks before shipping.

## Checklist

```
SHIP CHECKLIST
==============
[ ] 1. /gates          — All 4 stages pass (correctness, quality, security, consistency)
[ ] 2. /security       — No critical/high vulnerabilities
[ ] 3. /browser-test   — No console errors, Lighthouse > 90 (if frontend)
[ ] 4. /perf audit     — Core Web Vitals in target range (if frontend)
[ ] 5. Git status      — No uncommitted changes
[ ] 6. Tests           — All tests pass
[ ] 7. ADR             — Major decisions documented (if complexity >= 7)
[ ] 8. Spec            — Exit criteria met (if spec exists)
```

## Usage

```bash
/ship                    # Run full checklist
/ship --skip-browser     # Skip browser tests (backend-only)
```

## Behavior

1. Run each check sequentially
2. BLOCKING checks (1-2): must pass to ship
3. ADVISORY checks (3-8): reported but don't block
4. Output: summary with PASS/FAIL per check

## Anti-Rationalization

| Excuse | Rebuttal |
|---|---|
| "It's just a small change" | Small changes cause big outages. Run the checklist. |
| "I already tested manually" | Manual testing misses what automated checks catch. |
| "The deadline is tight" | Shipping broken code costs more time than the checklist. |
