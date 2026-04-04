---
# VERSION: 3.0.0
name: perf
description: "Performance optimization skill. Core Web Vitals via Lighthouse, bundle size analysis, metrics tracking over time. Use when: (1) optimizing frontend performance, (2) analyzing bundle size, (3) tracking metrics regression. Triggers: /perf, 'performance audit', 'core web vitals', 'bundle size'."
argument-hint: "<url or path>"
user-invocable: true
---

# Perf — Performance Optimization v3.0

Measure, analyze, and optimize performance.

## Actions

### `/perf audit <url>`

Run Lighthouse via `/browser-test` and extract performance metrics:
- LCP (Largest Contentful Paint) — target < 2.5s
- FID (First Input Delay) — target < 100ms
- CLS (Cumulative Layout Shift) — target < 0.1
- TTFB (Time to First Byte) — target < 800ms

### `/perf bundle <path>`

Analyze JavaScript bundle size:
- Total bundle size
- Per-chunk breakdown
- Tree-shaking opportunities
- Duplicate dependencies

### `/perf track`

Compare current metrics against previous run:
- Store results in `.claude/quality-results/perf/`
- Show delta (improved/regressed)
- Flag regressions as ADVISORY

## Integration

- `/browser-test` provides raw Lighthouse data
- `/gates` Stage 5 (BROWSER) includes perf checks
- `/ship` checklist includes perf audit

## Reference Checklist

See: `docs/reference/performance-checklist.md` (created with this skill)
