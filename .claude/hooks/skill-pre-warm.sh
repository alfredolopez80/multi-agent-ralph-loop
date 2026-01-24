#!/bin/bash
# Skill Pre-Warm Hook (v2.57.5)
# Hook: SessionStart
# Purpose: Pre-load frequently used skills into memory for faster access
#
# This hook identifies and pre-validates commonly used skills so they're
# ready to use immediately without validation delay on first invocation.
#
# VERSION: 2.68.2
# CRITICAL: Closes GAP-003 - Missing skill pre-load mechanism

set -euo pipefail
umask 077

# Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Configuration
SKILLS_DIR="${HOME}/.claude/skills"
SKILL_CACHE="${HOME}/.ralph/config/skill-cache.json"
LOG_FILE="${HOME}/.ralph/logs/skill-prewarm.log"
PREWARM_COUNT=10

# Logging
log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get list of frequently used skills from cache
get_frequent_skills() {
    local cache_file="$SKILL_CACHE"

    if [[ ! -f "$cache_file" ]]; then
        # Default skills to pre-warm if no cache exists
        echo "loop"
        echo "memory"
        echo "orchestrator"
        echo "gates"
        echo "security"
        echo "codex-cli"
        echo "curator"
        echo "repository-learner"
        echo "test-driven-development"
        echo "systematic-debugging"
        return
    fi

    # Read from cache - get top skills
    jq -r '.frequent_skills // [] | .[0:'"$PREWARM_COUNT"'] | .[]' "$cache_file" 2>/dev/null || \
        echo "loop memory orchestrator gates security codex-cli"
}

# Pre-warm a single skill
# GAP-SKILL-001 FIX v2.57.8: Claude Code skills use SKILL.md with YAML frontmatter, not skill.yaml
prewarm_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"

    if [[ ! -d "$skill_dir" ]]; then
        log "Skill not found: $skill_name"
        return 1
    fi

    # GAP-SKILL-001 FIX: Check for SKILL.md or skill.md (Claude Code format)
    local skill_file=""
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        skill_file="$skill_dir/SKILL.md"
    elif [[ -f "$skill_dir/skill.md" ]]; then
        skill_file="$skill_dir/skill.md"
    elif [[ -f "$skill_dir/instruction.md" ]]; then
        skill_file="$skill_dir/instruction.md"
    else
        log "No skill file for: $skill_name"
        return 1
    fi

    # Quick validation: extract YAML frontmatter and check for 'name'
    # Claude Code skills use --- delimited frontmatter
    # GAP-SKILL-001 FIX: Use single quotes for Python, double quotes for strings inside
    if python3 -c '
import sys, yaml
f = open(sys.argv[1])
c = f.read()
f.close()
if c[:3] == "---":
    p = c.split("---", 2)
    if len(p) >= 3:
        d = yaml.safe_load(p[1])
        if d and "name" in d:
            sys.exit(0)
sys.exit(1)
' "$skill_file" 2>/dev/null; then
        log "Pre-warmed: $skill_name"
        return 0
    else
        log "Validation failed: $skill_name"
        return 1
    fi
}

# Main pre-warm logic
prewarm_skills() {
    local start_time
    start_time=$(date +%s)
    local skills_prewarmed=0
    local skills_failed=0

    log "Starting skill pre-warm"

    # Get skills to pre-warm
    local skills
    skills=$(get_frequent_skills)

    if [[ -z "$skills" ]]; then
        log "No skills to pre-warm"
        echo '{"continue": true}'
        exit 0
    fi

    # Pre-warm each skill
    # GAP-SKILL-001 FIX: Add || true to prevent set -e from killing script on ((0++))
    while IFS= read -r skill; do
        [[ -z "$skill" ]] && continue

        if prewarm_skill "$skill"; then
            ((skills_prewarmed++)) || true
        else
            ((skills_failed++)) || true
        fi
    done <<< "$skills"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log "Pre-warm complete: $skills_prewarmed succeeded, $skills_failed failed in ${duration}s"

    # Output summary
    jq -n \
        --argjson prewarmed "$skills_prewarmed" \
        --argjson failed "$skills_failed" \
        --arg duration "${duration}s" \
        '{
            continue: true,
            skill_prewarm: {
                prewarmed_count: $prewarmed,
                failed_count: $failed,
                duration: $duration,
                timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            }
        }'
}

# Run on SessionStart
if [[ -d "$SKILLS_DIR" ]]; then
    prewarm_skills
else
    echo '{"continue": true}'
fi
