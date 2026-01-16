---
# VERSION: 2.43.0
name: checkpoint-restore
prefix: "@cp-restore"
category: tools
color: green
description: "Restore session state from a checkpoint"
---

# /checkpoint restore - Restore Checkpoint

Restore the session state from a previously saved checkpoint.

## Usage

```bash
/checkpoint restore <id>
@checkpoint restore 3
@cp-restore 2
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `id` | Checkpoint number from `/checkpoint list` |

## Examples

```bash
# Restore checkpoint #1
/checkpoint restore 1

# Restore checkpoint #3
@checkpoint restore 3
```

## Output

```
♻️  Restoring checkpoint: cp_20260107_143015_pre-refactoring
📁 Directory: /path/to/project
📝 Files modified: src/main.py, src/utils.py

✅ Checkpoint restored successfully!
```

## Safety Check

Before restore, the skill will:
1. Warn about unsaved changes
2. Confirm the checkpoint ID
3. Suggest backing up current state

## Related Commands

- `/checkpoint save` - Save a new checkpoint
- `/checkpoint list` - List all checkpoints
- `/checkpoint clear` - Delete all checkpoints
