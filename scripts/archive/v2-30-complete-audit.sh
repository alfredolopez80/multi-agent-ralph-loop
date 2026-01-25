#!/bin/bash
# v2.30 Complete Audit Script
# Run this to verify full v2.30 implementation

echo "=========================================="
echo "v2.30 COMPLETE AUDIT"
echo "=========================================="
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "✅ $name"
        PASS=$((PASS + 1))
    else
        echo "❌ $name"
        FAIL=$((FAIL + 1))
    fi
}

# Skills (10 required)
[ -d ~/.claude/skills/context-monitor ] && check "context-monitor skill" "0" || check "context-monitor skill" "1"
[ -d ~/.claude/skills/checkpoint-manager ] && check "checkpoint-manager skill" "0" || check "checkpoint-manager skill" "1"
[ -d ~/.claude/skills/system-reminders ] && check "system-reminders skill" "0" || check "system-reminders skill" "1"
[ -d ~/.claude/skills/fresh-context-explorer ] && check "fresh-context-explorer skill" "0" || check "fresh-context-explorer skill" "1"
[ -d ~/.claude/skills/cc-codex-workflow ] && check "cc-codex-workflow skill" "0" || check "cc-codex-workflow skill" "1"
[ -d ~/.claude/skills/ralph-loop-pattern ] && check "ralph-loop-pattern skill" "0" || check "ralph-loop-pattern skill" "1"
[ -d ~/.claude/skills/model-selection ] && check "model-selection skill" "0" || check "model-selection skill" "1"
[ -d ~/.claude/skills/tool-selection ] && check "tool-selection skill" "0" || check "tool-selection skill" "1"
[ -d ~/.claude/skills/workflow-patterns ] && check "workflow-patterns skill" "0" || check "workflow-patterns skill" "1"
[ -d ~/.claude/skills/security-patterns ] && check "security-patterns skill" "0" || check "security-patterns skill" "1"

echo ""
echo "Hooks (3 required):"
[ -f ~/.claude/hooks/context-warning.sh ] && check "context-warning.sh" "0" || check "context-warning.sh" "1"
[ -f ~/.claude/hooks/periodic-reminder.sh ] && check "periodic-reminder.sh" "0" || check "periodic-reminder.sh" "1"
[ -f ~/.claude/hooks/checkpoint-auto-save.sh ] && check "checkpoint-auto-save.sh" "0" || check "checkpoint-auto-save.sh" "1"

echo ""
echo "Commands (4 required):"
[ -f ~/.claude/commands/checkpoint-save.md ] && check "checkpoint-save command" "0" || check "checkpoint-save command" "1"
[ -f ~/.claude/commands/checkpoint-list.md ] && check "checkpoint-list command" "0" || check "checkpoint-list command" "1"
[ -f ~/.claude/commands/checkpoint-restore.md ] && check "checkpoint-restore command" "0" || check "checkpoint-restore command" "1"
[ -f ~/.claude/commands/checkpoint-clear.md ] && check "checkpoint-clear command" "0" || check "checkpoint-clear command" "1"

echo ""
echo "Config Files:"
[ -f ~/.ralph/checkpoint-config.json ] && check "checkpoint-config.json" "0" || check "checkpoint-config.json" "1"

echo ""
echo "CLAUDE.md:"
CLAUDE_LINES=$(wc -l < ~/.claude/CLAUDE.md 2>/dev/null)
if [ "$CLAUDE_LINES" -lt 200 ]; then
    check "CLAUDE.md reduced ($CLAUDE_LINES lines)" "0"
else
    check "CLAUDE.md reduced ($CLAUDE_LINES lines)" "1"
fi

echo ""
echo "=========================================="
echo "RESULT: $PASS PASSED, $FAIL FAILED"
echo "=========================================="

if [ $FAIL -eq 0 ]; then
    echo "✅ v2.30 FULLY IMPLEMENTED"
    exit 0
else
    echo "⚠️ v2.30 HAS $FAIL MISSING COMPONENTS"
    exit 1
fi
