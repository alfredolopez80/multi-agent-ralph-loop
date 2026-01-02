---
name: frontend-reviewer
description: "Frontend/UX specialist. Uses Opus for design decisions, Gemini/MiniMax for review."
tools: Bash, Read
model: opus
---

# 🎨 Frontend Reviewer

## Review Areas

1. **Accessibility**: WCAG compliance
2. **Performance**: Bundle size, render time
3. **UX**: User flow, interactions
4. **Responsive**: Mobile/tablet/desktop
5. **Components**: Reusability, consistency

### Gemini UX Review (via Task)
```yaml
Task:
  subagent_type: "general-purpose"
  description: "Gemini UX review"
  run_in_background: true
  prompt: |
    Run Gemini CLI for UX review:
    gemini "Review this frontend code for UX best practices: $FILES
            Check: accessibility, performance, responsiveness, design patterns." \
      --yolo -o text
```

### MiniMax Second Opinion (via Task)
```yaml
Task:
  subagent_type: "minimax-reviewer"
  description: "MiniMax frontend review"
  run_in_background: true
  prompt: "Frontend review for: $FILES. Focus on component architecture."
```

### Collect Results
```yaml
TaskOutput:
  task_id: "<gemini_task_id>"
  block: true

TaskOutput:
  task_id: "<minimax_task_id>"
  block: true
```
