#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-doc-review/scripts/check-networkpolicy-selectors.sh"
pass=0 fail=0
tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "=== U12: check-networkpolicy-selectors.sh ==="

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

output=$("$SCRIPT" /nonexistent 2>&1 || true)
if echo "$output" | grep -q "not found"; then echo "PASS: nonexistent dir"; pass=$((pass+1))
else echo "FAIL: nonexistent dir"; fail=$((fail+1)); fi

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

# Test: non-NetworkPolicy file with matching keywords should be excluded
svcdir=$(mktemp -d)
cat > "$svcdir/service.yaml" << 'YAMLEOF'
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  ports:
    - port: 80
YAMLEOF
output=$("$SCRIPT" "$svcdir" 2>&1) && rc=0 || rc=$?
if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d)==0" 2>/dev/null; then
  echo "PASS: excludes non-NetworkPolicy Service"; pass=$((pass+1))
else
  echo "FAIL: did not exclude Service"; fail=$((fail+1))
fi
rm -rf "$svcdir"

# Test: Deployment with ipBlock keyword should be excluded
depdir=$(mktemp -d)
cat > "$depdir/deploy.yaml" << 'YAMLEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: ipBlock
              value: "192.168.1.1"
YAMLEOF
output=$("$SCRIPT" "$depdir" 2>&1) && rc=0 || rc=$?
if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d)==0" 2>/dev/null; then
  echo "PASS: excludes non-NetworkPolicy Deployment"; pass=$((pass+1))
else
  echo "FAIL: did not exclude Deployment"; fail=$((fail+1))
fi
rm -rf "$depdir"

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
