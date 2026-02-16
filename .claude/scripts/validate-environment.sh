#!/bin/bash
# Validate all required environment variables
set -euo pipefail

REQUIRED_VARS=(
  "Z_AI_API_KEY"
  "ANTHROPIC_API_KEY"
)

MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
  local value="${!var:-}"

  # Check if variable is set
  if [[ -z "$value" ]]; then
    MISSING_VARS+=("$var (not set)")
    continue
  fi

  # Validate API key format (basic checks)
  case "$var" in
    *API_KEY*)
      # Check minimum length (API keys are typically 20+ chars)
      if [[ ${#value} -lt 20 ]]; then
        MISSING_VARS+=("$var (invalid length: ${#value} < 20)")
      fi

      # Check for placeholder values
      if [[ "$value" =~ ^(your-api-key|placeholder|xxx|test|example) ]]; then
        MISSING_VARS+=("$var (appears to be placeholder)")
      fi
      ;;
  esac
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "❌ ERROR: Missing required environment variables:" >&2
  printf '  - %s\n' "${MISSING_VARS[@]}" >&2
  echo "" >&2
  echo "Set missing variables:" >&2
  for var in "${MISSING_VARS[@]}"; do
    echo "  export $var='your-value-here'" >&2
  done
  exit 1
fi

echo "✅ All required environment variables are set"
exit 0
