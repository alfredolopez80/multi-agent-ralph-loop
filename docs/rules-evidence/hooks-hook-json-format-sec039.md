> Full text of the global rule ~/.claude/rules/proven/hooks-hook-json-format-sec039.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# hook-json-format-sec039

CRITICAL: Use correct JSON format per hook type. PostToolUse/PreToolUse/UserPromptSubmit hooks MUST use {"continue": true/false}. Stop hooks ONLY use {"decision": "approve"/"block"}. The string 'continue' is NEVER valid for the 'decision' field. Verify format against tests/HOOK_FORMAT_REFERENCE.md before committing.

**Trigger**: Writing or modifying Claude Code hooks that output JSON  
**Domain**: hooks  
**Confidence**: 1.0  
**Usage**: 81  
