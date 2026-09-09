"""Integration tests for skills/ts-code-review/scripts/merge-findings.py.

Encodes the U5 test scenarios for the extracted Stage 5 merge pipeline:
validation and drop semantics, fingerprint dedup with +/-3 line tolerance,
cross-reviewer promotion, pre-existing separation, conflict reporting,
conservative routing and legacy remaps, mode-aware demotion (testing
exemption, corroboration exemption), the late confidence gate with the
P0/P1-at-50+ exception, actionable/report-only partition, sort and stable
numbering, and the CLI contract (--help exit 0, bad input exit 1).
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = (
    Path(__file__).resolve().parent.parent.parent.parent
    / "skills" / "ts-code-review" / "scripts" / "merge-findings.py"
)


def run_merge(compact_dir):
    """Run merge-findings.py against a compact-return directory.

    Returns (parsed_stdout_json_or_None, stderr, returncode).
    """
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(compact_dir)],
        capture_output=True, text=True, check=False,
    )
    payload = json.loads(result.stdout) if result.returncode == 0 else None
    return payload, result.stderr, result.returncode


def stage_returns(tmp_path, returns):
    """Write {filename: return-dict} into tmp_path/compact; return the dir."""
    compact = tmp_path / "compact"
    compact.mkdir()
    for filename, payload in returns.items():
        (compact / filename).write_text(json.dumps(payload), encoding="utf-8")
    return compact


def finding(**overrides):
    """A valid merge-tier finding, overridden per test."""
    base = {
        "title": "Unvalidated redirect",
        "severity": "P1",
        "file": "app/controllers/sessions_controller.rb",
        "line": 42,
        "confidence": 75,
        "autofix_class": "gated_auto",
        "owner": "downstream-resolver",
        "requires_verification": False,
        "pre_existing": False,
    }
    base.update(overrides)
    return base


def finding_under_tail(test_line, **overrides):
    """An off-target finding (different file) so tests can isolate one
    finding's fate without emptying the primary set unintentionally."""
    overrides.setdefault("file", "app/models/other_thing.rb")
    overrides.setdefault("line", test_line)
    return finding(**overrides)


def reviewer_return(name, findings, risks=None, gaps=None):
    return {
        "reviewer": name,
        "findings": findings,
        "residual_risks": risks or [],
        "testing_gaps": gaps or [],
    }


