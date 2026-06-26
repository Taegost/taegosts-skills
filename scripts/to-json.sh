#!/usr/bin/env bash
# to-json.sh — Safe JSON output for bash scripts
# Eliminates printf-based JSON construction that breaks with special characters.
#
# Usage:
#   to-json.sh key1=value1 key2=value2              # simple object
#   to-json.sh --array item1 item2 item3             # simple array
#   echo '{"nested": true}' | to-json.sh --wrap key1 # wrap existing JSON
#   to-json.sh --help
#
# Output: Valid JSON on stdout
# Exit codes: 0 (success), 1 (error)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: to-json.sh [options] [key=value ...]"
  echo ""
  echo "Safe JSON construction for bash scripts."
  echo ""
  echo "Options:"
  echo "  --array item1 item2 ...   Output a JSON array"
  echo "  --wrap key                Read JSON from stdin, wrap as {\"key\": <stdin>}"
  echo ""
  echo "Exit codes: 0 (success), 1 (error)"
  exit 0
fi

if [[ "${1:-}" == "--array" ]]; then
  shift
  python3 -c "import sys,json; print(json.dumps([a for a in sys.argv[1:] if a != '--']))" -- "$@"
  exit 0
fi

if [[ "${1:-}" == "--wrap" ]]; then
  key="$2"
  python3 -c "import sys,json; print(json.dumps({sys.argv[1]: json.loads(sys.stdin.read())}, indent=2))" "$key"
  exit 0
fi

python3 -c "
import sys, json
result = {}
for arg in sys.argv[1:]:
    if arg == '--': continue
    if '=' not in arg:
        print(json.dumps({'error': 'invalid argument: ' + arg}), file=sys.stderr)
        sys.exit(1)
    key, val = arg.split('=', 1)
    if val.lower() == 'true': result[key] = True
    elif val.lower() == 'false': result[key] = False
    elif val.lower() == 'null': result[key] = None
    else:
        try: result[key] = int(val)
        except ValueError:
            try: result[key] = float(val)
            except ValueError: result[key] = val
print(json.dumps(result, indent=2))
" -- "$@"
