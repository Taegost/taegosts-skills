#!/usr/bin/env python3
"""U11: check-creds-in-configmaps.py - scan YAML/JSON files for cred patterns.

Usage:
    python3 check-creds-in-configmaps.py [directory]

Scans YAML and JSON files in the given directory (default: current directory)
for cred-like patterns (password, secret, key, token, api_key, cred).

Output: JSON array of {file, line, pattern_type, severity, redacted}
Redacts matched values -- shows pattern_type, not the actual value.

Exit codes:
    0 -- creds found (findings on stdout)
    1 -- error (bad input, directory not found)
    2 -- no creds found
"""

import json
import os
import re
import sys


# Cred patterns: (compiled_regex, pattern_type, severity)
CRED_PATTERNS = [
    (re.compile(r'(?i)["\']?(?:password|passwd|pwd)["\']?\s*[:=]\s*(.+)'), 'password', 'high'),
    (re.compile(r'(?i)["\']?(?:secret)["\']?\s*[:=]\s*(.+)'), 'secret', 'high'),
    (re.compile(r'(?i)["\']?(?:api[_-]?key)["\']?\s*[:=]\s*(.+)'), 'api_key', 'high'),
    (re.compile(r'(?i)["\']?(?:credential)s?["\']?\s*[:=]\s*(.+)'), 'credential', 'high'),
    (re.compile(r'(?i)["\']?(?:token)["\']?\s*[:=]\s*(.+)'), 'token', 'medium'),
    (re.compile(r'(?i)(?<!api[_-])(?<!api)key\s*[:=]\s*(["\']?[A-Za-z0-9+/=_-]{8,}["\']?)'), 'key', 'medium'),
]


def redact_value(value):
    """Redact a value -- return asterisks with first/last char visible if long enough."""
    value = value.strip().strip('"').strip("'")
    if len(value) <= 4:
        return '*' * len(value)
    return value[0] + '*' * (len(value) - 2) + value[-1]


def scan_line(line, lineno, filepath):
    """Scan a single line for cred patterns."""
    findings = []
    for pattern, ptype, severity in CRED_PATTERNS:
        match = pattern.search(line)
        if match:
            value = match.group(1).strip() if match.lastindex else ''
            findings.append({
                'file': filepath,
                'line': lineno,
                'pattern_type': ptype,
                'severity': severity,
                'redacted': redact_value(value) if value else '***'
            })
    return findings


def scan_file(filepath):
    """Scan a single file for cred patterns."""
    findings = []
    try:
        with open(filepath, 'r', errors='replace') as f:
            for lineno, line in enumerate(f, start=1):
                findings.extend(scan_line(line, lineno, filepath))
    except (PermissionError, OSError):
        pass
    return findings


def usage_fail(msg):
    sys.stderr.write(f"check-creds-in-configmaps: {msg}\n")
    sys.exit(1)


def main(argv):
    if len(argv) > 1 and argv[1] in ('--help', '-h'):
        print("Usage: check-creds-in-configmaps.py [directory]")
        print()
        print("Scan YAML/JSON files for credential-like patterns.")
        print()
        print("Patterns detected: password, secret, key, token, api_key, credential")
        print()
        print("Output: JSON array of {file, line, pattern_type, severity, redacted}")
        print()
        print("Exit codes:")
        print("  0 - credentials found")
        print("  1 - error")
        print("  2 - no credentials found")
        return 0

    directory = argv[1] if len(argv) > 1 else '.'

    # R10: validate input - reject shell metacharacters
    if re.search(r'[;|&$`]', directory):
        usage_fail("directory path contains shell metacharacters")

    if not os.path.isdir(directory):
        usage_fail(f"directory not found: {directory}")

    scan_extensions = {'.yaml', '.yml', '.json'}
    all_findings = []

    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ('node_modules', '__pycache__', 'vendor', '.git')]
        for fname in sorted(files):
            ext = os.path.splitext(fname)[1].lower()
            if ext in scan_extensions:
                filepath = os.path.join(root, fname)
                all_findings.extend(scan_file(filepath))

    seen = set()
    unique_findings = []
    for f in all_findings:
        key = (f['file'], f['line'], f['pattern_type'])
        if key not in seen:
            seen.add(key)
            unique_findings.append(f)

    print(json.dumps(unique_findings, indent=2))
    return 0 if unique_findings else 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
