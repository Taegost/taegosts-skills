#!/usr/bin/env python3
"""Tests for skills/ts-compound/scripts/detect-overlap.py (plan unit U14 suite)."""
import subprocess, os, json, sys

import pytest

SCRIPT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'skills', 'ts-compound', 'scripts', 'detect-overlap.py')
SCRIPT = os.path.normpath(SCRIPT)


@pytest.fixture()
def solutions_dir(tmp_path):
    """Solutions dir containing one convention doc, as the standalone runner's fixture did."""
    conventions = tmp_path / "docs" / "solutions" / "conventions"
    conventions.mkdir(parents=True)
    (conventions / "valkey-pattern.md").write_text(
        '---\ntitle: "Valkey Cache Auth Pattern"\ntags: [valkey, redis, cache]\n---\nContent\n'
    )
    return tmp_path / "docs" / "solutions"


def test_help_flag():
    r = subprocess.run([sys.executable, SCRIPT, '--help'], capture_output=True, text=True)
    assert r.returncode == 0 and ('usage' in r.stdout.lower() or 'usage' in r.stderr.lower()), \
        f"--help flag (rc={r.returncode}, stdout={r.stdout[:100]})"


def test_finds_matching_overlap(solutions_dir):
    r = subprocess.run(
        [sys.executable, SCRIPT, '--title', 'Valkey Cache Pattern', '--tags', 'valkey,redis',
         '--solutions-dir', str(solutions_dir)],
        capture_output=True, text=True)
    assert r.returncode == 0, f"exit code {r.returncode}"
    data = json.loads(r.stdout)
    assert len(data.get('matches', [])) > 0, "should find overlap"


def test_exit_2_for_no_matches(solutions_dir):
    r = subprocess.run(
        [sys.executable, SCRIPT, '--title', 'Completely Different Topic', '--tags', 'unrelated,tags',
         '--solutions-dir', str(solutions_dir)],
        capture_output=True, text=True)
    assert r.returncode == 2, f"expected exit 2, got {r.returncode}"


def test_exit_1_for_bad_dir():
    r = subprocess.run(
        [sys.executable, SCRIPT, '--title', 'x', '--tags', 'y', '--solutions-dir', '/nonexistent'],
        capture_output=True, text=True)
    assert r.returncode == 1, f"expected exit 1, got {r.returncode}"
