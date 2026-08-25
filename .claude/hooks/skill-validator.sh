#!/usr/bin/env bash
umask 077
# skill-validator.sh - Validate YAML-based skills before execution
# Hook: PreToolUse (Skill)
# v2.62.3 - Part of lightweight skills system (H70-inspired)
#
# This hook runs on PreToolUse/Skill to validate:
# - YAML structure and syntax
# - Required fields (name, version, category, role)
# - Regex patterns in validations and sharp-edges
# - File references (validations_ref, sharp_edges_ref, collaboration_ref)
# - Collaboration rules integrity
# Output: {"decision": "allow"} or {"decision": "block", "reason": "..."}

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


# VERSION: 2.84.3
# T48 (#68): HOT SECURITY GATE on the invoked skill's SKILL.md. Six deterministic
#          patterns (invisible unicode, base64+exec, exfil IOCs, pipe-to-shell,
#          secret literals, quote-aware override), context-awareness as a
#          REQUIREMENT (macos-cleaner is the regression fixture: it matches the
#          attack patterns while TEACHING the defense), and an auditable
#          allowlist (entry without a written reason is invalid; an entry that
#          matches no current finding is reported stale). COST CONTRACT: allow
#          adds NOTHING to the context — no code path emits additionalContext;
#          only deny carries a reason. DELIBERATELY OUT OF SCOPE: semantically
#          written injection (SkillJect, arXiv 2602.14211, fragments payloads
#          past regex); promising coverage we lack breeds unfounded confidence.
#          That belongs to the periodic corpus lint (T47 report in results/).
#          Recommended registration: PreToolUse matcher "Skill" (both T47 and
#          the selection design converged on this independently).
# T44 (#67): nameless invocations are the NORMAL case, not an error. The live
#          registration is PreToolUse Agent|Task — a payload that never carries
#          a skill name — so every Task/Agent launch logged "No skill name
#          provided" as ERROR: 4,693 of 4,786 log lines over 8 months, drowning
#          the 93 real validation lines (all from manual {"skill": ...} calls in
#          January). As a REGISTERED hook the validator never validated
#          anything. Three fixes: (1) nameless input now exits silently —
#          nothing is wrong, there is just nothing to validate; (2) the name is
#          read from tool_input.skill first (the field a real PreToolUse
#          Skill event carries), falling back to the root-level "skill" of
#          manual invocations; (3) a name that resolves to no skill.yaml is
#          OUT OF DOMAIN (the ecosystem migrated to SKILL.md; the two live
#          skill.yaml files sit in ~/.ralph/skills while SKILLS_DIR points at
#          ~/.claude/skills, so the effective domain was empty) — allowed with
#          an informational line, because denying would veto every modern
#          skill the day the registration is pointed at the Skill tool. A
#          PRESENT but invalid skill.yaml remains the violation this gate
#          exists for and still denies.
# v2.68.9: SEC-103 FIX - Use sys.argv for file path instead of string interpolation
# v2.68.2: FIX CRIT-004b - Only set trap when not sourced to prevent subshell JSON duplication
# v2.68.1: FIX CRIT-004 - Clear EXIT trap before explicit JSON output to prevent duplicate JSON
set -euo pipefail

