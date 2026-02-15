#!/usr/bin/env bash
#===============================================================================
# validate-hooks-syntax.sh
# Validates syntax of all hook scripts (shell and Python)
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Check all hook files have valid syntax and correct shebangs
#
# Usage:
#   ./scripts/validate-hooks-syntax.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All hooks have valid syntax
#   1: Syntax errors found
#   2: Cannot run checks
#===============================================================================

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output format
FORMAT="${FORMAT:-text}"
VERBOSE="${VERBOSE:-0}"

# Project paths
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-hooks-syntax.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - Bash syntax validation (bash -n) for .sh files
  - Python syntax validation (py_compile) for .py files
  - Shebang validation for all hook scripts
  - Reports errors with file:line format

Exit codes:
  0  All hooks have valid syntax
  1  Syntax errors found
  2  Cannot run checks
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A MESSAGES
declare -A ERROR_DETAILS
PASSED=0
FAILED=0
TOTAL=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Validate bash script syntax
validate_bash_syntax() {
    local file="$1"
    local errors

    errors=$(bash -n "$file" 2>&1)

    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo "$errors"
        return 1
    fi
}

# Validate Python script syntax
validate_python_syntax() {
    local file="$1"
    local errors

    errors=$(python3 -m py_compile "$file" 2>&1)

    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo "$errors"
        return 1
    fi
}

# Check shebang for shell scripts
check_bash_shebang() {
    local file="$1"
    local first_line

    first_line=$(head -1 "$file")

    # Valid bash shebangs
    if [[ "$first_line" == "#!/bin/bash"* ]] || \
       [[ "$first_line" == "#!/usr/bin/env bash"* ]] || \
       [[ "$first_line" == "#!/bin/sh"* ]] || \
       [[ "$first_line" == "#!/usr/bin/env sh"* ]]; then
        return 0
    fi
    return 1
}

# Check shebang for Python scripts
check_python_shebang() {
    local file="$1"
    local first_line

    first_line=$(head -1 "$file")

    # Valid python shebangs
    if [[ "$first_line" == "#!/usr/bin/env python"* ]] || \
       [[ "$first_line" == "#!/usr/bin/python"* ]] || \
       [[ "$first_line" == "#!/usr/local/bin/python"* ]]; then
        return 0
    fi
    return 1
}

# Validate a shell script
validate_shell_script() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    local status="PASS"
    local message=""
    local error_detail=""

    # Check shebang
    if ! check_bash_shebang "$file"; then
        status="FAIL"
        message="Invalid or missing shebang"
        error_detail="Expected: #!/bin/bash or #!/usr/bin/env bash"
    fi

    # Check bash syntax
    local syntax_errors
    local syntax_ret=0
    syntax_errors=$(validate_bash_syntax "$file") || syntax_ret=$?

    if [[ $syntax_ret -ne 0 ]]; then
        status="FAIL"
        if [[ -n "$message" ]]; then
            message="$message; syntax error"
        else
            message="Bash syntax error"
        fi
        error_detail="$syntax_errors"
    fi

    RESULTS["$filename"]="$status"
    MESSAGES["$filename"]="$message"
    ERROR_DETAILS["$filename"]="$error_detail"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
    esac
    TOTAL=$((TOTAL + 1))
}

# Validate a Python script
validate_python_script() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    local status="PASS"
    local message=""
    local error_detail=""

    # Check shebang
    if ! check_python_shebang "$file"; then
        status="FAIL"
        message="Invalid or missing shebang"
        error_detail="Expected: #!/usr/bin/env python3 or similar"
    fi

    # Check Python syntax
    local syntax_errors
    local syntax_ret=0
    syntax_errors=$(validate_python_syntax "$file") || syntax_ret=$?

    if [[ $syntax_ret -ne 0 ]]; then
        status="FAIL"
        if [[ -n "$message" ]]; then
            message="$message; syntax error"
        else
            message="Python syntax error"
        fi
        error_detail="$syntax_errors"
    fi

    RESULTS["$filename"]="$status"
    MESSAGES["$filename"]="$message"
    ERROR_DETAILS["$filename"]="$error_detail"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
    esac
    TOTAL=$((TOTAL + 1))
}

