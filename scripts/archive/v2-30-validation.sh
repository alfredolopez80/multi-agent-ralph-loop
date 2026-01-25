#!/bin/bash
# v2.30 Validation Audit Script
# This script runs a comprehensive audit of all v2.30 changes

AUDIT_DIR="${HOME}/Documents/claude-audit/v2-30"
LOG_FILE="${AUDIT_DIR}/audit-results.md"

echo "# v2.30 Context Engineering - Validation Audit" > "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "**Audit Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Function to check if file exists
check_file() {
    local file="$1"
    local description="$2"
    if [ -f "$file" ]; then
        echo "✅ **$description**: EXISTS" >> "$LOG_FILE"
        return 0
    else
        echo "❌ **$description**: MISSING" >> "$LOG_FILE"
        return 1
    fi
}

# Function to check if directory exists
check_dir() {
    local dir="$1"
    local description="$2"
    if [ -d "$dir" ]; then
        echo "✅ **$description**: EXISTS ($(ls -1 "$dir" 2>/dev/null | wc -l) items)" >> "$LOG_FILE"
        return 0
    else
        echo "❌ **$description**: MISSING" >> "$LOG_FILE"
        return 1
    fi
}

# ============================================================================
# FASE 1: Context Monitoring Hook
# ============================================================================
echo "## Fase 1: Context Monitoring Hook" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

check_file "$AUDIT_DIR/context-monitor/SKILL.md" "Context Monitor Skill" && \
check_file "$AUDIT_DIR/context-monitor/README.md" "Context Monitor README" && \
check_file "$AUDIT_DIR/context-warning.sh" "Context Warning Hook" && \
echo "   - SKILL.md: $(wc -l < "$AUDIT_DIR/context-monitor/SKILL.md") lines" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"

# ============================================================================
# FASE 2: Auto-Checkpointing
# ============================================================================
echo "## Fase 2: Auto-Checkpointing" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

check_dir "$AUDIT_DIR/checkpoint-manager" "Checkpoint Manager Skill" && \
check_file "$AUDIT_DIR/checkpoint-manager/SKILL.md" "Checkpoint Manager Skill" && \
check_file "$AUDIT_DIR/checkpoint-manager/README.md" "Checkpoint Manager README" && \
check_file "$AUDIT_DIR/checkpoint-save.md" "Checkpoint Save Command" && \
check_file "$AUDIT_DIR/checkpoint-list.md" "Checkpoint List Command" && \
check_file "$AUDIT_DIR/checkpoint-restore.md" "Checkpoint Restore Command" && \
check_file "$AUDIT_DIR/checkpoint-clear.md" "Checkpoint Clear Command" && \
echo "   - SKILL.md: $(wc -l < "$AUDIT_DIR/checkpoint-manager/SKILL.md") lines" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"

# ============================================================================
# FASE 3: CLAUDE.md Split
# ============================================================================
echo "## Fase 3: CLAUDE.md Split" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

CLAUDE_LINES=$(wc -l < "$AUDIT_DIR/CLAUDE.md" 2>/dev/null || echo "0")
if [ "$CLAUDE_LINES" -lt 200 ]; then
    echo "✅ **CLAUDE.md**: REDUCED ($CLAUDE_LINES lines, target: <200)" >> "$LOG_FILE"
else
    echo "⚠️ **CLAUDE.md**: Still large ($CLAUDE_LINES lines, target: <200)" >> "$LOG_FILE"
fi

check_dir "$AUDIT_DIR/ralph-loop-pattern" "Ralph Loop Pattern Skill"
check_dir "$AUDIT_DIR/model-selection" "Model Selection Skill"
check_dir "$AUDIT_DIR/tool-selection" "Tool Selection Skill"
check_dir "$AUDIT_DIR/workflow-patterns" "Workflow Patterns Skill"
check_dir "$AUDIT_DIR/security-patterns" "Security Patterns Skill"

echo "" >> "$LOG_FILE"

# ============================================================================
# FASE 4: System Reminders
# ============================================================================
echo "## Fase 4: System Reminders" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

check_dir "$AUDIT_DIR/system-reminders" "System Reminders Skill" && \
check_file "$AUDIT_DIR/system-reminders/SKILL.md" "System Reminders Skill" && \
check_file "$AUDIT_DIR/system-reminders/README.md" "System Reminders README" && \
check_file "$AUDIT_DIR/periodic-reminder.sh" "Periodic Reminder Hook" && \
echo "   - SKILL.md: $(wc -l < "$AUDIT_DIR/system-reminders/SKILL.md") lines" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"

# ============================================================================
# FASE 5: Fresh Context Explorer
# ============================================================================
echo "## Fase 5: Fresh Context Explorer" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

check_dir "$AUDIT_DIR/fresh-context-explorer" "Fresh Context Explorer Skill" && \
check_file "$AUDIT_DIR/fresh-context-explorer/SKILL.md" "Fresh Context Explorer Skill" && \
check_file "$AUDIT_DIR/fresh-context-explorer/README.md" "Fresh Context Explorer README" && \
echo "   - SKILL.md: $(wc -l < "$AUDIT_DIR/fresh-context-explorer/SKILL.md") lines" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"

# ============================================================================
# FASE 6: Esc+Esc Documentation
# ============================================================================
echo "## Fase 6: Esc+Esc Documentation" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

if grep -q "Esc+Esc" "$AUDIT_DIR/CLAUDE.md"; then
    echo "✅ **Esc+Esc Documentation**: EXISTS in CLAUDE.md" >> "$LOG_FILE"
else
    echo "❌ **Esc+Esc Documentation**: MISSING from CLAUDE.md" >> "$LOG_FILE"
fi

if grep -q "checkpoint" "$AUDIT_DIR/CLAUDE.md"; then
    echo "✅ **Checkpoint Documentation**: EXISTS in CLAUDE.md" >> "$LOG_FILE"
else
    echo "❌ **Checkpoint Documentation**: MISSING from CLAUDE.md" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# ============================================================================
# FASE 7: CC + Codex Workflow
# ============================================================================
echo "## Fase 7: CC + Codex Workflow" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

check_dir "$AUDIT_DIR/cc-codex-workflow" "CC + Codex Workflow Skill" && \
check_file "$AUDIT_DIR/cc-codex-workflow/SKILL.md" "CC + Codex Workflow Skill" && \
check_file "$AUDIT_DIR/cc-codex-workflow/README.md" "CC + Codex Workflow README" && \
echo "   - SKILL.md: $(wc -l < "$AUDIT_DIR/cc-codex-workflow/SKILL.md") lines" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"

# ============================================================================
# Summary
# ============================================================================
echo "## Summary" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

TOTAL_SKILLS=$(ls -d "$AUDIT_DIR"/*/ 2>/dev/null | wc -l)
TOTAL_HOOKS=$(ls -f "$AUDIT_DIR"/*.sh 2>/dev/null | wc -l)
TOTAL_COMMANDS=$(ls -f "$AUDIT_DIR"/*.md 2>/dev/null | wc -l)

echo "**Total Skills**: $TOTAL_SKILLS" >> "$LOG_FILE"
echo "**Total Hooks**: $TOTAL_HOOKS" >> "$LOG_FILE"
echo "**Total Commands**: $TOTAL_COMMANDS" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "**Files Created**: $(find "$AUDIT_DIR" -type f | wc -l)" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
echo "*Audit completed at $(date -u +"%Y-%m-%d %H:%M:%S UTC")*" >> "$LOG_FILE"

# Display results
cat "$LOG_FILE"
