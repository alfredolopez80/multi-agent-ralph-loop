#!/usr/bin/env bash
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


# VERSION: 2.69.0
# v2.68.9: SEC-103 FIX - Use sys.argv for file path instead of string interpolation
# v2.68.2: FIX CRIT-004b - Only set trap when not sourced to prevent subshell JSON duplication
# v2.68.1: FIX CRIT-004 - Clear EXIT trap before explicit JSON output to prevent duplicate JSON
set -euo pipefail

# Error trap: Only set when running directly (not when sourced by timeout subshell)
# This prevents duplicate JSON from nested bash invocations
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT
fi

# Configuration
SKILLS_DIR="${HOME}/.claude/skills"
LOG_FILE="${HOME}/.ralph/skill-validation.log"
VALIDATION_TIMEOUT=10

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
validate_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"

    if [[ ! -d "$skill_dir" ]]; then
        log_error "Skill directory not found: $skill_dir"
        return 1
    fi

    log "Starting validation for skill: $skill_name"

    # Validate skill.yaml (required)
    if [[ ! -f "$skill_dir/skill.yaml" ]]; then
        log_error "skill.yaml not found in $skill_dir"
        return 1
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
    # For now, assume input is JSON: {"skill": "skill-name", "action": "load"}
    local skill_name
    skill_name=$(echo "$input" | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    print(data.get('skill', ''))
except:
    sys.exit(1)
" 2>/dev/null)

    if [[ -z "$skill_name" ]]; then
        log_error "No skill name provided in hook input"
        # v2.69.0: Removed stderr output (causes hook error warnings in UI)
        trap - EXIT  # CRIT-004: Clear trap before explicit output
        echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
        exit 0  # Don't block if no skill specified
    fi

    # SECURITY FIX v2.57.0: Sanitize skill_name to prevent command injection
    skill_name=$(sanitize_skill_name "$skill_name")

    if [[ -z "$skill_name" ]]; then
        log_error "Skill name became empty after sanitization (contained only invalid characters)"
        trap - EXIT  # CRIT-004: Clear trap before explicit output
        echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
        exit 0
    fi

    # Run validation with timeout
    # Source this script to make functions available
    if timeout "$VALIDATION_TIMEOUT" bash -c "source '${BASH_SOURCE[0]}' && validate_skill '$skill_name'"; then
        log_success "Validation completed successfully for: $skill_name"
        trap - EXIT  # CRIT-004: Clear trap before explicit output
        echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
        exit 0
    else
        log_error "Validation failed or timed out for: $skill_name"
        trap - EXIT  # CRIT-004: Clear trap before explicit output
        echo '{"decision": "block", "reason": "Skill validation failed"}'
        exit 1  # Block skill execution on validation failure
    fi
}

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
