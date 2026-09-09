#!/usr/bin/env python3
"""
merge-findings.py -- Merge reviewer compact returns into one finding set.

Deterministic Stage 5 merge pipeline for ts-code-review. Reads the run's
staged compact returns (merge-tier fields only, one <reviewer>.json per
reviewer) and applies the scripted half of the Stage 5 steps: validation,
dedup, cross-reviewer promotion, pre-existing separation, conflict detection,
routing normalization, mode-aware demotion, the late confidence gate,
actionable/report-only partition, and stable sort + numbering. Judgment steps
(disagreement annotation, triage grouping 9b, Coverage prose, CE-artifact
preservation) stay with the orchestrator, which consumes this script's
`coverage.conflicts` report and counts.

Input (positional, required):
    merge-findings.py <compact-dir>

    <compact-dir> contains one `*.json` file per reviewer in the compact-return
    shape: top-level reviewer (string), findings (array), residual_risks
    (array), testing_gaps (array); per-finding merge-tier fields (title,
    severity, file, line, confidence, autofix_class, owner,
    requires_verification, pre_existing, optional suggested_fix). The
    orchestrator stages these to <run-dir>/compact/<reviewer>.json as
    reviewers return; this script reads ONLY these files, never the
    full-schema artifacts, so a failed artifact write still merges via the
    compact return.

Output (stdout): one JSON object:
    findings        primary findings after merge/gate, each with stable `#`
                    (monotonic across the full primary set), merge-tier
                    fields, contributing `reviewers` list, and final routing
    pre_existing    findings with pre_existing: true, separated before
                    demotion/gating (informational; no stable `#`)
    residual_risks  union across validated returns, plus demoted findings
                    appended as `<file:line> -- <title>` lines
    testing_gaps    union across validated returns
    partition       {actionable: [#...], report_only: [#...]} — stable `#`
                    lists; actionable = gated_auto/manual owned by
                    downstream-resolver, report_only = the rest. Both halves
                    stay in `findings`; Stage 6 and the JSON
                    `actionable_findings` field consume these lists.
    coverage        counts for the Coverage section: malformed returns
                    dropped (with reasons), findings dropped per-finding
                    (with reasons), legacy routing remaps, dedup merges,
                    promotions, demotions, suppressed count by anchor,
                    pre-existing count, and the `conflicts` report — same
                    fingerprint, differing severity/autofix_class/owner —
                    naming each reviewer's position for the orchestrator's
                    disagreement-annotation step.

Encoded Stage 5 rules (canonical spec: SKILL.md history, KTD 2 of
docs/plans/2026-09-08-002, script-extraction-standards.md):

1. Validate returns. Missing/wrong-typed top-level field drops the ENTIRE
   return (its findings and arrays do not survive). A finding violating a
   required field or value constraint is dropped and flagged; siblings in the
   same return survive. Legacy values are remapped before enum validation:
   autofix_class safe_auto -> gated_auto, owner review-fixer ->
   downstream-resolver.
2. Dedup. Fingerprint = normalize(file) + line within +/-3 + normalize(title).
   Matching findings merge into one group keeping the highest severity and
   highest anchor. `line_bucket` is implemented as direct tolerance matching
   (any two lines <= 3 apart match, transitively through chains) because a
   fixed floor bucket cannot honor +/-3 at bucket boundaries.
   normalize(): lowercase, collapse whitespace runs, strip, strip a leading
   "./", backslashes -> forward slashes.
3. Cross-reviewer agreement. 2+ distinct contributing reviewers on one group
   promote the anchor one step: 50 -> 75, 75 -> 100, 100 -> 100 (0/25 stay).
4. Separate pre-existing (all members pre_existing: true) into `pre_existing`.
5. Disagreements inside a group (severity/autofix_class/owner) are recorded
   in coverage.conflicts; the script reports, it does not resolve beyond the
   merge rules below.
6. Normalize routing. Conservative route on disagreement: autofix_class
   advisory > manual > gated_auto; owner human > release >
   downstream-resolver; requires_verification OR-ed (true wins).
6b. Mode-aware demotion. Demote when ALL hold: severity P2 or P3; autofix_class
   advisory; exactly one contributing reviewer AND it is not `testing`.
   Demoted findings are removed from primary and appended to residual_risks
   as `<file:line> -- <title>`.
7. Confidence gate (late). Suppress remaining primary findings below anchor
   75, except P0/P1 at anchor 50+. Suppressed count recorded by anchor.
8. Partition actionable vs report_only (see `partition` above).
9. Sort and number. severity (P0 first) -> anchor descending -> file path ->
   line number (title as final deterministic tiebreak); assign monotonic `#`
   across the full primary set.
10. Coverage data. Union residual_risks/testing_gaps across validated returns
   (a fully-dropped return's arrays drop with it, per step 1); exact
   duplicate lines dedupe, first occurrence wins in reviewer-name order.

Steps 9b (triage grouping) and 11 (CE-artifact preservation) stay
orchestrator-side and are not implemented here.

Exit codes:
    0 - Success (merged JSON on stdout; malformed RETURNS are dropped and
        reported inside coverage, not fatal)
    1 - Usage or input error (missing/unreadable compact-dir, no *.json
        files in it, unreadable file); reason on stderr

Usage:
    merge-findings.py <compact-dir>
    merge-findings.py --help
"""

