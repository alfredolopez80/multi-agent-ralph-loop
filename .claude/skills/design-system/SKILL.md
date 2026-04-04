---
# VERSION: 3.0.0
name: design-system
description: "Design system management for frontend agents. Actions: init (create DESIGN.md from template), load (inject into agent context), validate (check component compliance). Use when: (1) starting a frontend project, (2) generating UI components, (3) reviewing frontend code for design consistency. Triggers: /design-system, 'design system', 'create design', 'design tokens'."
argument-hint: "<action: init|load|validate> [options]"
user-invocable: true
---

# Design System Skill v3.0

Manage DESIGN.md files that frontend agents read to generate consistent UI.

## Actions

### `/design-system init`

Create a new DESIGN.md from the template:

1. Copy `docs/templates/DESIGN.md.template` to project root as `DESIGN.md`
2. Ask user for: project name, visual theme, primary color
3. Fill in template variables
4. Output: `DESIGN.md` ready for customization

```bash
/design-system init
# Creates DESIGN.md with 9 sections from template
```

### `/design-system load`

Load DESIGN.md into current context for frontend work:

1. Read `DESIGN.md` from project root (or specified path)
2. Extract design tokens as structured data
3. Inject into agent context as reference
4. Used automatically by orchestrator Step 3 (PLAN) for frontend tasks

```bash
/design-system load
# Loads DESIGN.md tokens into context
```

### `/design-system validate`

Check generated components against DESIGN.md:

1. Read DESIGN.md
2. Scan specified files for design token usage
3. Report violations: hardcoded colors, wrong spacing, missing states
4. Output: compliance report with fix suggestions

```bash
/design-system validate src/components/
# Checks all components against design system
```

## Integration Points

| Skill/Agent | How It Uses DESIGN.md |
|---|---|
| Orchestrator Step 3 | If task is frontend and DESIGN.md exists, include as context |
| ralph-frontend | Loads DESIGN.md before generating any component |
| /create-task-batch | Phase 1 asks about design system for frontend tasks |
| /gates Stage 5 | BROWSER validation checks design compliance (future) |

## Validation Checklist

The 9 required sections in every DESIGN.md:

1. Visual Theme
2. Color Palette (with CSS custom property tokens)
3. Typography (with font stack and scale)
4. Components (buttons, inputs, cards minimum)
5. Layout (grid, spacing scale, breakpoints)
6. Depth and Elevation
7. Do's and Don'ts
8. Responsive Behavior
9. Agent Prompt Guide

## Template

Source: `docs/templates/DESIGN.md.template`

Inspired by [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) — 55+ real-world DESIGN.md files.
