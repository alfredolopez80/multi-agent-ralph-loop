---
# VERSION: 3.0.0
name: browser-test
description: "Browser testing using Chrome DevTools MCP and Playwright for visual verification. Start dev server, navigate, screenshot, Lighthouse audit, console errors, network check. Use when: (1) verifying frontend changes, (2) accessibility auditing, (3) performance testing, (4) visual regression. Triggers: /browser-test, 'test in browser', 'visual test', 'lighthouse audit'."
argument-hint: "<url>"
user-invocable: true
---

# Browser Test v3.0

Visual verification using Chrome DevTools MCP and Playwright.

## Quick Start

```bash
/browser-test http://localhost:3000
/browser-test http://localhost:3000 --a11y
/browser-test http://localhost:3000 --perf
```

## Workflow

### 1. Start Dev Server (if needed)

```bash
# Auto-detect package manager and start
npm run dev &  # or yarn dev, bun dev
# Wait for server to be ready
```

### 2. Navigate and Screenshot

Using Playwright MCP or Chrome DevTools:
- Navigate to URL
- Take full-page screenshot
- Save to `.claude/quality-results/screenshots/`

### 3. Console Errors Check

- Capture all console messages (errors, warnings)
- Flag any errors as BLOCKING
- Flag warnings as ADVISORY

### 4. Lighthouse Audit

Run via Chrome DevTools MCP:
- Performance score (target: > 90)
- Accessibility score (target: > 90)
- Best Practices score (target: > 90)
- SEO score (target: > 90)

### 5. Network Check

- Verify no failed requests (4xx, 5xx)
- Check for oversized assets (> 500KB)
- Verify no mixed content (HTTP on HTTPS)

## Output Format

```
Browser Test Report — http://localhost:3000
=============================================
Screenshot: .claude/quality-results/screenshots/2026-04-04-home.png
Console: 0 errors, 2 warnings
Lighthouse: Perf 94 | A11y 98 | BP 100 | SEO 92
Network: 23 requests, 0 failed, largest: 145KB
---------------------------------------------
RESULT: PASS (0 blocking, 2 advisory)
```

## Integration Points

| Skill | How |
|---|---|
| /gates Stage 5 | BROWSER validation (advisory for frontend) |
| Orchestrator Step 7 | Include browser testing for frontend tasks |
| ralph-frontend | Invoke via skill, not via MCP directly |

## Accessibility Audit Mode (`--a11y`) (v3.0 — Item 13)

```bash
/browser-test http://localhost:3000 --a11y
```

Runs axe-core via Lighthouse accessibility audit:
- WCAG 2.1 AA compliance check
- Color contrast violations
- Missing alt text, labels, ARIA roles
- Keyboard navigation traps
- Focus management issues

Output blocked in ralph-frontend quality gate when score < 90.

Reference: `docs/reference/accessibility-checklist.md`

## Visual Regression Mode (v3.0 — Item 14)

Screenshots saved to `.claude/quality-results/screenshots/` with timestamp.

For visual comparison between runs:
```bash
# Compare current vs previous screenshot
mcp__zai-mcp-server__ui_diff_check(before_image, after_image)
```

Screenshots are gitignored (`.claude/quality-results` in .gitignore).

## Anti-Rationalization

| Excuse | Rebuttal |
|---|---|
| "It looks fine in the code" | Visual bugs are invisible in code review. Test in browser. |
| "Lighthouse is too strict" | Lighthouse catches real user experience issues. |
| "Console warnings don't matter" | Warnings become errors in strict mode and for users. |
| "Accessibility is for later" | WCAG 2.1 AA is mandatory, not optional. |
