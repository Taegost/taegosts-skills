#!/usr/bin/env bash
# detect-missing-artifacts.sh -- Find files in reference dir but absent from plan
# Input: --plan-files <file> --reference-dir <path>
# Output: JSON array of {file, status} where status is "missing" or "in_plan"
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: detect-missing-artifacts.sh --plan-files <file> --reference-dir <path>

Compare a plan file list against a reference directory to find missing artifacts.

Arguments:
  --plan-files <file>      Path to file containing list of files (one per line)
  --reference-dir <path>   Path to reference directory to scan

Output: JSON array of {file, status} where:
  - "missing"  = in reference dir but NOT in plan (needs action)
  - "in_plan"  = in both reference dir and plan

Exit codes:
  0 - success
  1 - error (bad input, missing args)
EOF
  exit 0
fi

# Parse arguments
plan_files=""
reference_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-files)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--plan-files requires a value"}' >&2; exit 1; }
      plan_files="$2"
      shift 2
      ;;
    --reference-dir)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--reference-dir requires a value"}' >&2; exit 1; }
      reference_dir="$2"
      shift 2
      ;;
    *)
      echo '{"ok":false,"error":"unknown argument"}' >&2
      exit 1
      ;;
  esac
done

# Validate required args
if [[ -z "$plan_files" || -z "$reference_dir" ]]; then
  echo '{"ok":false,"error":"--plan-files and --reference-dir are required"}' >&2
  exit 1
fi

# R10: validate inputs - reject shell metacharacters (file-path variant: excludes /)
# KTD1: ANSI-C quoting for proper escape handling of control chars, \n, \t
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*? \n\t]'
if [[ "$plan_files" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--plan-files path contains shell metacharacters"}' >&2
  exit 1
fi
if [[ "$reference_dir" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--reference-dir path contains shell metacharacters"}' >&2
  exit 1
fi

# Block path traversal
if [[ "$plan_files" == *".."* ]]; then
  echo '{"ok":false,"error":"--plan-files must not contain path traversal (..)"}' >&2
  exit 1
fi
if [[ "$reference_dir" == *".."* ]]; then
  echo '{"ok":false,"error":"--reference-dir must not contain path traversal (..)"}' >&2
  exit 1
fi

# Validate file/dir existence
if [[ ! -f "$plan_files" ]]; then
  echo '{"ok":false,"error":"--plan-files file not found"}' >&2
  exit 1
fi

if [[ ! -d "$reference_dir" ]]; then
  echo '{"ok":false,"error":"--reference-dir not found"}' >&2
  exit 1
fi

# Verify python3 is available
if ! command -v python3 &>/dev/null; then
  echo '{"ok":false,"error":"python3 is required but not found in PATH"}' >&2
  exit 1
fi

# Use python for reliable JSON output
python3 - "$plan_files" "$reference_dir" << 'PYEOF'
import json
import os
import sys

plan_file = sys.argv[1]
ref_dir = sys.argv[2]

try:
    # Read plan file list
    with open(plan_file) as f:
        plan_set = set(line.strip() for line in f if line.strip())

    # Scan reference directory
    results = []
    for root, dirs, files in os.walk(ref_dir, onerror=lambda e: (_ for _ in ()).throw(e)):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "__pycache__", ".venv")]
        for fname in sorted(files):
            full_path = os.path.join(root, fname)
            rel_path = os.path.relpath(full_path, ref_dir)
            if rel_path in plan_set:
                results.append({"file": rel_path, "status": "in_plan"})
            else:
                results.append({"file": rel_path, "status": "missing"})

    print(json.dumps(results, indent=2))
except Exception as e:
    # Emit the script's established {"ok":false,"error":...} contract instead
    # of a raw traceback -- covers unreadable plan_files (decode/permission
    # errors) and unreadable subdirectories under reference_dir (permission
    # errors, which os.walk otherwise skips silently by default).
    print(json.dumps({"ok": False, "error": str(e)}), file=sys.stderr)
    sys.exit(1)
PYEOF
