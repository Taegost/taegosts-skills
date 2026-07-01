#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-scripts.sh"
pass=0 fail=0
tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT
echo "=== test-verify-scripts.sh ==="

# --help
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then
  echo "PASS: --help"; pass=$((pass+1))
else
  echo "FAIL: --help"; fail=$((fail+1))
fi

# good .sh
echo "#!/bin/bash" > "$tmpdir/good.sh" && chmod +x "$tmpdir/good.sh"
echo "# help text with --help" >> "$tmpdir/good.sh"
if "$SCRIPT" --file "$tmpdir/good.sh" >/dev/null 2>&1; then
  echo "PASS: good .sh"; pass=$((pass+1))
else
  echo "FAIL: good .sh"; fail=$((fail+1))
fi

# bad .sh (syntax error)
echo "if then else" > "$tmpdir/bad.sh"
if "$SCRIPT" --file "$tmpdir/bad.sh" >/dev/null 2>&1; then
  echo "FAIL: bad .sh"; fail=$((fail+1))
else
  echo "PASS: bad .sh fails"; pass=$((pass+1))
fi

# good .py
echo "#!/usr/bin/env python3" > "$tmpdir/good.py" && chmod +x "$tmpdir/good.py"
echo "# --help" >> "$tmpdir/good.py"
echo "print(42)" >> "$tmpdir/good.py"
if "$SCRIPT" --file "$tmpdir/good.py" >/dev/null 2>&1; then
  echo "PASS: good .py"; pass=$((pass+1))
else
  echo "FAIL: good .py"; fail=$((fail+1))
fi

# bad .py (syntax error)
echo "def foo(" > "$tmpdir/bad.py"
if "$SCRIPT" --file "$tmpdir/bad.py" >/dev/null 2>&1; then
  echo "FAIL: bad .py"; fail=$((fail+1))
else
  echo "PASS: bad .py fails"; pass=$((pass+1))
fi

# unsupported extension
echo "content" > "$tmpdir/test.md"
output=$("$SCRIPT" --file "$tmpdir/test.md" 2>&1)
if echo "$output" | grep -q "0 passed"; then
  echo "PASS: unsupported ext skipped"; pass=$((pass+1))
else
  echo "FAIL: unsupported ext"; fail=$((fail+1))
fi

# --all mode
if "$SCRIPT" --all 2>&1 | grep -q "checking"; then
  echo "PASS: --all mode"; pass=$((pass+1))
else
  echo "FAIL: --all"; fail=$((fail+1))
fi

# dir arg
if "$SCRIPT" "$REPO_ROOT/scripts" 2>&1 | grep -q "passed"; then
  echo "PASS: dir arg"; pass=$((pass+1))
else
  echo "FAIL: dir arg"; fail=$((fail+1))
fi

# syntax-error file should not count as passed
echo "#!/bin/bash" > "$tmpdir/mixed.sh" && chmod +x "$tmpdir/mixed.sh"
echo "# --help" >> "$tmpdir/mixed.sh"
echo "if then" >> "$tmpdir/mixed.sh"
output=$("$SCRIPT" --file "$tmpdir/mixed.sh" 2>&1)
if echo "$output" | grep -q "0 passed"; then
  echo "PASS: syntax failure doesn't count as passed"; pass=$((pass+1))
else
  echo "FAIL: syntax failure counted as passed"; fail=$((fail+1))
fi

# .py with control characters should fail
printf '#!/usr/bin/env python3\n# --help\nprint(42)\x07' > "$tmpdir/ctrl.py" && chmod +x "$tmpdir/ctrl.py"
if "$SCRIPT" --file "$tmpdir/ctrl.py" >/dev/null 2>&1; then
  echo "FAIL: .py control chars not caught"; fail=$((fail+1))
else
  echo "PASS: .py control chars caught"; pass=$((pass+1))
fi

# --file without path should error
if "$SCRIPT" --file 2>/dev/null; then
  echo "FAIL: --file without path should error"; fail=$((fail+1))
else
  echo "PASS: --file without path errors"; pass=$((pass+1))
fi

# unknown flag should error
if "$SCRIPT" --bogus 2>/dev/null; then
  echo "FAIL: --bogus should error"; fail=$((fail+1))
else
  echo "PASS: --bogus errors"; pass=$((pass+1))
fi

echo ""
echo "Results: $pass passed, $fail failed"
if [[ $fail -eq 0 ]]; then
  exit 0
else
  exit 1
fi
