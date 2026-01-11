---
name: checkpoint-clear
prefix: "@cp-clear"
category: tools
color: green
description: "Clear all saved checkpoints"
---

# /checkpoint clear - Clear Checkpoints

Delete all saved checkpoints. Requires confirmation.

## Usage

```bash
/checkpoint clear
@checkpoint clear
@cp-clear
```

## Confirmation

```
⚠️  This will delete ALL checkpoints (N total).

Are you sure? Type 'yes' to confirm:
```

## Examples

```
⚠️  This will delete ALL checkpoints (3 total):

1. [2026-01-07 14:30:15] Pre-refactoring state
2. [2026-01-07 14:25:00] Before security audit
3. [2026-01-07 13:45:30] Initial setup

Are you sure? Type 'yes' to confirm: yes

🗑️  Deleting checkpoints...
✅ All checkpoints cleared (3 deleted)
```

## Options

### Force Clear (No Confirmation)

```bash
# Add --force or -f flag
/checkpoint clear --force
```

## Related Commands

- `/checkpoint save` - Save a new checkpoint
- `/checkpoint list` - List all checkpoints
- `/checkpoint restore` - Restore a checkpoint
