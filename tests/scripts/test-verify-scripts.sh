#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-scripts.sh"
pass=0 fail=0

echo "=== verify-scripts.sh ==="

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

# Should pass on our good scripts
"$SCRIPT" --file "$REPO_ROOT/scripts/to-json.sh" 2>&1 && echo "PASS: good script passes" && pass=$((pass+1)) || { echo "FAIL: good script"; fail=$((fail+1)); }

# Should fail on a bad script
badfile=$(mktemp --suffix=.sh)
echo "if then else" > "$badfile"
"$SCRIPT" --file "$badfile" 2>&1 && { echo "FAIL: bad script should fail"; fail=$((fail+1)); } || { echo "PASS: bad script fails"; pass=$((pass+1)); }
rm -f "$badfile"

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
