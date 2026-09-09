"""Integration tests for skills/ts-code-review/scripts/merge-findings.py.

Encodes the U5 test scenarios for the extracted Stage 5 merge pipeline:
validation and drop semantics, fingerprint dedup with +/-3 line tolerance,
cross-reviewer promotion, pre-existing separation, conflict reporting,
conservative routing and legacy remaps, mode-aware demotion (testing
exemption, corroboration exemption), the late confidence gate with the
P0/P1-at-50+ exception, actionable/report-only partition, sort and stable
numbering, true-promotion counting, the requires_verification OR-merge,
unreadable-return drop-and-continue, and the CLI contract (--help exit 0,
bad input exit 1). Later additions pin the all-returns-dropped fatality,
candidate_lines emission for dedup groups, suggested_fix inheritance from a
sibling, P0 low-anchor suppression, P3 advisory demotion, and the
file/line sort tiebreak.
"""

import json
import os
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


class TestScenario1bIndependentMaxima:
    """Rule 2 pin: "keep highest severity, keep highest anchor" are two
    independent maxima, not a pair taken from the severity-dominant member."""

    def test_severity_and_anchor_maxima_come_from_different_members(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(severity="P0", confidence=50),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(severity="P1", confidence=100),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        merged = payload["findings"][0]
        assert merged["severity"] == "P0", "severity is the group max"
        assert merged["confidence"] == 100, "anchor is the group max (100 stays 100 under promotion)"

    def test_gate_outcome_uses_group_max_anchor(self, tmp_path):
        """Single reviewer returning near-duplicates: P2@50 + P3@100 merges
        to P2@100 and survives the late gate (P2@50 alone would suppress)."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(severity="P2", confidence=50),
                finding(severity="P3", confidence=100),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        merged = payload["findings"][0]
        assert merged["severity"] == "P2"
        assert merged["confidence"] == 100
        assert payload["coverage"]["suppressed_by_anchor"] == {}


class TestScenario1cTransitiveChaining:
    """Rule 1 pin: the +/-3 tolerance chains transitively through a group —
    50, 53, and 56 are each adjacent within 3 lines, so all three merge
    into one finding even though 50 and 56 are 6 lines apart."""

    def test_three_step_chain_merges_into_one(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(line=50, confidence=50),
                finding(line=53, confidence=50),
                finding(line=56, confidence=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1, \
            "50-53-56 must chain into a single finding"
        assert payload["coverage"]["dedup_merges"] == 2
        assert payload["findings"][0]["reviewers"] == ["correctness"]

    def test_gap_of_six_without_intermediate_stays_two(self, tmp_path):
        """Boundary control for the chain: 50 and 56 with no bridging
        finding are 6 lines apart and must remain two findings."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(line=50, confidence=50),
                finding(line=56, confidence=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 2
        assert payload["coverage"]["dedup_merges"] == 0


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


class TestScenario3bReviewerStemMismatch:
    """The compact filename stem is the authoritative reviewer identity. A
    return whose reviewer field disagrees with its filename drops entirely —
    a mis-staged return must not import another reviewer's demotion and
    promotion exemptions."""

    def test_mismatched_reviewer_field_drops_whole_return(self, tmp_path):
        mis_staged = reviewer_return("testing", [
            finding(title="Dodged demotion", severity="P2",
                    confidence=50, autofix_class="advisory",
                    owner="human"),
        ])
        compact = stage_returns(tmp_path, {
            "adversarial.json": mis_staged,
            "correctness.json": reviewer_return("correctness", [
                finding(title="Legit finding"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, "mismatched returns drop, they do not fail the run"
        assert len(payload["findings"]) == 1
        assert payload["findings"][0]["reviewers"] == ["correctness"], \
            "the mis-staged return's finding must not survive"
        dropped = payload["coverage"]["returns_dropped"]
        assert len(dropped) == 1
        assert dropped[0]["file"] == "adversarial.json"
        assert "stem" in dropped[0]["reason"]

    def test_matching_stem_passes_unchanged(self, tmp_path):
        """Sanity control: reviewer == filename stem validates normally."""
        compact = stage_returns(tmp_path, {
            "testing.json": reviewer_return("testing", [
                finding(title="Control finding"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        assert payload["findings"][0]["reviewers"] == ["testing"]
        assert payload["coverage"]["returns_dropped"] == []


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
        # the gate too, and counts as exactly one true promotion.
        assert payload["findings"][0]["confidence"] == 75
        assert payload["coverage"]["promoted"] == 1


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

    def test_file_then_line_tiebreak_within_severity_and_anchor(self, tmp_path):
        """Pin the remaining sort keys: two findings sharing severity and
        anchor order by file path, then line number (both ascending)."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(title="Zeta file", severity="P2",
                        file="app/models/zeta.rb", line=7),
                finding(title="Alpha later line", severity="P2",
                        file="app/models/alpha.rb", line=100),
                finding(title="Alpha earlier line", severity="P2",
                        file="app/models/alpha.rb", line=99),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        ordered = [f["title"] for f in payload["findings"]]
        assert ordered == [
            "Alpha earlier line",
            "Alpha later line",
            "Zeta file",
        ], "lower file path sorts first, then lower line number"


class TestScenario10bPreExistingSeparation:
    """pre_existing: true findings separate into payload["pre_existing"]
    without '#', absent from findings/partition, counted in coverage —
    and the output sort does not KeyError on the merged rep lacking
    reviewer context (regression: reps once had no _reviewer key)."""

    def test_pre_existing_separates_without_number(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(title="stale legacy call", pre_existing=True),
                finding(title="new defect", severity="P2",
                        file="app/models/other_thing.rb", line=7),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert [f["title"] for f in payload["findings"]] == ["new defect"]
        assert len(payload["pre_existing"]) == 1
        pre = payload["pre_existing"][0]
        assert pre["title"] == "stale legacy call"
        assert "#" not in pre, "pre-existing findings carry no stable #"
        assert payload["coverage"]["pre_existing"] == 1
        nums = [f["#"] for f in payload["findings"]]
        assert payload["partition"]["actionable"] == [nums[0]]

    def test_mixed_dedup_group_stays_primary(self, tmp_path):
        """All-members rule: one pre-existing + one new member of the same
        dedup group keeps the merged finding primary (all() is False)."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(title="shared defect", pre_existing=True),
            ]),
            "security.json": reviewer_return("security", [
                finding(title="shared defect", pre_existing=False),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert payload["pre_existing"] == []
        assert len(payload["findings"]) == 1
        assert payload["coverage"]["pre_existing"] == 0
        assert payload["coverage"]["dedup_merges"] == 1


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


class TestScenario13TruePromotionCount:
    """Coverage pin: `promoted` counts only real anchor moves (50 -> 75,
    75 -> 100). Agreement at an anchor the promotion table cannot move
    (0/25/100) changes nothing and must not increment the count."""

    def test_saturated_agreement_not_counted_and_anchor_stays(self, tmp_path):
        """100 is already the ceiling: agreement must leave both the anchor
        and the promoted count untouched."""
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(title="Pinned defect", confidence=100),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(title="Pinned defect", confidence=100),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        assert payload["findings"][0]["confidence"] == 100, \
            "the ceiling anchor must not move"
        assert payload["coverage"]["promoted"] == 0, \
            "100 -> 100 is a no-op, not a promotion"

    @pytest.mark.parametrize("anchor", [0, 25])
    def test_stuck_low_anchor_agreement_not_counted(self, tmp_path, anchor):
        """0/25 stay put under the promotion table: corroborated or not,
        no anchor move means no promotion counted."""
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(title="Low anchor defect", confidence=anchor),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(title="Low anchor defect", confidence=anchor),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert payload["coverage"]["promoted"] == 0


class TestScenario14RequiresVerificationOrMerge:
    """Conservative-routing pin: requires_verification ORs across a dedup
    group (true wins) — one corroborating reviewer flagging it keeps the
    verification requirement on the merged finding."""

    def test_one_true_member_makes_merged_true(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(requires_verification=True, confidence=50),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(requires_verification=False, confidence=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        assert payload["findings"][0]["requires_verification"] is True, \
            "OR-merge: any true member makes the merged flag true"

    def test_all_false_members_merge_false(self, tmp_path):
        """Control for the OR: with no true member the merged flag stays
        false (the OR does not unconditionally set it)."""
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(title="Control defect"),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(title="Control defect"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        assert payload["findings"][0]["requires_verification"] is False


class TestScenario15UnreadableReturnDrop:
    """A return that cannot be READ (permissions, transient I/O) drops with
    a coverage reason like an invalid-JSON return — one unreadable file
    must not abort the merge and discard every other reviewer's validated
    findings. Uses chmod 000 because return_paths filters on is_file(), so
    an unreadable path can only be a file (a directory never reaches the
    read)."""

    @pytest.mark.skipif(
        hasattr(os, "geteuid") and os.geteuid() == 0,
        reason="chmod 000 does not block root from reading",
    )
    def test_unreadable_file_dropped_valid_returns_survive(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(title="Surviving finding"),
            ]),
        })
        bogus = compact / "bogus.json"
        bogus.write_text("{}", encoding="utf-8")
        bogus.chmod(0o000)

        payload, stderr, rc = run_merge(compact)

        assert rc == 0, f"one unreadable return must not fail the run: {stderr}"
        assert [f["title"] for f in payload["findings"]] == \
            ["Surviving finding"], "valid findings must survive"
        dropped = payload["coverage"]["returns_dropped"]
        assert len(dropped) == 1
        assert dropped[0]["file"] == "bogus.json"
        assert dropped[0]["reason"].startswith("unreadable"), \
            f"got: {dropped[0]['reason']}"
        assert payload["coverage"]["returns_total"] == 2


class TestScenario16AllReturnsDropped:
    """When every compact return is dropped (malformed/unreadable) there is
    nothing to merge: the run fails loudly (exit 1) instead of emitting a
    clean zero-findings merge that would post a false APPROVE review."""

    def test_all_returns_dropped_exits_one(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": {
                "reviewer": "correctness",
                "findings": "not-a-list",  # wrong type: whole return dropped
                "residual_risks": [],
                "testing_gaps": [],
            },
            "security.json": {
                "reviewer": "security",
                "findings": [],
                # residual_risks/testing_gaps missing: whole return dropped
            },
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 1, "all returns dropped must be fatal, not a clean merge"
        assert payload is None, "no clean zero-findings output may be printed"
        assert "all 2 compact return(s)" in stderr
        assert "dropped" in stderr

    def test_some_valid_returns_still_merge(self, tmp_path):
        """Control for the fatality: one dropped return among valid ones
        stays non-fatal (the drop-and-continue rule is unchanged)."""
        compact = stage_returns(tmp_path, {
            "correctness.json": {
                "reviewer": "correctness",
                "findings": "not-a-list",
                "residual_risks": [],
                "testing_gaps": [],
            },
            "security.json": reviewer_return("security", [
                finding(title="Survivor"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert [f["title"] for f in payload["findings"]] == ["Survivor"]


class TestScenario17CandidateLines:
    """Merged dedup groups carry every member's (file, line) so downstream
    linemap anchoring (build-review-payload.sh) can fall back when the kept
    representative's primary line is not commentable."""

    def test_dedup_group_carries_all_member_anchors(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(line=50),
            ]),
            "security.json": reviewer_return("security", [
                finding(line=52),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        merged = payload["findings"][0]
        assert merged["candidate_lines"] == [
            ["app/controllers/sessions_controller.rb", 50],
            ["app/controllers/sessions_controller.rb", 52],
        ], "both member anchors, deduped and sorted"

    def test_duplicate_member_anchors_dedupe(self, tmp_path):
        """Two members on the same line dedupe to one candidate — equal to
        the primary anchor, so nothing extra is emitted (schema-minimal:
        candidate_lines carries fallback anchors only)."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(line=50),
            ]),
            "security.json": reviewer_return("security", [
                finding(line=50),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert payload["coverage"]["dedup_merges"] == 1
        assert "candidate_lines" not in payload["findings"][0]

    def test_single_member_group_omits_candidate_lines(self, tmp_path):
        """Schema-minimal pin: single-member groups carry no candidate_lines
        (nothing to fall back through)."""
        compact = stage_returns(tmp_path, {
            "correctness.json": reviewer_return("correctness", [
                finding(title="Lone finding"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert "candidate_lines" not in payload["findings"][0]


class TestScenario18SuggestedFixInheritance:
    """The merged suggested_fix falls back to a sibling's when the kept
    representative (highest severity/anchor) carries none."""

    def test_best_without_fix_inherits_sibling_fix(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                # Highest severity: becomes the kept representative, no fix.
                finding(severity="P0", confidence=75),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(severity="P1", confidence=75,
                        suggested_fix="Allowlist the redirect target"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        merged = payload["findings"][0]
        assert merged["severity"] == "P0", "security's P0 is the group max"
        assert merged["suggested_fix"] == "Allowlist the redirect target", \
            "merged suggested_fix equals the sibling's"

    def test_no_member_with_fix_omits_field(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(severity="P0"),
            ]),
            "correctness.json": reviewer_return("correctness", [
                finding(severity="P1"),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert len(payload["findings"]) == 1
        assert "suggested_fix" not in payload["findings"][0]


class TestScenario19P0LowAnchorSuppressed:
    """Gate pin: the P0/P1 exception requires anchor 50+ — a P0 at 25 is
    suppressed and counted by anchor, not passed through on severity alone."""

    def test_p0_at_twentyfive_suppressed_by_anchor(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "security.json": reviewer_return("security", [
                finding(severity="P0", confidence=25),
            ]),
        })
        payload, stderr, rc = run_merge(compact)

        assert rc == 0, stderr
        assert payload["findings"] == [], "P0 at anchor 25 is below the gate"
        assert payload["coverage"]["suppressed_by_anchor"] == {"25": 1}


class TestScenario20P3AdvisoryDemotion:
    """Demotion covers P3 as well as P2: a single non-testing reviewer's P3
    advisory demotes to residual_risks with the demoted count."""

    def test_p3_advisory_single_reviewer_demoted(self, tmp_path):
        compact = stage_returns(tmp_path, {
            "maintainability.json": reviewer_return("maintainability", [
                finding(severity="P3", autofix_class="advisory",
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
