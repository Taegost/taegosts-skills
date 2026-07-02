#!/usr/bin/env bash
# Test: Verify that cleanup traps remove temp directories on exit
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || { echo "ERROR: cannot resolve script directory"; exit 1; }
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)" || { echo "ERROR: cannot resolve repo root"; exit 1; }

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-cleanup-traps.sh ==="

# Test that scripts actually clean up after themselves
test_cleanup() {
  local script_name="$1"
  local script_path="$REPO_ROOT/tests/scripts/$script_name"

  if [[ ! -f "$script_path" ]]; then
    die "Script not found: $script_name"
    return
  fi

  # First check: script has EXIT trap
  if ! grep -q 'trap.*EXIT' "$script_path"; then
    die "$script_name missing EXIT trap"
    return
  fi

  # Second check: trap references temp directory
  if ! grep -q 'trap.*rm -rf.*tmpdir\|trap.*rm -rf.*FIXTURE_DIR\|trap.*rm -rf.*TEMP_HOME\|trap.*cleanup.*EXIT' "$script_path"; then
    die "$script_name trap doesn't reference temp directory"
    return
  fi

  # Behavioral test: run the script and verify temp dirs are cleaned up
  # Extract tmpdir variable name from the script
  local tmpdir_var=$(grep -oP 'tmpdir\S*=\$\(mktemp' "$script_path" | head -1 | sed 's/=.*//')

  if [[ -z "$tmpdir_var" ]]; then
    # Check for other temp dir variables
    tmpdir_var=$(grep -oP '(FIXTURE_DIR|TEMP_HOME)=\$\(mktemp' "$script_path" | head -1 | sed 's/=.*//')
  fi

  # If still empty, check for TEMP_HOME specifically
  if [[ -z "$tmpdir_var" ]]; then
    if grep -q 'TEMP_HOME=$(mktemp -d)' "$script_path"; then
      tmpdir_var="TEMP_HOME"
    fi
  fi

  if [[ -z "$tmpdir_var" ]]; then
    ok "$script_name has EXIT trap (no mktemp found, structural check only)"
    return
  fi

  # Create a wrapper script that:
  # 1. Runs the test script in a subshell
  # 2. Captures the tmpdir path before the trap fires
  # 3. Checks if the tmpdir exists after the script exits
  local wrapper=$(mktemp)
  cat > "$wrapper" << WRAPPER
#!/usr/bin/env bash
set -uo pipefail

# Create a modified version of the script that prints the tmpdir
# before the trap fires
modified_script=$(mktemp)
cat > "\$modified_script" << 'MODSCRIPT'
#!/usr/bin/env bash
set -uo pipefail
MODSCRIPT

# Extract the script content, adding tmpdir echo before exit
awk '
/^tmpdir=/ {
  print
  print "echo \"TMPDIR_VAR:\" \"\$tmpdir\""
  next
}
/^TEMP_HOME=/ {
  print
  print "echo \"TMPDIR_VAR:\" \"\$TEMP_HOME\""
  next
}
/^FIXTURE_DIR=/ {
  print
  print "echo \"TMPDIR_VAR:\" \"\$FIXTURE_DIR\""
  next
}
{print}
' "$script_path" >> "\$modified_script"

chmod +x "\$modified_script"

# Run the modified script and capture the tmpdir
output=\$(bash "\$modified_script" 2>/dev/null | grep "TMPDIR_VAR:" | sed 's/TMPDIR_VAR: //')

rm -f "\$modified_script"

# Check if any of the reported tmpdirs still exist
for dir in \$output; do
  if [[ -d "\$dir" ]]; then
    echo "FAIL: tmpdir \$dir still exists after $script_name exited"
    exit 1
  fi
done
echo "PASS: all tmpdirs cleaned up for $script_name"
exit 0
WRAPPER
  chmod +x "$wrapper"

  # Run the wrapper
  if bash "$wrapper" 2>/dev/null; then
    ok "$script_name cleans up tmpdir on exit"
  else
    die "$script_name left tmpdir behind"
  fi

  rm -f "$wrapper"
}

# Test scripts that create temp directories (tests/scripts/)
test_cleanup "test-default-branch.sh"
test_cleanup "test-detect-diff-scope.sh"
test_cleanup "test-git-context.sh"
test_cleanup "test-validate-findings-json.sh"
test_cleanup "test-classify-document.sh"
test_cleanup "test-solutions-search.sh"
test_cleanup "test-sync-taegosts-skills.sh"
test_cleanup "test-verify-scripts.sh"
test_cleanup "test-verify-fix.sh"

# Test scripts that create temp directories (tests/skills/)
test_cleanup_skills() {
  local script_name="$1"
  local script_path="$REPO_ROOT/tests/skills/$script_name"

  if [[ ! -f "$script_path" ]]; then
    die "Script not found: $script_name"
    return
  fi

  # First check: script has EXIT trap
  if ! grep -q 'trap.*EXIT' "$script_path"; then
    die "$script_name missing EXIT trap"
    return
  fi

  # Second check: trap references temp directory
  if ! grep -q 'trap.*rm -rf.*tmpdir\|trap.*rm -rf.*FIXTURE_DIR\|trap.*rm -rf.*TEMP_HOME\|trap.*cleanup.*EXIT' "$script_path"; then
    die "$script_name trap doesn't reference temp directory"
    return
  fi

  ok "$script_name has EXIT trap"
}

test_cleanup_skills "ts-plan/test-generate-plan-filename.sh"
test_cleanup_skills "ts-plan/test-scan-repo-structure.sh"
test_cleanup_skills "ts-work/test-find-precommit-hook.sh"
test_cleanup_skills "ts-verify-implementation/test-detect-file-status.sh"
test_cleanup_skills "ts-doc-review/test-check-creds-in-configmaps.sh"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
