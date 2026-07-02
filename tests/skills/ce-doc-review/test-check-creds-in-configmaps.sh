#!/usr/bin/env bash
# Test: skills/ce-doc-review/scripts/check-credentials-in-configmaps.py
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-doc-review/scripts/check-credentials-in-configmaps.py"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)

echo "=== test-check-credentials-in-configmaps.py ==="

if [[ -x "$SCRIPT" ]]; then
  ok "script is executable"
else
  die "script not executable"
fi

output=$(python3 "$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

output=$(python3 "$SCRIPT" -h 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "-h flag works"
else
  die "-h flag (rc=$rc)"
fi

# Test YAML with sensitive data
cat > "$tmpdir/config.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  password: mysecret123
  api_key: ***
  token: bearer-xyz789
  normal_value: hello
ENDOFYAML

output=$(python3 "$SCRIPT" "$tmpdir" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "finds sensitive patterns (exit 0)"
else
  die "expected exit 0 (rc=$rc)"
fi

echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
if [[ $? -eq 0 ]]; then
  ok "output is valid JSON"
else
  die "output is not valid JSON"
fi

if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(f['pattern_type']=='password' for f in d)" 2>/dev/null; then
  ok "detects password pattern"
else
  die "did not detect password pattern"
fi

if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(f['pattern_type']=='api_key' for f in d)" 2>/dev/null; then
  ok "detects api_key pattern"
else
  die "did not detect api_key pattern"
fi

if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(f['pattern_type']=='token' for f in d)" 2>/dev/null; then
  ok "detects token pattern"
else
  die "did not detect token pattern"
fi

# Test standalone 'key' field is detected
keydir=$(mktemp -d)
cat > "$keydir/has-key.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: key-test
data:
  key: somevalue123
ENDOFYAML
output=$(python3 "$SCRIPT" "$keydir" 2>&1) && rc=0 || rc=$?
if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(f['pattern_type']=='key' for f in d)" 2>/dev/null; then
  ok "detects standalone key field"
else
  die "did not detect standalone key field"
fi
rm -rf "$keydir"

# Test that primary_key, cacheKey, monkey are NOT flagged as 'key'
falsedir=$(mktemp -d)
cat > "$falsedir/false-keys.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: false-key-test
data:
  primary_key: value123456
  cacheKey: value123456
  monkey: value123456
ENDOFYAML
false_output=$(python3 "$SCRIPT" "$falsedir" 2>&1) && rc=0 || rc=$?
if echo "$false_output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not any(f['pattern_type']=='key' for f in d)" 2>/dev/null; then
  ok "does not flag primary_key/cacheKey/monkey as key"
else
  die "false positive on primary_key/cacheKey/monkey"
fi
rm -rf "$falsedir"

if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not any(f['pattern_type']=='normal_value' for f in d)" 2>/dev/null; then
  ok "does not flag normal values"
else
  die "flagged normal value incorrectly"
fi

# Check redaction
if echo "$output" | grep -q "mysecret123"; then
  die "raw value leaked"
else
  ok "values are redacted"
fi

# Check redaction returns *** without leaking first/last chars
if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(f['redacted']=='***' for f in d if f.get('redacted'))" 2>/dev/null; then
  ok "redacted values are exactly ***"
else
  die "redacted values contain source characters"
fi

if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all('severity' in f for f in d)" 2>/dev/null; then
  ok "severity field present"
else
  die "missing severity field"
fi

# Test clean dir
cleandir=$(mktemp -d)
cat > "$cleandir/safe.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - port: 80
ENDOFYAML
output=$(python3 "$SCRIPT" "$cleandir" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "exit 2 when no patterns found"
else
  die "expected exit 2 (rc=$rc)"
fi
rm -rf "$cleandir"

# Test nonexistent dir
output=$(python3 "$SCRIPT" /nonexistent_dir_xyz 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exit 1 for nonexistent directory"
else
  die "expected exit 1 (rc=$rc)"
fi

# Test metacharacters
output=$(python3 "$SCRIPT" '/tmp/foo;rm -rf /' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects shell metacharacters"
else
  die "expected exit 1 (rc=$rc)"
fi

# Test JSON file (must have kind: ConfigMap to pass the gate)
cat > "$tmpdir/configmap.json" << 'ENDOFJSON'
{"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "test"}, "password": "supersecret", "host": "localhost"}
ENDOFJSON
output=$(python3 "$SCRIPT" "$tmpdir" 2>&1) && rc=0 || rc=$?
if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(f['file'].endswith('configmap.json') for f in d)" 2>/dev/null; then
  ok "scans JSON files too"
else
  die "did not scan JSON files"
fi

# Test kind-gating: Secret manifest should be excluded
secretdir=$(mktemp -d)
cat > "$secretdir/secret.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
password: mysecret123
ENDOFYAML
output=$(python3 "$SCRIPT" "$secretdir" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "excludes Secret manifests (exit 2)"
else
  die "did not exclude Secret manifest (rc=$rc)"
fi
rm -rf "$secretdir"

# Test kind-gating: Deployment manifest should be excluded
depdir=$(mktemp -d)
cat > "$depdir/deploy.yaml" << 'ENDOFYAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deploy
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: password
              value: mysecret123
ENDOFYAML
output=$(python3 "$SCRIPT" "$depdir" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "excludes Deployment manifests (exit 2)"
else
  die "did not exclude Deployment manifest (rc=$rc)"
fi
rm -rf "$depdir"

# Test kind-gating: mixed directory only returns ConfigMap findings
mixeddir=$(mktemp -d)
cat > "$mixeddir/configmap.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  password: configmapsecret
ENDOFYAML
cat > "$mixeddir/secret.yaml" << 'ENDOFYAML'
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
password: secretsecret
ENDOFYAML
output=$(python3 "$SCRIPT" "$mixeddir" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all('ConfigMap' in f['file'] or 'configmap' in f['file'] for f in d)" 2>/dev/null; then
  ok "mixed dir: only ConfigMap findings returned"
else
  die "mixed dir: Secret findings leaked through"
fi
rm -rf "$mixeddir"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