# Error trap: Only set when running directly (not when sourced by timeout subshell)
# This prevents duplicate JSON from nested bash invocations
# v2.87.0 FIX: Use hookSpecificOutput wrapper for PreToolUse hooks
# BUG-3: `trap ... ERR EXIT` emitted twice. Under `set -e` a failing command
# fires ERR (emits JSON) and then EXIT (emits again); stdout then carried two
# concatenated objects and Claude Code rejected the payload with
# "Hook JSON output validation failed - (root): Invalid input", which a
# PreToolUse hook reports as a block. emit_json makes emission idempotent, and
# every `trap -` clears ERR as well as EXIT.
readonly DEFAULT_HOOK_JSON='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
_HOOK_EMITTED=0
emit_json() {
    [ "${_HOOK_EMITTED}" -eq 1 ] && return 0
    _HOOK_EMITTED=1
    printf '%s\n' "${1:-$DEFAULT_HOOK_JSON}"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap 'emit_json' ERR EXIT

    # T62 (#72): empty stdin is the deterministic "nothing to validate"
    # case. The old path died at the JSON extraction under set -e (rc 1)
    # and the ERR trap emitted the allow BY ACCIDENT — fail-open by crash.
    # The contract is now explicit and deliberate: this validator FAILS
    # OPEN BY DESIGN — a bug here must not take down the skill system
    # (permission-guard covers unparseable payloads) — with a clean exit 0,
    # never by crashing. NOTE: inside the run-directly guard — validate_skill
    # sources this file with stdin already drained, and a top-level copy of
    # this block made the inner process emit a SECOND allow (double JSON).
    if [[ -z "$INPUT" ]]; then
        trap - ERR EXIT
        emit_json '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
        exit 0
    fi
fi

# Configuration
SKILLS_DIR="${HOME}/.claude/skills"
LOG_FILE="${HOME}/.ralph/skill-validation.log"
# T44: on a clean HOME the log directory does not exist and every log line
# silently vanished (|| true swallowed it) — validations ran with no trace.
# Same pattern as repo-boundary-guard.sh.
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
VALIDATION_TIMEOUT=10
# T48 (#68): the allowlist lives next to the hook. Format (one entry per line):
#   <skill-name> <pattern-id>[,<pattern-id>...] # <reason — MANDATORY>
# An entry without a written reason is INVALID: ignored and logged as an error
# (fail-closed — the skill is NOT exempted). An entry whose pattern-id matches
# no current finding for that skill is logged as stale, so the list cannot rot.
ALLOWLIST_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skill-validator.allowlist"

# Security: Sanitize skill name to prevent command injection
# Only allow alphanumeric, hyphens, underscores, and dots
sanitize_skill_name() {
    local name="$1"
    # Remove any character that's not alphanumeric, hyphen, underscore, or dot
    echo "$name" | tr -cd 'a-zA-Z0-9_.-'
}

# Logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_FILE"
    # v2.69.0: Removed stderr output (causes hook error warnings in UI)
    # echo "❌ Skill Validation Error: $*" - now only logged to file
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*" >> "$LOG_FILE"
    # v2.69.0: Removed stderr output (causes hook error warnings in UI)
    # echo "⚠️  Warning: $*" - now only logged to file
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*" >> "$LOG_FILE"
    # v2.69.0: Removed stderr output (causes hook error warnings in UI)
    # echo "✅ $*" - now only logged to file
}

# Validate YAML syntax using Python
# SEC-103 FIX: Pass file path via sys.argv to prevent code injection
validate_yaml_syntax() {
    local file="$1"

    if ! python3 -c '
import yaml
import sys
try:
    with open(sys.argv[1], "r") as f:
        yaml.safe_load(f)
    sys.exit(0)
except yaml.YAMLError as e:
    # v2.69.0: Print to stdout (captured by 2>&1) instead of stderr directly
    print(f"YAML syntax error: {e}")
    sys.exit(1)
except Exception as e:
    # v2.69.0: Print to stdout (captured by 2>&1) instead of stderr directly
    print(f"Error reading file: {e}")
    sys.exit(1)
' "$file" 2>&1; then
        log_error "Invalid YAML syntax in $file"
        return 1
    fi
    return 0
}

# Validate skill.yaml required fields
validate_skill_yaml() {
    local skill_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")

    log "Validating skill.yaml for: $skill_name"

    # Check YAML syntax first
    if ! validate_yaml_syntax "$skill_file"; then
        return 1
    fi

    # Required fields
    local required_fields=(
        "name"
        "version"
        "category"
        "role"
        "triggers"
        "execution"
    )

    for field in "${required_fields[@]}"; do
        if ! python3 -c "
import yaml
import sys
with open('$skill_file', 'r') as f:
    data = yaml.safe_load(f)
if '$field' not in data or data['$field'] is None:
    sys.exit(1)
" 2>/dev/null; then
            log_error "Missing required field '$field' in $skill_file"
            return 1
        fi
    done

    # Validate triggers structure
    if ! python3 -c "
import yaml
with open('$skill_file', 'r') as f:
    data = yaml.safe_load(f)
triggers = data.get('triggers', {})
if not isinstance(triggers, dict):
    exit(1)
if 'keywords' not in triggers and 'file_patterns' not in triggers and 'context_patterns' not in triggers:
    exit(1)
" 2>/dev/null; then
        log_error "Invalid triggers structure in $skill_file (must have keywords, file_patterns, or context_patterns)"
        return 1
    fi

    log_success "skill.yaml validation passed for $skill_name"
    return 0
}