import json
import sys
from pathlib import Path

SEVERITY_RANK = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
SEVERITIES = set(SEVERITY_RANK)
AUTO_CLASSES = ("gated_auto", "manual", "advisory")
OWNERS = ("downstream-resolver", "human", "release")
CONFIDENCE_ANCHORS = (0, 25, 50, 75, 100)
# More conservative = less autonomous action. Higher value wins on conflict.
CONSERVATIVE_AUTO = {"gated_auto": 0, "manual": 1, "advisory": 2}
CONSERVATIVE_OWNER = {"downstream-resolver": 0, "release": 1, "human": 2}
LINE_TOLERANCE = 3
TESTING_REVIEWER = "testing"

TOP_LEVEL_FIELDS = (
    ("reviewer", str),
    ("findings", list),
    ("residual_risks", list),
    ("testing_gaps", list),
)


def _norm_text(value: str) -> str:
    """Lowercase, collapse whitespace runs, strip."""
    return " ".join(value.lower().split())


def _norm_path(value: str) -> str:
    """Normalize a file path for fingerprinting."""
    value = value.strip().replace("\\", "/")
    while value.startswith("./"):
        value = value[2:]
    return _norm_text(value)


def _is_int(value) -> bool:
    """True for real ints — bool is excluded (bool subclasses int)."""
    return isinstance(value, int) and not isinstance(value, bool)


def _remap_legacy(finding: dict) -> int:
    """Remap legacy routing values in place. Returns count of remaps."""
    remapped = 0
    if finding.get("autofix_class") == "safe_auto":
        finding["autofix_class"] = "gated_auto"
        remapped += 1
    if finding.get("owner") == "review-fixer":
        finding["owner"] = "downstream-resolver"
        remapped += 1
    return remapped