class TestScenario1DedupAndPromotion:
    """Two reviewers, same issue within +/-3 lines, same normalized title."""

    def test_merged_once_promoted_one_step_both_reviewers_recorded(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                # Different case/whitespace title and "./" file prefix --
                # must normalize to the same fingerprint as security's.
                finding(title="Missing Null  Check", file="./src/app.py",
                        line=50, confidence=50),
            ]),
            "security.json": reviewer_return("security", [
                finding(title="missing null check", file="src/app.py",
                        line=52, confidence=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1, "same fingerprint must merge once"
        merged = payload["findings"][0]
        # 50 -> 75: exactly one anchor step for 2-reviewer agreement.
        assert merged["confidence"] == 75
        assert merged["reviewers"] == ["correctness", "security"]
        assert merged["severity"] == "P1"
        assert merged["#"] == 1

    def test_lines_four_apart_do_not_merge(self, tmp_path):
        """Addition (boundary pin for the +/-3 tolerance): 4 lines apart is
        outside the documented tolerance and must stay two findings."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(line=50, confidence=75),
            ]),
            "security.json": reviewer_return("security", [
                finding(line=54, confidence=75),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 2


class TestScenario2ConflictReporting:
    """Same fingerprint, differing severity and autofix_class."""

    def test_keeps_highest_severity_conservative_route_reports_conflict(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(severity="P0", autofix_class="gated_auto",
                        owner="downstream-resolver", confidence=75),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(severity="P1", autofix_class="manual",
                        owner="downstream-resolver", confidence=75),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        merged = payload["findings"][0]
        assert merged["severity"] == "P0", "highest severity wins"
        # Conservative route on disagreement: manual over gated_auto.
        assert merged["autofix_class"] == "manual"

        conflicts = payload["coverage"]["conflicts"]
        assert len(conflicts) == 1
        conflict = conflicts[0]
        positions = {p["reviewer"]: p for p in conflict["positions"]}
        assert set(positions) == {"security", "correctness"}, \
            "conflict must name both reviewers"
        assert positions["security"]["severity"] == "P0"
        assert positions["correctness"]["severity"] == "P1"
        assert positions["security"]["autofix_class"] == "gated_auto"
        assert positions["correctness"]["autofix_class"] == "manual"
        assert conflict["kept"]["severity"] == "P0"


class TestScenario3ReturnLevelMalformation:
    """A return missing a required top-level field drops entirely."""

    def test_missing_residual_risks_drops_whole_return(self, tmp_path):
        broken = {
            "reviewer": "maintainability",
            "findings": [finding(title="Dead code path")],
            "testing_gaps": [],
            # residual_risks missing
        }
        compact = stage_returns(tmp_path, {
            "maintainability.json": broken,
            "correctness.json": reviewer_return("correctness", [
                finding(title="Dead code path"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, "malformed returns drop, they do not fail the run"
        assert len(payload["findings"]) == 1
        assert payload["findings"][0]["reviewers"] == ["correctness"], \
            "the malformed return's finding must not survive"
        dropped = payload["coverage"]["returns_dropped"]
        assert len(dropped) == 1
        assert "residual_risks" in dropped[0]["reason"]


class TestScenario4FindingLevelMalformation:
    """A constraint-violating finding drops; its siblings survive."""

    @pytest.mark.parametrize("bad_override,why", [
        ({"severity": "P4"}, "severity outside the P0-P3 enum"),
        ({"confidence": 72}, "confidence 72 is not a valid anchor"),
    ])
    def test_bad_finding_dropped_and_flagged_sibling_survives(
            self, tmp_path, bad_override, why):
        bad = finding(title="Bad finding", **bad_override)
        sibling = finding(title="Good finding", file="app/models/user.rb",
                          line=7)
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return(
                "correctness", [bad, sibling]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        titles = [f["title"] for f in payload["findings"]]
        assert "Good finding" in titles, "sibling must survive"
        assert "Bad finding" not in titles
        dropped = payload["coverage"]["findings_dropped"]
        assert len(dropped) == 1, why
        assert dropped[0]["reviewer"] == "correctness"
        assert dropped[0]["reason"]


class TestScenario5Demotion:
    """P2 advisory from a single non-testing reviewer demotes."""

    def test_demoted_to_residual_risks_with_count(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "maintainability.json": reviewer_return("maintainability", [
                finding(severity="P2", autofix_class="advisory",
                        owner="human", confidence=75),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert payload["findings"] == [], "demoted finding leaves primary"
        assert payload["residual_risks"] == [
            "app/controllers/sessions_controller.rb:42 -- Unvalidated redirect"
        ]
        assert payload["coverage"]["demoted"] == 1


class TestScenario6TestingExemption:
    """The same shape from the testing reviewer stays primary."""

    def test_testing_reviewer_finding_not_demoted(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "testing.json": reviewer_return("testing", [
                finding(severity="P2", autofix_class="advisory",
                        owner="human", confidence=75),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1, \
            "testing-sourced findings never demote"
        assert payload["coverage"]["demoted"] == 0


class TestScenario7CorroborationExemption:
    """Two reviewers on the same P2 advisory shape keep it primary."""

    def test_two_reviewer_finding_not_demoted(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "maintainability.json": reviewer_return("maintainability", [
                finding(severity="P2", autofix_class="advisory",
                        owner="human", confidence=50),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(severity="P2", autofix_class="advisory",
                        owner="human", confidence=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1, \
            "cross-reviewer corroboration prevents demotion"
        assert payload["coverage"]["demoted"] == 0
        # Corroboration also promotes the anchor: 50 -> 75 keeps it past
        # the gate too.
        assert payload["findings"][0]["confidence"] == 75


class TestScenario8ConfidenceGate:
    """Anchor-50 P1 survives; anchor-50 P2 alone is suppressed by anchor."""

    def test_gate_exception_and_suppression_count(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                # P1 at anchor 50: gate exception, survives.
                finding(title="P1 at fifty", confidence=50),
                # P2 at anchor 50, gated_auto so demotion does not take it:
                # the gate suppresses it.
                finding(title="P2 at fifty", severity="P2",
                        autofix_class="gated_auto", confidence=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        titles = [f["title"] for f in payload["findings"]]
        assert titles == ["P1 at fifty"]
        assert payload["coverage"]["suppressed_by_anchor"] == {"50": 1}


class TestScenario9LegacyRemap:
    """safe_auto / review-fixer remap to gated_auto / downstream-resolver."""

    def test_legacy_values_remapped_before_validation_and_route(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(autofix_class="safe_auto", owner="review-fixer"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, "legacy values must remap, not drop the finding"
        assert len(payload["findings"]) == 1
        merged = payload["findings"][0]
        assert merged["autofix_class"] == "gated_auto"
        assert merged["owner"] == "downstream-resolver"
        assert payload["coverage"]["legacy_remapped"] == 2
        # Remapped route lands in the actionable partition for Stage 6.
        assert merged["#"] in payload["partition"]["actionable"]


class TestScenario10SortAndNumbering:
    """P0 before P1; anchor descending within severity; # monotonic."""

    def test_sort_order_and_monotonic_numbers(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(title="P1 low anchor", confidence=75),
                finding(title="P0 finding", severity="P0", confidence=75),
                finding(title="P1 high anchor", confidence=100),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        ordered = [(f["#"], f["title"]) for f in payload["findings"]]
        # P0 first, then P1 by anchor descending.
        assert ordered == [
            (1, "P0 finding"),
            (2, "P1 high anchor"),
            (3, "P1 low anchor"),
        ]
        assert [n for n, _ in ordered] == [1, 2, 3], \
            "stable # values are monotonic across the full primary set"


class TestScenario11AllEmpty:
    """All reviewers return empty findings: empty primary set, exit 0."""

    def test_empty_returns_produce_empty_merge(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return(
                "correctness", [], risks=["watch the rollout"],
                gaps=["no regression test"]),
            "security.json": reviewer_return("security", []),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert payload["findings"] == []
        assert payload["pre_existing"] == []
        assert payload["residual_risks"] == ["watch the rollout"]
        assert payload["testing_gaps"] == ["no regression test"]


class TestScenario12Help:
    """--help prints usage and exits 0."""

    def test_help_exits_zero(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--help"],
            capture_output=True, text=True, check=False,
        )
        assert result.returncode == 0
        assert "Usage:" in result.stdout


class TestCliContract:
    """Addition: the documented CLI error contract."""

    def test_missing_directory_exits_one_with_stderr(self, tmp_path):
        payload, stderr, rc = run_merge(tmp_path / "does-not-exist")

        assert rc == 1
        assert payload is None
        assert stderr.strip(), "failure must carry a clear stderr reason"

    def test_empty_directory_exits_one(self, tmp_path):
        compact = tmp_path / "compact"
        compact.mkdir()
        _, stderr, rc = run_merge(compact)

        assert rc == 1
        assert "no *.json" in stderr