# Validate validations.yaml regex patterns
validate_validations_yaml() {
    local validations_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$validations_file")")

    if [[ ! -f "$validations_file" ]]; then
        log_warning "validations.yaml not found for $skill_name (optional)"
        return 0
    fi

    log "Validating validations.yaml for: $skill_name"

    # Check YAML syntax
    if ! validate_yaml_syntax "$validations_file"; then
        return 1
    fi

    # Validate regex patterns can be compiled
    if ! python3 -c "
import yaml
import re
import sys
with open('$validations_file', 'r') as f:
    data = yaml.safe_load(f)
validations = data.get('validations', [])
for v in validations:
    pattern = v.get('pattern', {})
    if 'regex' in pattern:
        try:
            re.compile(pattern['regex'])
        except re.error as e:
            # v2.69.0: Print to stdout instead of stderr
            print(f\"Invalid regex in {v.get('id', 'unknown')}: {e}\")
            sys.exit(1)
    if 'negative_regex' in pattern:
        try:
            re.compile(pattern['negative_regex'])
        except re.error as e:
            # v2.69.0: Print to stdout instead of stderr
            print(f\"Invalid negative_regex in {v.get('id', 'unknown')}: {e}\")
            sys.exit(1)
" 2>&1; then
        log_error "Invalid regex patterns in $validations_file"
        return 1
    fi

    log_success "validations.yaml validation passed for $skill_name"
    return 0
}

# Validate sharp-edges.yaml patterns
validate_sharp_edges_yaml() {
    local sharp_edges_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$sharp_edges_file")")

    if [[ ! -f "$sharp_edges_file" ]]; then
        log_warning "sharp-edges.yaml not found for $skill_name (optional)"
        return 0
    fi

    log "Validating sharp-edges.yaml for: $skill_name"

    # Check YAML syntax
    if ! validate_yaml_syntax "$sharp_edges_file"; then
        return 1
    fi

    # Validate detection patterns
    if ! python3 -c "
import yaml
import re
import sys
with open('$sharp_edges_file', 'r') as f:
    data = yaml.safe_load(f)
sharp_edges = data.get('sharp_edges', [])
for edge in sharp_edges:
    pattern = edge.get('detection_pattern', {})
    if 'regex' in pattern:
        try:
            re.compile(pattern['regex'])
        except re.error as e:
            # v2.69.0: Print to stdout instead of stderr
            print(f\"Invalid regex in {edge.get('id', 'unknown')}: {e}\")
            sys.exit(1)
" 2>&1; then
        log_error "Invalid detection patterns in $sharp_edges_file"
        return 1
    fi

    log_success "sharp-edges.yaml validation passed for $skill_name"
    return 0
}

# Validate collaboration.yaml structure
validate_collaboration_yaml() {
    local collaboration_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$collaboration_file")")

    if [[ ! -f "$collaboration_file" ]]; then
        log_warning "collaboration.yaml not found for $skill_name (optional)"
        return 0
    fi

    log "Validating collaboration.yaml for: $skill_name"

    # Check YAML syntax
    if ! validate_yaml_syntax "$collaboration_file"; then
        return 1
    fi

    # Validate structure has delegation or accept_delegation_from
    if ! python3 -c "
import yaml
with open('$collaboration_file', 'r') as f:
    data = yaml.safe_load(f)
if 'delegation' not in data and 'accept_delegation_from' not in data:
    exit(1)
" 2>/dev/null; then
        log_error "collaboration.yaml must have 'delegation' or 'accept_delegation_from' section"
        return 1
    fi

    log_success "collaboration.yaml validation passed for $skill_name"
    return 0
}

