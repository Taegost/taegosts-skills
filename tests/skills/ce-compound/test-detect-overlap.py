#!/usr/bin/env python3
import subprocess, os, tempfile, json, sys

SCRIPT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'skills', 'ce-compound', 'scripts', 'detect-overlap.py')
SCRIPT = os.path.normpath(SCRIPT)
pass_count = 0
fail_count = 0

def ok(msg):
    global pass_count; pass_count += 1; print(f"  PASS: {msg}")
def fail(msg):
    global fail_count; fail_count += 1; print(f"  FAIL: {msg}")

print("=== U14: detect-overlap.py ===")

# Test --help
r = subprocess.run([sys.executable, SCRIPT, '--help'], capture_output=True, text=True)
if r.returncode == 0 and ('usage' in r.stdout.lower() or 'usage' in r.stderr.lower()): ok("--help flag")
else: fail(f"--help flag (rc={r.returncode}, stdout={r.stdout[:100]})")

# Test with matching content
tmpdir = tempfile.mkdtemp()
os.makedirs(f"{tmpdir}/docs/solutions/conventions")
with open(f"{tmpdir}/docs/solutions/conventions/valkey-pattern.md", 'w') as f:
    f.write('---\ntitle: "Valkey Cache Auth Pattern"\ntags: [valkey, redis, cache]\n---\nContent\n')

r = subprocess.run([sys.executable, SCRIPT, '--title', 'Valkey Cache Pattern', '--tags', 'valkey,redis', '--solutions-dir', f'{tmpdir}/docs/solutions'], capture_output=True, text=True)
if r.returncode == 0:
    data = json.loads(r.stdout)
    if len(data.get('matches', [])) > 0: ok("finds matching overlap")
    else: fail("should find overlap")
else: fail(f"exit code {r.returncode}")

# Test no matches
r = subprocess.run([sys.executable, SCRIPT, '--title', 'Completely Different Topic', '--tags', 'unrelated,tags', '--solutions-dir', f'{tmpdir}/docs/solutions'], capture_output=True, text=True)
if r.returncode == 2: ok("exit 2 for no matches")
else: fail(f"expected exit 2, got {r.returncode}")

# Test bad dir
r = subprocess.run([sys.executable, SCRIPT, '--title', 'x', '--tags', 'y', '--solutions-dir', '/nonexistent'], capture_output=True, text=True)
if r.returncode == 1: ok("exit 1 for bad dir")
else: fail(f"expected exit 1, got {r.returncode}")

print(f"\nResults: {pass_count} passed, {fail_count} failed")
sys.exit(0 if fail_count == 0 else 1)