def validate_finding(finding, reviewer: str, index: int):
    """Validate one finding against merge-tier constraints.

    Returns (finding, None) on success or (None, reason-string) on failure.
    Legacy safe_auto / review-fixer values are remapped before enum checks.
    """
    if not isinstance(finding, dict):
        return None, f"finding {index}: not an object"

    remap_count = _remap_legacy(finding)

    required = (
        "title", "severity", "file", "line", "confidence",
        "autofix_class", "owner", "requires_verification", "pre_existing",
    )
    missing = [k for k in required if k not in finding]
    if missing:
        return None, f"finding {index}: missing required field(s): {', '.join(missing)}"

    if not isinstance(finding["title"], str) or not finding["title"].strip():
        return None, f"finding {index}: title must be a non-empty string"
    if finding["severity"] not in SEVERITIES:
        return None, f"finding {index}: severity must be one of {sorted(SEVERITIES)}"
    if not isinstance(finding["file"], str) or not finding["file"].strip():
        return None, f"finding {index}: file must be a non-empty string"
    if not _is_int(finding["line"]) or finding["line"] < 1:
        return None, f"finding {index}: line must be a positive integer"
    if not _is_int(finding["confidence"]) or finding["confidence"] not in CONFIDENCE_ANCHORS:
        return None, (
            f"finding {index}: confidence must be an integer in "
            f"{list(CONFIDENCE_ANCHORS)}"
        )
    if finding["autofix_class"] not in AUTO_CLASSES:
        return None, f"finding {index}: autofix_class must be one of {list(AUTO_CLASSES)}"
    if finding["owner"] not in OWNERS:
        return None, f"finding {index}: owner must be one of {list(OWNERS)}"
    if not isinstance(finding["requires_verification"], bool):
        return None, f"finding {index}: requires_verification must be a boolean"
    if not isinstance(finding["pre_existing"], bool):
        return None, f"finding {index}: pre_existing must be a boolean"

    suggested = finding.get("suggested_fix")
    if "suggested_fix" in finding and not isinstance(suggested, str):
        finding["suggested_fix"] = None

    finding["_remapped"] = remap_count
    finding["_reviewer"] = reviewer
    return finding, None


def validate_return(raw, source_name: str):
    """Validate one compact return.

    Returns (validated, None) or (None, reason). A wrong-typed/missing
    top-level field drops the entire return.
    """
    if not isinstance(raw, dict):
        return None, "return is not a JSON object"

    for field, expected in TOP_LEVEL_FIELDS:
        if field not in raw:
            return None, f"missing required top-level field '{field}'"
        if not isinstance(raw[field], expected):
            return None, (
                f"top-level field '{field}' must be of type "
                f"{expected.__name__}"
            )
    if not raw["reviewer"].strip():
        return None, "top-level field 'reviewer' must be a non-empty string"

    reviewer = raw["reviewer"]
    validated = []
    for i, finding in enumerate(raw["findings"]):
        ok, reason = validate_finding(finding, reviewer, i)
        if ok is None:
            validated.append((None, reason))
        else:
            validated.append((ok, None))
    return {
        "reviewer": reviewer,
        "findings": [f for f, _ in validated if f is not None],
        "dropped_findings": [
            {"reviewer": reviewer, "index": i, "reason": reason}
            for i, (_, reason) in enumerate(validated) if reason
        ],
        "residual_risks": [
            r for r in raw["residual_risks"] if isinstance(r, str)
        ],
        "testing_gaps": [
            g for g in raw["testing_gaps"] if isinstance(g, str)
        ],
        "source": source_name,
    }, None


def _member_sort_key(finding: dict):
    """Canonical processing order: deterministic regardless of file order."""
    return (
        _norm_path(finding["file"]),
        finding["line"],
        _norm_text(finding["title"]),
        finding["_reviewer"],
    )


def _best_sort_key(finding: dict):
    """Total order for the kept representative: highest severity, then
    highest anchor, then lowest line, then reviewer name."""
    return (
        SEVERITY_RANK[finding["severity"]],
        -finding["confidence"],
        finding["line"],
        finding["_reviewer"],
    )


def merge_dedup(findings: list) -> list:
    """Group findings by fingerprint: normalized file, title, line +/-3.

    Single-linkage greedy grouping in canonical order — a finding joins the
    first group whose normalized file and title match and where any member's
    line is within LINE_TOLERANCE. Returns a list of member-lists.
    """
    groups: list[list[dict]] = []
    for finding in sorted(findings, key=_member_sort_key):
        placed = False
        for group in groups:
            rep = group[0]
            if (
                _norm_path(rep["file"]) == _norm_path(finding["file"])
                and _norm_text(rep["title"]) == _norm_text(finding["title"])
                and any(
                    abs(member["line"] - finding["line"]) <= LINE_TOLERANCE
                    for member in group
                )
            ):
                group.append(finding)
                placed = True
                break
        if not placed:
            groups.append([finding])
    return groups


