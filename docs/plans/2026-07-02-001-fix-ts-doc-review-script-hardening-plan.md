---
title: "fix: Harden ts-doc-review scripts (credential scanner + networkpolicy checker)"
type: fix
date: 2026-07-02
---

**Status: COMPLETED** — all implementation units merged in PR #70 (commit 9080e17).

## Summary

Harden three `ts-doc-review` scripts: tighten the credential scanner's regex to
eliminate false positives, stop leaking credential fragments in redacted output,
gate both scanners on the correct Kubernetes `kind`, and fix a broken test
cleanup trap.

## Problem Frame

CodeRabbit review of PR #20 identified 3 findings on
`check-credentials-in-configmaps.py` and 1 on `check-networkpolicy-selectors.sh`.
A manual review also found a broken cleanup trap in the networkpolicy test.

The credential scanner matches too broadly (e.g., `primary_key`, `cacheKey`,
`monkey`), leaks the first/last character of secrets in redacted output, and
scans every YAML/JSON file regardless of Kubernetes resource kind. The
networkpolicy checker has the same kind-gating gap, flagging Services,
Deployments, and Helm values that contain keywords like `Egress` or `ipBlock`.

## Requirements

### Credential scanner (`check-credentials-in-configmaps.py`)

- R1. The `key` regex matches only standalone `key` field names, not suffixes like `primary_key`, `cacheKey`, or `monkey`.
- R2. `redact_value()` returns `***` for all values — no source characters are ever exposed.
- R3. `scan_file()` skips files whose content does not contain `kind: ConfigMap` (YAML) or `"kind": "ConfigMap"` (JSON).

### Networkpolicy checker (`check-networkpolicy-selectors.sh`)

- R4. The main loop skips files whose content does not match `kind: NetworkPolicy`.

### Test fix

- R5. The cleanup trap in `test-check-networkpolicy-selectors.sh` removes the actual `mktemp -d` directory, not a glob pattern.

## Key Technical Decisions

- KTD-1: **Gate on file content, not filename.** Both scanners check the file's `kind` field rather than relying on directory structure or naming conventions. Kubernetes manifests have no filename convention; content-based gating is the only reliable approach.
- KTD-2: **Read file content once, gate then scan.** For `check-credentials-in-configmaps.py`, read the file content upfront, check for `kind: ConfigMap`, and only then scan line-by-line. This avoids reading the file twice. For the bash script, the content is already captured in `$content` — add the gate before the existing checks.
- KTD-3: **Anchor `key` regex with word boundaries.** Replace the negative lookbehind/lookahead approach with a word-boundary anchor (`\bkey\b`) so the pattern only matches when `key` is a standalone word in a field-name position.

## Implementation Units

### U1. Fix `key` regex in check-credentials-in-configmaps.py

**Goal:** Stop false-positive matches on field names where `key` is a suffix.

**Requirements:** R1

**Files:**
- `skills/ts-doc-review/scripts/check-credentials-in-configmaps.py` (line 32)
- `tests/skills/ts-doc-review/test-check-creds-in-configmaps.sh`

**Approach:** Replace the `(?<!api[_-])(?!api)key` pattern with `\bkey\b` to match only standalone `key` tokens. The existing negative lookbehind was trying to exclude `api_key`/`apikey` but those are already covered by the separate `api_key` pattern at line 29.

**Test scenarios:**
- Happy path: a YAML file with `key: somevalue123` is detected as a `key` finding.
- Edge case: a YAML file with `primary_key: val`, `cacheKey: val`, `monkey: val` produces no `key` findings (only the explicit `key` field matches).
- Regression: existing `password`, `api_key`, `token`, `secret`, `credential` detections are unaffected.

**Verification:** Run the test script; confirm `key` findings only fire on standalone `key` field names.

### U2. Fix `redact_value()` to fully mask credentials

**Goal:** Stop leaking the first and last character of matched credential values.

**Requirements:** R2

**Files:**
- `skills/ts-doc-review/scripts/check-credentials-in-configmaps.py` (lines 36-41)
- `tests/skills/ts-doc-review/test-check-creds-in-configmaps.sh`

**Approach:** Change `redact_value()` to always return `***` regardless of input length. The current implementation exposes `value[0] + '*' * (len - 2) + value[-1]`, which is enough to fingerprint real secrets.