# Print text output
print_text_output() {
    echo "=================================================="
    echo "   Hooks Syntax Validation - v1.0.0"
    echo "=================================================="
    echo ""
    echo "Hooks Dir: $HOOKS_DIR"
    echo ""

    # Shell scripts section
    echo -e "${BLUE}Shell Scripts (.sh)${NC}"
    echo "--------------------------------------------------"

    local shell_files=()
    while IFS= read -r -d '' file; do
        shell_files+=("$file")
    done < <(find "$HOOKS_DIR" -maxdepth 1 -name "*.sh" -type f -print0 2>/dev/null | sort -z)

    if [[ ${#shell_files[@]} -eq 0 ]]; then
        echo "  No shell scripts found"
    else
        for file in "${shell_files[@]}"; do
            local filename
            filename=$(basename "$file")
            local status="${RESULTS[$filename]}"
            local message="${MESSAGES[$filename]}"

            case "$status" in
                PASS)
                    echo -e "${GREEN}  OK${NC} $filename"
                    [[ "$VERBOSE" -eq 1 ]] && echo "      $message"
                    ;;
                FAIL)
                    echo -e "${RED}  FAIL${NC} $filename"
                    echo -e "       ${YELLOW}$message${NC}"
                    if [[ -n "${ERROR_DETAILS[$filename]}" ]]; then
                        # Print error details with indentation
                        echo "${ERROR_DETAILS[$filename]}" | while IFS= read -r line; do
                            echo "       $line"
                        done
                    fi
                    ;;
            esac
        done
    fi

    echo ""

    # Python scripts section
    echo -e "${BLUE}Python Scripts (.py)${NC}"
    echo "--------------------------------------------------"

    local python_files=()
    while IFS= read -r -d '' file; do
        python_files+=("$file")
    done < <(find "$HOOKS_DIR" -maxdepth 1 -name "*.py" -type f -print0 2>/dev/null | sort -z)

    if [[ ${#python_files[@]} -eq 0 ]]; then
        echo "  No Python scripts found"
    else
        for file in "${python_files[@]}"; do
            local filename
            filename=$(basename "$file")
            local status="${RESULTS[$filename]}"
            local message="${MESSAGES[$filename]}"

            case "$status" in
                PASS)
                    echo -e "${GREEN}  OK${NC} $filename"
                    [[ "$VERBOSE" -eq 1 ]] && echo "      $message"
                    ;;
                FAIL)
                    echo -e "${RED}  FAIL${NC} $filename"
                    echo -e "       ${YELLOW}$message${NC}"
                    if [[ -n "${ERROR_DETAILS[$filename]}" ]]; then
                        echo "${ERROR_DETAILS[$filename]}" | while IFS= read -r line; do
                            echo "       $line"
                        done
                    fi
                    ;;
            esac
        done
    fi

    echo ""
    echo "=================================================="
    echo "   SUMMARY"
    echo "=================================================="
    echo "  Total:   $TOTAL"
    echo "  Passed:  $PASSED"
    echo "  Failed:  $FAILED"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}OK All hooks have valid syntax${NC}"
        return 0
    else
        echo -e "${RED}FAIL Some hooks have syntax errors${NC}"
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $FAILED -gt 0 ]] && overall_status="fail"

    # Build hooks JSON array
    local hooks_json=""
    local first=true

    # Process all files in RESULTS (sorted for consistent output)
    local sorted_filenames
    sorted_filenames=$(printf '%s\n' "${!RESULTS[@]}" | sort)

    while IFS= read -r filename; do
        [[ -z "$filename" ]] && continue

        local status="${RESULTS[$filename]}"
        local message="${MESSAGES[$filename]}"
        local error_detail="${ERROR_DETAILS[$filename]}"

        # Determine file type
        local file_type="unknown"
        if [[ "$filename" == *.sh ]]; then
            file_type="shell"
        elif [[ "$filename" == *.py ]]; then
            file_type="python"
        fi

        # Escape message and error_detail for JSON
        message=$(echo "$message" | jq -Rs '.' 2>/dev/null || echo '""')
        error_detail=$(echo "$error_detail" | jq -Rs '.' 2>/dev/null || echo '""')

        if $first; then
            first=false
        else
            hooks_json+=","
        fi

        hooks_json+="
    \"$filename\": {
      \"type\": \"$file_type\",
      \"status\": \"$status\",
      \"message\": $message,
      \"error_detail\": $error_detail
    }"
    done <<< "$sorted_filenames"

    cat << EOF
{
  "status": "$overall_status",
  "hooks_dir": "$HOOKS_DIR",
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED
  },
  "hooks": {$hooks_json
  }
}
EOF
}

#===============================================================================
# MAIN
#===============================================================================

# Check if hooks directory exists
if [[ ! -d "$HOOKS_DIR" ]]; then
    echo "Hooks directory not found: $HOOKS_DIR" >&2
    exit 2
fi

# Find and validate shell scripts
while IFS= read -r -d '' file; do
    validate_shell_script "$file"
done < <(find "$HOOKS_DIR" -maxdepth 1 -name "*.sh" -type f -print0 2>/dev/null)

# Find and validate Python scripts
while IFS= read -r -d '' file; do
    validate_python_script "$file"
done < <(find "$HOOKS_DIR" -maxdepth 1 -name "*.py" -type f -print0 2>/dev/null)

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac

# Return exit code based on failures
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