# Main validation function
# scan_skill_md <skill.md path> <skill name> — T48 hot security gate.
# Returns 0 clean, 3 violation (reason on stdout). Scanner-internal errors are
# fail-OPEN by design and logged: a bug in the detector must not take down the
# whole skill system; the error surfaces in the log for the lint to catch.
scan_skill_md() {
    local skill_md="$1" skill_name="$2"
    local verdict rc_scan=0
    # rc 0 = clean, 3 = violation (DENY line on stdout). Any other rc is a
    # scanner-internal failure: fail-OPEN by design (a detector bug must not
    # take down the skill system) and logged for the lint to surface. The
    # `|| rc_scan=$?` capture is required: under set -e a bare assignment with
    # rc 3 would kill the script, and the deny path would become a crash.
    verdict=$(python3 - "$skill_md" "$skill_name" "$ALLOWLIST_PATH" <<'PYEOF'
import re, sys, unicodedata

path, skill, allowlist_path = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8", errors="replace").read()

# --- context model ---------------------------------------------------------
# Fenced code blocks and inline code are tracked per offset. override_instructions
# (the only PROSE pattern) is suppressed inside them and near negation lines — a
# skill that documents an attack to forbid it must pass (macos-cleaner fixture).
# Code patterns (base64/exec/ioc/pipe/secret) scan EVERYWHERE including fences:
# real payloads live in "run this" blocks. Known benign doc installs (gcloud)
# belong on the allowlist with a reason, not in a blind exception.
inline_spans = [m.span() for m in re.finditer(r"`[^`\n]+`", text)]
fence_spans = [m.span() for m in re.finditer(r"(?ms)^```.*?^```", text)]
def in_span(off):
    return any(a <= off < b for a, b in inline_spans + fence_spans)
lines = text.splitlines("\n")
negation = re.compile(r"(?i)(never|do not|don't|avoid|prohibit|forbidden|not instructions|inert|data, not)")
negated_line = set()
prev_neg = False
for i, ln in enumerate(lines):
    cur = bool(negation.search(ln))
    if cur or prev_neg:
        negated_line.add(i)
    prev_neg = cur

def line_of(off):
    return text.count("\n", 0, off)

findings = []
def add(pid, detail):
    findings.append((pid, detail))

# 1. unicode_invisible — zero-width/bidi/tag characters anywhere: no legitimate
#    use in a skill body (red-team samples go on the allowlist).
for ch in set(text):
    o = ord(ch)
    if o in (0x200b, 0x200c, 0x200d, 0xfeff, 0x2060, 0x202e) or 0xe0000 <= o <= 0xe007f:
        add("unicode_invisible", f"U+{o:04X} present")
        break

# 2. base64_exec — a long base64 run feeding a decoder (hidden payload).
for m in re.finditer(r"(?i)(echo\s+[A-Za-z0-9+/=]{60,}\s*\|?\s*base64\s+(-d|--decode))|([A-Za-z0-9+/=]{120,}\|\s*base64)", text):
    add("base64_exec", m.group(0)[:60] + "...")
    break

# 3. exfil_ioc — network tooling on the same line as a known exfil endpoint
#    (known exfil domains, or ANY raw non-local IP — ClawHavoc shared a raw C2).
for m in re.finditer(r"(?im)^.*(?:curl|wget|nc |ncat|fetch\().*$", text):
    ln = m.group(0)
    if re.search(r"127\.0\.0\.1|0\.0\.0\.0|localhost", ln):
        continue
    if re.search(r"webhook\.site|discord\.com/api/webhooks|pastebin\.com|ngrok\.(io|app)|(?:\d{1,3}\.){3}\d{1,3}", ln):
        add("exfil_ioc", ln.strip()[:80])
        break

# 4. pipe_to_shell — remote content piped straight into a shell.
m = re.search(r"(?i)(curl|wget)\s+\S+\s*\|\s*(sudo\s+)?(ba|z|da)?sh\b", text)
if m:
    add("pipe_to_shell", m.group(0)[:70])

# 5. secret_literal — planted or leaked credentials in the prompt.
m = re.search(r"sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xoxb-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY", text)
if m:
    add("secret_literal", m.group(0)[:30] + "...")

# 6. override_instructions — prose trying to neutralize the system prompt,
#    QUOTE-AWARE: only outside code spans and non-negated lines.
for m in re.finditer(r"(?i)(ignore|disregard|forget)\s+(all\s+)?(previous|prior|above|earlier|your)\s+(instructions?|rules?|prompts?|guidelines?)", text):
    if in_span(m.start()):
        continue
    if line_of(m.start()) in negated_line:
        continue
    add("override_instructions", m.group(0))
    break

# --- allowlist (auditable) -------------------------------------------------
exempt = {}
try:
    for raw in open(allowlist_path, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        body, _, reason = line.partition("#")
        reason = reason.strip()
        parts = body.split()
        if len(parts) < 2 or not reason:
            # entry without a written reason is INVALID: ignored (fail-closed)
            print(f"ALLOWLIST_INVALID {body.strip()[:60]}")
            continue
        exempt.setdefault(parts[0], set()).update(parts[1].split(","))
except FileNotFoundError:
    pass

exemptions = exempt.get(skill, set())
matched = {pid for pid, _ in findings}
# Stale reporting is unconditional: an exempted pattern that matched nothing
# must be flagged even when the skill is otherwise clean (the list cannot rot).
for pid in sorted(exemptions - matched):
    print(f"ALLOWLIST_STALE {skill} {pid}")
for pid, detail in findings:
    if pid not in exemptions:
        print(f"DENY {pid} {detail}")
        sys.exit(3)
print("CLEAN")
sys.exit(0)
PYEOF
    ) || rc_scan=$?
    if [[ $rc_scan -ne 0 && $rc_scan -ne 3 ]]; then
        log "ERROR: security scanner failed for $skill_name (rc=$rc_scan) — allowing (fail-open by design, see T48)"
        return 0
    fi

    # Scanner warnings that do not block (allowlist hygiene) go to the log.
    while IFS= read -r line; do
        case "$line" in
            ALLOWLIST_INVALID*) log "ERROR: $line (entry ignored — reason is mandatory)" ;;
            ALLOWLIST_STALE*)   log "WARN: $line (exempted pattern no longer present — prune the entry)" ;;
        esac
    done <<< "$(grep -E '^(ALLOWLIST_INVALID|ALLOWLIST_STALE)' <<<"$verdict" || true)"

    if grep -q '^DENY ' <<<"$verdict"; then
        local reason pid
        reason="$(grep '^DENY ' <<<"$verdict" | head -n1 | cut -d' ' -f3-)"
        pid="$(grep '^DENY ' <<<"$verdict" | head -n1 | awk '{print $2}')"
        log_error "SECURITY: [$pid] $skill_name — $reason"
        trap - ERR EXIT
        # jq -n, never string interpolation: the reason comes from the scanned
        # file, and a quote in it produced invalid JSON, the harness could not
        # parse the deny, and an unparseable deny denies nothing (T23 lesson).
        emit_json "$(jq -nc --arg p "$pid" --arg s "$skill_name" --arg r "$reason" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("[skill-validator] " + $p + " in " + $s + ": " + $r)}}')"
        return 1
    fi
    log "security scan clean: $skill_name"
    return 0
}

