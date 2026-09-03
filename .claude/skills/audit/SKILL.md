---
# VERSION: 3.0.0
name: audit
description: "Report token and query usage from the ralph usage logs. Use when: (1) /audit is invoked, (2) task relates to audit functionality."
user-invocable: true
context: fork
---

# /audit

Generate a usage report from the local ralph usage logs.

## Scope

Descriptive only. This skill reports what the session already consumed; it never selects,
recommends, or routes to a model or provider. The model is whatever the session runs — the
user picks it with `/model` or by naming it expressly.

## What it shows

- Total queries over the reporting period
- Token counts (input / output / total)
- Per-project usage breakdown
- Usage trends (daily / weekly)
- Where consumption concentrates, so the user can decide what to change

## Sources

Reads the local ralph usage logs under `~/.ralph/logs/` and `~/.ralph/metrics/`. Nothing is
sent anywhere; the report is produced from files already on disk.

## Execution

```bash
# Detailed audit report
ralph audit
```

## Example Output

```
=== Usage Audit ===
Period: Last 7 days

Queries:        75

Tokens:
  Input:        1,240,000
  Output:         310,000
  Total:        1,550,000

By project:
  multi-agent-ralph-loop   48 queries   1,020,000 tokens (66%)
  other-project            27 queries     530,000 tokens (34%)
```

If a log file is missing or unreadable, the report fails loudly and names the file rather than
reporting a zeroed section.
