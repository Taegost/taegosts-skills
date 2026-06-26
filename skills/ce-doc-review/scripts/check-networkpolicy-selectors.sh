#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: check-networkpolicy-selectors.sh [directory]"
  echo "Check NetworkPolicy files for namespaceSelector/metalLB hairpin issues."
  echo "Output: JSON array of {file, issue, selector_type, recommendation}"
  echo "Exit codes: 0 (issues found), 1 (error), 2 (no issues)"
  exit 0
fi

dir="${1:-.}"
[[ ! -d "$dir" ]] && echo "directory not found" >&2 && exit 1

echo "$dir" | grep -qE '[;&|$\`]' && echo "invalid characters in path" >&2 && exit 1

# Fix #1 + #2: Use while/read loop instead of for-in-subshell
# Fix #6: Escape file paths for JSON
found_any=false
printf '['
first=true

while IFS= read -r -d '' f; do
  content=$(cat "$f" 2>/dev/null) || continue

  # JSON-escape the file path
  f_escaped=$(echo "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')

  # Check for namespaceSelector used with external IPs
  if echo "$content" | grep -q "namespaceSelector"; then
    if echo "$content" | grep -qE 'ipBlock|cidr.*192\.168|cidr.*10\.'; then
      found_any=true
      [[ "$first" == "true" ]] && first=false || printf ','
      printf '\n  {"file":"%s","issue":"namespaceSelector used alongside ipBlock for local network IPs - MetalLB hairpin risk","selector_type":"namespaceSelector","recommendation":"Use namespaceSelector for cluster services, port-based rules for external services"}' "$f_escaped"
    fi
  fi

  # Check for egress to MetalLB IPs via ipBlock
  if echo "$content" | grep -qE 'ipBlock' && echo "$content" | grep -qE 'cidr.*192\.168\.[0-9]+\.[0-9]+/32'; then
    found_any=true
    [[ "$first" == "true" ]] && first=false || printf ','
    printf '\n  {"file":"%s","issue":"ipBlock targeting single MetalLB IP - will fail with L2 hairpin","selector_type":"ipBlock","recommendation":"Replace ipBlock with namespaceSelector targeting the LoadBalancer backend namespace"}' "$f_escaped"
  fi

  # Check for missing DNS egress
  if echo "$content" | grep -q "Egress" && ! echo "$content" | grep -qE 'port.*53|dns'; then
    found_any=true
    [[ "$first" == "true" ]] && first=false || printf ','
    printf '\n  {"file":"%s","issue":"egress policy may be missing DNS port 53 rule","selector_type":"egress","recommendation":"Add UDP/TCP port 53 egress to kube-system namespace for DNS resolution"}' "$f_escaped"
  fi
done < <(find "$dir" \( -name "*.yaml" -o -name "*.yml" \) -print0 2>/dev/null)

printf '\n]\n'

[[ "$found_any" == "true" ]] && exit 0 || exit 2