validate_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"

    # T44 (#67): not-found is OUT OF DOMAIN, not a violation. The skill
    # ecosystem migrated to SKILL.md; a name with no directory or no
    # skill.yaml is a modern skill with nothing for THIS validator to check.
    # Denying here would veto every SKILL.md-era skill the day the
    # registration is pointed at the Skill tool. A PRESENT-but-invalid
    # skill.yaml is the violation this gate exists for — that still denies.
    if [[ ! -d "$skill_dir" ]]; then
        log "Not an H70 skill (no directory): $skill_dir — nothing to validate"
        return 0
    fi

    log "Starting validation for skill: $skill_name"

    # Validate skill.yaml (required for H70 skills; absent means out of domain)
    if [[ ! -f "$skill_dir/skill.yaml" ]]; then
        log "Not an H70 skill (no skill.yaml): $skill_dir — nothing to validate"
        return 0
    fi

    if ! validate_skill_yaml "$skill_dir/skill.yaml"; then
        return 1
    fi

    # Validate optional files
    validate_validations_yaml "$skill_dir/validations.yaml" || return 1
    validate_sharp_edges_yaml "$skill_dir/sharp-edges.yaml" || return 1
    validate_collaboration_yaml "$skill_dir/collaboration.yaml" || return 1

    log_success "All validation checks passed for skill: $skill_name"
    return 0
}

