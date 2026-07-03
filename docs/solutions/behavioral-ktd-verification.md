# Behavioral KTD Criteria

This document defines what a `[behavioral]` KTD is, how to write one that can be verified, and how to verify that an implementation satisfies it. It applies to plan authors, to `ts-verify-implementation` (Completeness and Correctness subagents), and to `ts-work` (implementer constraints).

## What is a behavioral KTD?

A `[behavioral]` KTD specifies a pattern, approach, or constraint — not a literal string. It describes *what the implementation must do* or *how it must behave*, not the exact characters it must contain.

Examples:
- "The skill is based on ts-code-review's existing plan discovery logic" — describes an architectural approach
- "On ambiguity, always ask the user — never silently pick" — describes a behavioral constraint
- "The script returns the plan path or empty — it does not prompt the user" — describes an interface contract

### Classification test

A KTD is behavioral if two structurally different implementations could both satisfy it. If only one exact output satisfies the KTD (a specific filename, a specific string, a specific schema), it is `[literal]`.

**Mixed KTDs must be split at authoring time.** "Based on ts-code-review's discovery logic, and the command must be named `find-plan`" is one behavioral KTD and one literal KTD. A verifier receiving a mixed KTD should flag it as a plan defect, then verify each part under its correct rubric.

## Writing a verifiable behavioral KTD

Plan authors: verifiers can only check what the KTD makes checkable. Each rule below exists because the verification approach depends on it.

1. **State constraints explicitly.** Prefer "must", "never", "always", "only", "does not". A constraint the author leaves implicit may not be extracted, and an unextracted constraint is unverified.
2. **Cite precedent when the pattern is mandatory.** "Based on ts-code-review's plan discovery logic" binds the implementer to that pattern. An uncited KTD ("discovers the plan from the docs directory") grants the implementer structural freedom — the verifier will treat any intent-preserving approach as a match. If you require the pattern, cite it; if you omit the citation, you are granting the freedom.
3. **Make interface contracts concrete.** "Returns the plan path or empty" is checkable (return type, no-raise behavior). "Handles missing plans gracefully" is not — "gracefully" has no verification procedure.
4. **State the failure behavior, not just the success behavior.** "Returns path or empty" implies but does not state "never raises on missing". If the failure behavior matters, write it as its own constraint.

## Verification approach

For each `[behavioral]` KTD, verification covers three dimensions:

### 1. Intent preservation

Does the implementation preserve the *purpose* of the KTD? This is the primary check.

**Test:** Reading only the implementation, could a reviewer independently reconstruct the behavior the KTD describes? If the code alone evidences the described pattern, constraint, or contract, intent is preserved.

