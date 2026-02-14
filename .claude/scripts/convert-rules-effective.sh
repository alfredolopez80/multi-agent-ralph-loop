#!/bin/bash
# Convert Rules to Effective Format v2.88.0
# Converts auto-extract rules into Claude-usable format

set -euo pipefail

RULES_FILE="${HOME}/.ralph/procedural/rules.json"
OUTPUT_DIR="${HOME}/.ralph/procedural/effective"

mkdir -p "$OUTPUT_DIR"

MIN_USAGE=0
DOMAIN_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) DOMAIN_FILTER="$2"; shift 2 ;;
        --min-usage) MIN_USAGE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== Converting Rules to Effective Format ==="

# Get list of domains
DOMAINS=$(jq -r '.rules[].domain // "general"' "$RULES_FILE" 2>/dev/null | sort -u)

total_effective=0

for domain in $DOMAINS; do
    [[ -z "$domain" ]] && continue
    [[ -n "$DOMAIN_FILTER" && "$domain" != "$DOMAIN_FILTER" ]] && continue

    # Extract effective rules for this domain
    count=$(jq -r --arg domain "$domain" --argjson min "$MIN_USAGE" '
        [.rules[] | select(
            .domain == $domain and
            (.usage_count // 0) >= $min and
            .behavior != null and .behavior != ""
        )] | length
    ' "$RULES_FILE" 2>/dev/null || echo "0")

    if [[ "$count" -gt 0 ]]; then
        # Create effective rules file
        jq -r --arg domain "$domain" --argjson min "$MIN_USAGE" '
            .rules |
            map(select(
                .domain == $domain and
                (.usage_count // 0) >= $min and
                .behavior != null and .behavior != ""
            )) |
            sort_by(-(.usage_count // 0)) |
            {
                domain: $domain,
                total: length,
                rules: [.[] | {
                    id: .rule_id,
                    pattern: .behavior,
                    usage: (.usage_count // 0),
                    confidence: (.confidence // 0.5),
                    source: (.trigger // "")
                }]
            }
        ' "$RULES_FILE" > "${OUTPUT_DIR}/${domain}.json" 2>/dev/null

        echo "  $domain: $count effective rules"
        total_effective=$((total_effective + count))
    fi
done

echo ""
echo "=== Summary ==="
echo "Total effective rules: $total_effective"
echo "Output directory: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.json 2>/dev/null | wc -l | xargs echo "Domain files created:"
