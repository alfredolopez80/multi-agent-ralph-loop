#!/bin/bash
# Validate all required environment variables
set -euo pipefail

REQUIRED_VARS=(
  "Z_AI_API_KEY"
  "ANTHROPIC_API_KEY"
)

MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING_VARS+=("$var")
  fi
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
