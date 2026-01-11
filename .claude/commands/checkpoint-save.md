---
name: checkpoint-save
prefix: "@cp"
category: tools
color: green
description: "Save current session state to a checkpoint"
---

# /checkpoint save - Save Checkpoint

Save the current session state to a named checkpoint.

## Usage

```bash
/checkpoint save "Description of state"
@checkpoint save "Description"
@cp "Pre-refactoring state"
```

## Description

Creates a checkpoint of the current session including:
- Current working directory
- Recent file modifications
- Task context

## Examples

```bash
/checkpoint save "Before refactoring authentication"
```

## Output

```
✅ Checkpoint saved: cp_20260107_143015_before-refactoring-authentication
📁 Location: ~/.ralph/checkpoints/cp_20260107_143015.json
⏱️  Expires: 24 hours (2026-01-08 14:30:15)
```

## Related Commands

- `/checkpoint list` - View all checkpoints
- `/checkpoint restore` - Restore a checkpoint
- `/checkpoint clear` - Delete all checkpoints
