#!/usr/bin/env bash
# Capture baseline state of files that will change in this plan.
# Run BEFORE any implementation. Compare after restructure.
set -euo pipefail

BASELINE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$BASELINE_DIR/../.." && pwd)"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "Baseline capture: $TIMESTAMP"
echo "Repo: $REPO_ROOT"
echo ""

# Reset snapshot files to prevent duplicate rows on re-run
: > "$BASELINE_DIR/word-counts.txt"
: > "$BASELINE_DIR/file-hashes.txt"

# --- Word counts ---
echo "=== Word Counts ==="
for f in \
  skills/ts-plan/SKILL.md \
  skills/ts-doc-review/references/subagent-template.md \
  skills/ts-doc-review/references/synthesis-and-presentation.md \
  skills/ts-doc-review/references/findings-schema.json \
  skills/ts-doc-review/SKILL.md \
  skills/ts-work/SKILL.md \
  skills/ts-verify-implementation/SKILL.md \
; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    wc=$(wc -w < "$REPO_ROOT/$f")
    echo "$f: $wc words"
    echo "$wc $f" >> "$BASELINE_DIR/word-counts.txt"
  else
    echo "$f: NOT FOUND"
  fi
done

echo ""

# --- File hashes ---
echo "=== File Hashes (SHA-256) ==="
for f in \
  skills/ts-plan/SKILL.md \
  skills/ts-plan/references/html-rendering.md \
  skills/ts-plan/references/plan-handoff.md \
  skills/ts-plan/references/plan-sections.md \
  skills/ts-plan/references/synthesis-summary.md \
  skills/ts-plan/references/deepening-workflow.md \
  skills/ts-plan/references/approach-altitude.md \
  skills/ts-doc-review/SKILL.md \
  skills/ts-doc-review/references/subagent-template.md \
  skills/ts-doc-review/references/synthesis-and-presentation.md \
  skills/ts-doc-review/references/findings-schema.json \
  skills/ts-work/SKILL.md \
  skills/ts-work/references/agents/implementer-tests.md \
  skills/ts-work/references/agents/implementer-general.md \
  skills/ts-verify-implementation/SKILL.md \
  docs/standards/agent-standards.md \
  docs/standards/INDEX.md \
; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    hash=$(sha256sum "$REPO_ROOT/$f" | cut -d' ' -f1)
    echo "$hash  $f"
    echo "$hash  $f" >> "$BASELINE_DIR/file-hashes.txt"
  else
    echo "MISSING  $f"
  fi
done

echo ""

# --- Section structure of ts-plan/SKILL.md ---
echo "=== ts-plan/SKILL.md Section Structure ==="
grep -n '^#' "$REPO_ROOT/skills/ts-plan/SKILL.md" | head -60

echo ""
echo "Baseline capture complete. Files written to: $BASELINE_DIR"