def merge_group(group: list) -> dict:
    """Collapse one dedup group into a single merged finding."""
    best = min(group, key=_best_sort_key)
    reviewers = sorted({f["_reviewer"] for f in group})

    auto = max((f["autofix_class"] for f in group),
               key=lambda c: CONSERVATIVE_AUTO[c])
    owner = max((f["owner"] for f in group),
                key=lambda o: CONSERVATIVE_OWNER[o])
    requires_verification = any(f["requires_verification"] for f in group)

    suggested = best.get("suggested_fix")
    if not isinstance(suggested, str):
        for member in sorted(group, key=_member_sort_key):
            if isinstance(member.get("suggested_fix"), str):
                suggested = member["suggested_fix"]
                break

    return {
        "title": best["title"],
        "severity": best["severity"],
        "file": best["file"],
        "line": best["line"],
        "confidence": best["confidence"],
        "autofix_class": auto,
        "owner": owner,
        "requires_verification": requires_verification,
        "pre_existing": all(f["pre_existing"] for f in group),
        "suggested_fix": suggested,
        "reviewers": reviewers,
        # merge bookkeeping (stripped from output)
        "_group_size": len(group),
        "_reviewer_positions": [
            {
                "reviewer": f["_reviewer"],
                "severity": f["severity"],
                "autofix_class": f["autofix_class"],
                "owner": f["owner"],
            }
            for f in sorted(group, key=_member_sort_key)
        ],
    }


PROMOTIONS = {50: 75, 75: 100, 100: 100}


def detect_conflicts(merged: list) -> list:
    """Report groups whose members disagree on severity/class/owner."""
    conflicts = []
    for finding in merged:
        positions = finding["_reviewer_positions"]
        disagreement = (
            len({p["severity"] for p in positions}) > 1
            or len({p["autofix_class"] for p in positions}) > 1
            or len({p["owner"] for p in positions}) > 1
        )
        if disagreement:
            conflicts.append({
                "file": finding["file"],
                "line": finding["line"],
                "title": finding["title"],
                "positions": positions,
                "kept": {
                    "severity": finding["severity"],
                    "autofix_class": finding["autofix_class"],
                    "owner": finding["owner"],
                },
            })
    return conflicts


def _public(finding: dict, number: int | None) -> dict:
    out = {k: finding[k] for k in (
        "title", "severity", "file", "line", "confidence",
        "autofix_class", "owner", "requires_verification", "pre_existing",
        "reviewers",
    )}
    if isinstance(finding.get("suggested_fix"), str):
        out["suggested_fix"] = finding["suggested_fix"]
    if number is not None:
        out["#"] = number
    return out