**Test scenarios:**
- Happy path: a password value `mysecret123` appears as `***` in output, not `m*********3`.
- Edge case: short values (<=4 chars) also return `***`.
- Regression: the existing "values are redacted" test still passes (it only checks that the raw value is absent, so `***` satisfies it).

**Verification:** Run the test script; confirm no output contains the first or last character of any matched value.

### U3. Gate credential scanner on `kind: ConfigMap`

**Goal:** Stop scanning Secrets and non-ConfigMap manifests for credential patterns.

**Requirements:** R3

**Files:**
- `skills/ts-doc-review/scripts/check-credentials-in-configmaps.py` (function `scan_file`)
- `tests/skills/ts-doc-review/test-check-creds-in-configmaps.sh`

**Approach:** In `scan_file()`, read the file content first, check whether it contains `kind: ConfigMap` or `"kind": "ConfigMap"` (for JSON). Use a line-anchored regex consistent with U4's pattern: `re.search(r'^\s*kind:\s*ConfigMap(\s|$)', content)` for YAML. If the kind check fails, return an empty list without scanning lines. This requires refactoring `scan_file()` to read content into memory rather than iterating line-by-line from the file handle. Note: this approach treats the file as a single resource; multi-document YAML files (with `---` separators) containing mixed resource types are a known limitation outside this plan's scope.

**Patterns to follow:** The `scan_line()` function is called per-line; `scan_file()` should read content, gate on kind, then iterate lines from the in-memory content.

**Test scenarios:**
- Happy path: a `kind: ConfigMap` YAML with `password: secret` produces findings.
- Edge case: a `kind: Secret` YAML with `password: secret` produces no findings (exit code 2).
- Edge case: a `kind: Deployment` YAML with `password: secret` produces no findings.
- Regression: existing ConfigMap test fixtures continue to pass.
- Integration: a directory containing both ConfigMap and Secret manifests only returns findings for the ConfigMap.

**Verification:** Run the test script; confirm Secrets and non-ConfigMap manifests are excluded.

### U4. Gate networkpolicy checker on `kind: NetworkPolicy`

**Goal:** Stop flagging non-NetworkPolicy YAML files that contain `Egress`, `ipBlock`, or `namespaceSelector`.

**Requirements:** R4

**Files:**
- `skills/ts-doc-review/scripts/check-networkpolicy-selectors.sh` (main loop, around line 23)
- `tests/skills/ts-doc-review/test-check-networkpolicy-selectors.sh`

**Approach:** After capturing `content=$(cat "$f")`, add a guard:
`echo "$content" | grep -qE '^\s*kind:\s*NetworkPolicy(\s|$)' || continue`. This skips files whose `kind` is not `NetworkPolicy` before running any heuristic checks.

**Test scenarios:**
- Happy path: a `kind: NetworkPolicy` file with `ipBlock` and `cidr: 192.168.5.202/32` produces a hairpin finding (existing test).
- Edge case: a `kind: Service` file containing `Egress` and `namespaceSelector` strings produces no findings.
- Edge case: a `kind: Deployment` file containing `ipBlock` produces no findings.
- Regression: existing test for MetalLB hairpin detection still passes.

**Verification:** Run the test script; confirm non-NetworkPolicy files are silently skipped.

### U5. Fix cleanup trap in test-check-networkpolicy-selectors.sh

**Goal:** The test cleanup removes the actual temp directory, not a glob pattern.

**Requirements:** R5

**Files:**
- `tests/skills/ts-doc-review/test-check-networkpolicy-selectors.sh` (lines 7-8, 20-21)

**Approach:** Move the `tmpdir=$(mktemp -d)` assignment before the `trap` registration, and change the cleanup function to `rm -rf "$tmpdir"`. Remove the glob-based `rm -rf /tmp/test-np-*`.

**Test scenarios:**
- Happy path: after the test runs, the specific temp directory no longer exists.
- Edge case: no unrelated `/tmp` directories are affected.

**Verification:** Run the test script; confirm no leaked temp directories remain.

## Scope Boundaries

### Deferred to Follow-Up Work

- Issues #63, #62, #47, #44, #42, #64 (Plan 2: PR/work script hardening)
- Issues #56, #55, #53, #49, #45 (Plan 3: test suite hardening)
- Issues #65, #60, #61, #16, #19 (Plan 4: feature work)