# Entry point
main() {
    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes CRIT-001 double-read bug)
    local input="$INPUT"

    # Extract skill name from input
    # T44 (#67): a real PreToolUse payload nests the name in tool_input.skill
    # (Skill tool); the flat {"skill": ...} shape only exists in manual/test
    # invocations. tool_input first, root fallback.
    local skill_name
    skill_name=$(echo "$input" | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input') or {}
    name = ti.get('skill') or data.get('skill', '')
    print(name if isinstance(name, str) else '')
except:
    # T62 (#72): garbage stdin degrades to nameless — the silent allow —
    # instead of exiting 1 (which under set -e killed the hook and made the
    # ERR trap emit the allow by accident: rc 1 + allow, the worst of both).
    print("")
" 2>/dev/null)

    if [[ -z "$skill_name" ]]; then
        # T44 (#67): silent allow. The live registration (PreToolUse
        # Agent|Task) produces this on EVERY invocation — logging it as ERROR
        # buried the real validation lines under 4,693 copies of noise.
        trap - ERR EXIT
        emit_json '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
        exit 0  # Nothing to validate — not an error, not even worth a log line
    fi

    # SECURITY FIX v2.57.0: Sanitize skill_name to prevent command injection
    skill_name=$(sanitize_skill_name "$skill_name")

    if [[ -z "$skill_name" ]]; then
        log_error "Skill name became empty after sanitization (contained only invalid characters)"
        trap - ERR EXIT  # CRIT-004: Clear trap before explicit output
        emit_json '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
        exit 0
    fi

    # ── T48 (#68): resolve the ONE SKILL.md about to be invoked and gate it ──
    # Resolution order: user skills dir, project skills, then plugins by name.
    # Cost contract: on allow this path adds NOTHING to the model's context —
    # only a deny carries a reason. No path here ever emits additionalContext.
    SKILL_MD=""
    for cand in "${SKILLS_DIR}/${skill_name}/SKILL.md" \
                "${CLAUDE_PROJECT_DIR:-}/.claude/skills/${skill_name}/SKILL.md"; do
        [[ -n "${cand%/SKILL.md}" && -f "$cand" ]] && { SKILL_MD="$cand"; break; }
    done
    if [[ -z "$SKILL_MD" ]]; then
        # `|| true` is load-bearing: under set -euo pipefail, a missing plugins
        # dir makes find exit 1, the assignment inherits it, and the whole
        # hook died before ever reaching the H70 domain (caught by the suite).
        SKILL_MD="$(find "${HOME}/.claude/plugins" -maxdepth 7 -type f -path "*/skills/${skill_name}/SKILL.md" 2>/dev/null | head -n1 || true)"
    fi
    if [[ -n "$SKILL_MD" ]]; then
        scan_skill_md "$SKILL_MD" "$skill_name" || exit 0   # deny already emitted
    else
        log "no SKILL.md for $skill_name — H70 domain only"
    fi

    # Run validation with timeout
    # Source this script to make functions available
    if timeout "$VALIDATION_TIMEOUT" bash -c "source '${BASH_SOURCE[0]}' && validate_skill '$skill_name'"; then
        log_success "Validation completed successfully for: $skill_name"
        trap - ERR EXIT  # CRIT-004: Clear trap before explicit output
        emit_json '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
        exit 0
    else
        log_error "Validation failed or timed out for: $skill_name"
        trap - ERR EXIT  # CRIT-004: Clear trap before explicit output
        emit_json '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "[skill-validator] Skill validation failed or timed out"}}'
        # exit 0, not 1: PreToolUse honours a structured deny only with exit 0 (or a bare
        # exit 2). Any other code is treated as a non-blocking hook error and the JSON on
        # stdout is discarded — so `exit 1` emitted a veto that was thrown away.
        exit 0
    fi
}

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