**Evidence to look for:**
- The implementation's code structure matches the KTD's described pattern (e.g., "based on X" → the implementation imports or mirrors X's approach)
- The implementation's behavior matches the KTD's described constraint (e.g., "ask user on ambiguity" → the code contains a user-prompt path for ambiguous cases)
- The implementation's interface matches the KTD's described contract (e.g., "returns path or empty" → the function returns a string or None, never raises on missing)

### 2. Constraint satisfaction

Does the implementation satisfy every *constraint* stated in the KTD?

**Definition:** A constraint is any statement in the KTD whose violation would make the implementation wrong. The markers "must", "never", "always", "does not", and "only" are heuristics for finding candidate constraints — they are not the definition of the set. Constraints can be stated without markers: "the script returns the plan path or empty" constrains the return contract even though no modal verb appears. Extract by asking of each sentence: "if the implementation contradicted this, would it be a defect?"

**Verification by constraint type:**
- **"Must" constraints (required behavior):** confirm the code path exists and is reachable. Identify the call site or entry point that triggers it.
- **"Never" constraints (forbidden behavior):** grep is insufficient — it proves absence of a string, not absence of a behavior. A fallback that silently picks the most-recent file is a `sort()` on an mtime list, not a greppable phrase. Trace the code paths where the forbidden behavior could occur and confirm no branch produces it.
- **"Always" constraints (unconditional behavior):** enumerate the entry points and branches that reach the relevant code, and confirm each one exhibits the behavior. "No edge case bypasses it" is the conclusion of that enumeration, not a check in itself.

### 3. Scope fidelity

Does the implementation stay within the scope described by the KTD?

**Test:** "Does the implementation do more or less than the KTD describes?"

Ownership of the two halves is split across lanes (see "How subagents use this"):
- **Omission** — behavior the KTD requires but the implementation lacks — is a Completeness finding.
- **Addition (scope creep)** — behavior the implementation has but the KTD doesn't describe — is owned by the Scope subagent, not by this rubric's lanes. Completeness and Correctness verifiers who notice scope creep note it in passing without filing it as their own finding, to avoid duplicates.

**Significance test for scope creep:** an addition is significant if it introduces new persistence, new external side effects, new user-facing surface, or new files. Additional defensive handling *within* the described behavior (input validation, clearer error messages on the already-described failure path) is not significant and is acceptable under a match.

## Match vs mismatch

**Match:** The implementation preserves intent, satisfies all constraints, and omits nothing the KTD requires. Minor implementation differences (different variable names, different control flow structure, additional error handling within described behavior) are acceptable as long as intent is preserved.

**Mismatch — intent violation:** The implementation does not achieve what the KTD described. Example: KTD says "ask user on ambiguity" but the implementation silently picks the first match.

**Mismatch — constraint violation:** The implementation violates a stated constraint. Example: KTD says "never silently pick most recent" but the implementation falls back to most-recent when no keywords match.

**Mismatch — omission:** The implementation lacks behavior the KTD requires. Example: KTD says "prompts the user when multiple plans match" but no prompt path exists.

**Scope creep** (significant additions per the test above) is reported by the Scope subagent as its own finding class, not as a mismatch under this rubric.

## Ambiguous cases

When intent preservation is debatable:

1. **Check the KTD's evidence.** If the KTD cites a specific pattern or precedent, the implementation must follow that pattern. If it doesn't cite one, the implementer has more freedom.
2. **Check the KTD's constraints.** Constraints are hard boundaries. If the implementation satisfies all constraints but the intent is arguable, it's a match.
3. **When still ambiguous:** Flag as a finding at the advisory confidence level defined in the subagent template's confidence rubric. Describe the ambiguity and let the operator decide.

When a *constraint* is ambiguous — the statement is extractable but its meaning is unclear ("handles errors appropriately") — that is a plan defect, not a verification judgment call. Flag it as an advisory finding against the plan, and verify the implementation against the most conservative plausible reading.

## How subagents use this

The lane boundary: **Completeness owns presence, Correctness owns fidelity.** Completeness asks "is every KTD addressed at all?" Correctness asks "does the addressed behavior actually match?" A KTD with no corresponding implementation is a Completeness finding; a KTD with a corresponding implementation that behaves wrongly is a Correctness finding. Neither lane re-verifies the other's dimension.

### ts-verify-implementation — Completeness subagent

For each `[behavioral]` KTD:
1. Find the implementation code referenced by the KTD
2. Check intent preservation — reading only the code, does it evidence the behavior the KTD describes?
3. Check for omissions — behavior the KTD requires with no corresponding code path
4. Report: PASS (KTD is addressed and nothing required is missing), FAIL (KTD unaddressed, or required behavior omitted), or ADVISORY (ambiguous intent, per the ambiguity rules)

Completeness does not verify constraint satisfaction — confirming the prompt path *exists* is Completeness; confirming it fires in the right cases is Correctness.

### ts-verify-implementation — Correctness subagent

For each `[behavioral]` KTD:
1. Extract the constraints per the definition above (semantic extraction, markers as heuristic)
2. Verify each constraint per its type: reachable path for "must", traced branches for "never", enumerated entry points for "always"
3. Verify the implementation's interface matches the KTD's described contract
4. Report: PASS, FAIL with the specific violated constraint and the code path that violates it, or ADVISORY (ambiguous constraint, flagged as plan defect)

Correctness does not re-check presence — a KTD with no implementation at all is Completeness's finding, and Correctness skips it as N/A.

### ts-work — Implementer

For each `[behavioral]` KTD:
1. Extract the constraints (same semantic definition the verifiers use) and treat them as a pre-implementation checklist
2. After implementation, confirm each constraint is satisfied, citing the code path that satisfies it
3. Self-check scope before handoff: any new persistence, external side effects, user-facing surface, or files not described by the plan must be either removed or explicitly surfaced to the operator as intentional additions

The implementer self-check does not replace verification — it exists to catch violations before they cost a verification round.