def merge(compact_dir: Path) -> dict:
    """Run the full Stage 5 merge pipeline over a compact-return dir."""
    return_paths = sorted(
        p for p in compact_dir.iterdir()
        if p.is_file() and p.suffix == ".json"
    )
    if not return_paths:
        raise ValueError(f"no *.json compact returns found in {compact_dir}")

    returns = []
    returns_dropped = []
    for path in return_paths:
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError) as exc:
            raise ValueError(f"cannot read {path}: {exc}") from exc
        except json.JSONDecodeError as exc:
            returns_dropped.append(
                {"file": path.name, "reason": f"invalid JSON: {exc}"})
            continue
        validated, reason = validate_return(raw, path.name)
        if validated is None:
            returns_dropped.append({"file": path.name, "reason": reason})
        else:
            returns.append(validated)

    coverage = {
        "returns_total": len(return_paths),
        "returns_dropped": returns_dropped,
        "findings_received": sum(len(r["findings"]) for r in returns)
        + sum(len(d["dropped_findings"]) for d in returns),
        "findings_dropped": [
            d for r in returns for d in r["dropped_findings"]
        ],
        "legacy_remapped": 0,
        "dedup_merges": 0,
        "promoted": 0,
        "demoted": 0,
        "suppressed_by_anchor": {},
        "pre_existing": 0,
        "conflicts": [],
    }

    # Step 2-3: dedup + cross-reviewer promotion.
    raw_findings = []
    for r in returns:
        coverage["legacy_remapped"] += sum(
            f.pop("_remapped", 0) for f in r["findings"])
        raw_findings.extend(r["findings"])

    merged = []
    for group in merge_dedup(raw_findings):
        coverage["dedup_merges"] += len(group) - 1
        finding = merge_group(group)
        if len({f["_reviewer"] for f in group}) >= 2:
            finding["confidence"] = PROMOTIONS.get(
                finding["confidence"], finding["confidence"])
            coverage["promoted"] += 1
        merged.append(finding)

    # Step 5: disagreement report (annotation stays orchestrator-side).
    coverage["conflicts"] = detect_conflicts(merged)

    # Step 4: separate pre-existing.
    pre_existing = [f for f in merged if f["pre_existing"]]
    primary = [f for f in merged if not f["pre_existing"]]
    coverage["pre_existing"] = len(pre_existing)

    # Step 6b: mode-aware demotion of weak single-reviewer findings.
    residual_risks: list[str] = []
    demoted_set = set()
    for i, finding in enumerate(primary):
        if (
            finding["severity"] in ("P2", "P3")
            and finding["autofix_class"] == "advisory"
            and len(finding["reviewers"]) == 1
            and finding["reviewers"][0] != TESTING_REVIEWER
        ):
            demoted_set.add(i)
            residual_risks.append(
                f"{finding['file']}:{finding['line']} -- {finding['title']}")
            coverage["demoted"] += 1
    primary = [f for i, f in enumerate(primary) if i not in demoted_set]

    # Step 7: late confidence gate.
    suppressed: dict[int, int] = {}
    gated = []
    for finding in primary:
        if finding["confidence"] < 75 and not (
            finding["severity"] in ("P0", "P1")
            and finding["confidence"] >= 50
        ):
            suppressed[finding["confidence"]] = (
                suppressed.get(finding["confidence"], 0) + 1)
        else:
            gated.append(finding)
    coverage["suppressed_by_anchor"] = {
        str(anchor): count
        for anchor, count in sorted(suppressed.items())
    }

    # Step 9: sort and number across the full primary set.
    gated.sort(key=lambda f: (
        SEVERITY_RANK[f["severity"]],
        -f["confidence"],
        f["file"],
        f["line"],
        _norm_text(f["title"]),
    ))

    # Step 8: partition actionable vs report-only (membership by identity —
    # two distinct findings must never compare equal via dict equality).
    actionable_ids = {
        id(f) for f in gated
        if f["autofix_class"] in ("gated_auto", "manual")
        and f["owner"] == "downstream-resolver"
    }
    number_of = {id(f): n for n, f in enumerate(gated, start=1)}
    partition = {
        "actionable": [number_of[id(f)] for f in gated
                       if id(f) in actionable_ids],
        "report_only": [number_of[id(f)] for f in gated
                        if id(f) not in actionable_ids],
    }

    findings_out = [
        _public(f, n) for n, f in enumerate(gated, start=1)
    ]

    # Step 10: union coverage data across validated returns, reviewer-name
    # order, exact duplicates deduped; demoted lines appended last.
    def union(field: str) -> list:
        seen = set()
        out = []
        for r in sorted(returns, key=lambda r: (r["reviewer"], r["source"])):
            for line in r[field]:
                if line not in seen:
                    seen.add(line)
                    out.append(line)
        return out

    residual_risks = union("residual_risks") + residual_risks
    testing_gaps = union("testing_gaps")

    return {
        "findings": findings_out,
        "pre_existing": [_public(f, None) for f in
                         sorted(pre_existing, key=_best_sort_key)],
        "residual_risks": residual_risks,
        "testing_gaps": testing_gaps,
        "partition": partition,
        "coverage": coverage,
    }


def main() -> int:
    args = sys.argv[1:]
    if "--help" in args or "-h" in args:
        print(__doc__.strip())
        return 0
    if len(args) != 1:
        print(
            "Usage: merge-findings.py <compact-dir>\n"
            "Run with --help for full usage.",
            file=sys.stderr,
        )
        return 1

    compact_dir = Path(args[0])
    try:
        result = merge(compact_dir)
    except (ValueError, OSError) as exc:
        print(f"merge-findings.py: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
