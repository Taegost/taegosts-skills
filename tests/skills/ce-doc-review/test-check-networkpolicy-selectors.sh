#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-doc-review/scripts/check-networkpolicy-selectors.sh"
pass=0 fail=0
cleanup() { rm -rf /tmp/test-np-* 2>/dev/null || true; }
trap cleanup EXIT

echo "=== U12: check-networkpolicy-selectors.sh ==="

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

output=$("$SCRIPT" /nonexistent 2>&1 || true)
if echo "$output" | grep -q "not found"; then echo "PASS: nonexistent dir"; pass=$((pass+1))
else echo "FAIL: nonexistent dir"; fail=$((fail+1)); fi

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir"
cat > "$tmpdir/test-np.yaml" << 'YAMLEOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock:
            cidr: 192.168.5.202/32
YAMLEOF

output=$("$SCRIPT" "$tmpdir" 2>&1)
if echo "$output" | grep -q "hairpin"; then echo "PASS: detects MetalLB hairpin"; pass=$((pass+1))
else echo "FAIL: MetalLB hairpin"; fail=$((fail+1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
