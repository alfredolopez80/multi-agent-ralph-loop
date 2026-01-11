---
name: checkpoint-list
prefix: "@cp-list"
category: tools
color: green
description: "List all saved checkpoints"
---

# /checkpoint list - List Checkpoints

Display all saved checkpoints with timestamps and descriptions.

## Usage

```bash
/checkpoint list
@checkpoint list
@cp-list
```

## Output Format

```
📋 Checkpoints (N total):

1. [YYYY-MM-DD HH:MM:SS] Description
2. [YYYY-MM-DD HH:MM:SS] Another description
...

⏱️  TTL: 24 hours (expired checkpoints are marked)
```

## Examples

```
📋 Checkpoints (3 total):

1. [2026-01-07 14:30:15] Pre-refactoring state
2. [2026-01-07 14:25:00] Before security audit
3. [2026-01-07 13:45:30] Initial setup

⏱️  TTL: 24 hours
```

## Related Commands

- `/checkpoint save` - Save a new checkpoint
- `/checkpoint restore` - Restore a checkpoint
- `/checkpoint clear` - Delete all checkpoints
