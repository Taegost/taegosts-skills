#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: validate-findings-json.sh <findings-json-file>"
  echo "Validates findings JSON has required fields: title, severity, file, description"
  echo "Valid severities: Critical, High, Moderate, Minor, Info"
  echo "Exit codes: 0 (valid), 1 (error), 2 (invalid)"
  exit 0
fi

findings_file="${1:-}"
[[ -z "$findings_file" || ! -f "$findings_file" ]] && { echo "valid file required" >&2; exit 1; }

python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
if not isinstance(data, list):
    print('fail'); print('Error: root must be an array', file=sys.stderr); sys.exit(2)
valid_sev = {'Critical','High','Moderate','Minor','Info'}
required = {'title','severity','file','description'}
errors = []
for i, f in enumerate(data):
    if not isinstance(f, dict):
        errors.append(f'finding {i}: not an object'); continue
    missing = required - set(f.keys())
    if missing: errors.append(f'finding {i}: missing {missing}')
    if f.get('severity') not in valid_sev: errors.append(f'finding {i}: invalid severity: {f.get(\"severity\")}')
if errors:
    print('fail')
    for e in errors: print(e, file=sys.stderr)
    sys.exit(2)
print('pass')
" 2>&1
