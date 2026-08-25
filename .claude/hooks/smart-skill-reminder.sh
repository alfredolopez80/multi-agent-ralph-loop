#!/bin/bash
#!/usr/bin/env bash
#===============================================================================
# Smart Skill Reminder Hook — RETIRED
# PreToolUse hook - filesystem-derived skill suggestions BEFORE writing code
#===============================================================================
#
# STATUS: RETIRED. NOT REGISTERED in ~/.claude/settings.json. DO NOT RE-REGISTER.
#
# Lead's desregistro is the canonical state. Re-registering this hook
# without reading this header would re-introduce a no-op that consumes
# tokens and produces nothing. Read the three nails below first.
#
# WHY RETIRED (T49 / T52, 2026-08-25) — three independent nails, each
# sufficient on its own:
#
# 1. additionalContext not honored in PreToolUse.
#    v2.69.0 emitted additionalContext. zc verified empirically across
#    250 sessions and 1.343 hook invocations on this machine: 0 deliveries.
#    The mechanism was a no-op from day one. tests/HOOK_FORMAT_REFERENCE.md
#    lists additionalContext as "optional" but the PreToolUse validation
#    function only checks for continue or permissionDecision.
#
# 2. permissionDecisionReason for allow has no slot.
#    v3.0.0 switched to {"permissionDecision":"allow",
#    "permissionDecisionReason":"..."}. zc verified: 0 of 25 cases where
#    the reason reached the model. The reason: a PreToolUse `allow`
#    executes the tool, and the tool_result IS the visible output.
#    There is no physical slot in the harness where the reason lands
#    before the model sees the next turn. The field is honored only for
#    deny (the model needs the reason to understand the block); for allow
#    there is no functional requirement and no implementation.
#
# 3. Matching by generic extension produces alphabetical selection, not
#    relevance. v3.0.0 matched file extensions from the description
#    (".py", ".ts", etc.) as a substring of the file path. With 60+
#    skills, every `.py` edit would match every skill whose description
#    mentions `.py`. The effective selector was the order of the file
#    walk, which is alphabetical — not the skill's relevance to the
#    task. A selector that decides by alphabetical order is not a
#    selector; it is a noise generator with a 30-minute cooldown.
#
# WHAT REPLACES IT
# The skill catalog is already in the model's context. mmx-2's lint
# ensures it stays in sync with the filesystem (check #4 of T54: no hook
# references a skill that doesn't have its SKILL.md). The catalog is a
# better guide than any substring-based suggestion could be: it has all
# 246 skills with descriptions, costs 19,705 tokens already paid, and
# the model can match its own context. A 1.5k-token / 1-emission / 30-min
# substring selector added nothing the catalog didn't already cover.
#
# WHY THE FILE IS STILL HERE
# Lead's explicit instruction: "NO lo borres del disco; déjalo con una
# nota de cabecera diciendo que está retirado, por qué (los tres clavos,
# con las cifras), y que el catálogo en contexto lo sustituye. Que el
# próximo que lo encuentre no reviva la idea sin leer esto." This header
# is that note. The body below is a NO-OP; the v3.0.0 functional body
# was removed so the 13 names exist ONLY in the prose above (the lint
# ignores comments; the lint would NOT have ignored the executable
# body that referenced them). The file exists so the next reader sees
# this note before re-registering.
#
# IF YOU'RE READING THIS AND THINKING "MAYBE I CAN MAKE IT WORK"
# 1. additionalContext: the docs say optional; the validation ignores
#    it; the harness has no slot for it. Three independent failures.
# 2. permissionDecisionReason + allow: no slot in the tool_result flow.
#    Verified, not a guess.
# 3. Extension matching: the index order IS the selector. Even if the
#    channel delivered, the suggestion would be alphabetical noise.
# Any of the three is fatal. Build something different.
#
# Useful artifact kept on disk: the v3.0.0 build process and tests
# (tests/test_smart_skill_reminder_v3.sh) — those demonstrated the
# enumerator works (the build-skill-index.sh piece survived as the
# mmx-2 lint enumerator in T52). The hook itself does not.

# ----------------------------------------------------------------------------
# NO-OP BODY. Replaces the v3.0.0 functional code. The hook is retired.
# The only thing this body does is consume stdin (SEC-111) and emit
# the empty allow. No skill names referenced in code. The lint check
# for "skill reference without SKILL.md" passes trivially.
# ----------------------------------------------------------------------------

# SEC-111: limit input size (DoS protection — keep the existing pattern).
head -c 100000 >/dev/null

# Empty allow. Same shape every PreToolUse hook outputs. 22 tokens.
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'