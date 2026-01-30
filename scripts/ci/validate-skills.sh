#!/usr/bin/env bash
# validate-skills.sh - CI skill validation
set -euo pipefail

SKILLS_DIR="${1:-.claude/skills}"
ERRORS=0

echo "🔍 Validating skills in $SKILLS_DIR..."

for skill_dir in "$SKILLS_DIR"/*/; do
    if [ ! -d "$skill_dir" ]; then continue; fi
    
    skill_name=$(basename "$skill_dir")
    echo -n "  Checking $skill_name... "
    
    # Check SKILL.md exists
    if [ ! -f "${skill_dir}SKILL.md" ]; then
        echo "❌ Missing SKILL.md"
        ((ERRORS++))
        continue
    fi
    
    # Check SKILL.md has frontmatter
    if ! head -5 "${skill_dir}SKILL.md" | grep -q "^---"; then
        echo "⚠️  Missing frontmatter"
    fi
    
    echo "✅"
done

if [ $ERRORS -gt 0 ]; then
    echo "❌ Found $ERRORS errors"
    exit 1
fi

echo "✅ All skills validated successfully"
