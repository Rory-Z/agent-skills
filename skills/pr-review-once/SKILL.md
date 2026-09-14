---
name: pr-review-once
description: Review one pull-request head with a single agent across Standards, Spec, and Ponytail, publish a SHA-bound Review Result, and stop. Use for a one-shot PR review without automatic re-review or fixes.
---

# PR Review Once

Perform one Review Cycle in the current agent. Build one shared understanding of the change, check all three perspectives, and report them separately. Do not spawn review sub-agents or invoke the code-review, ponytail-review, or pr-review-loop workflows. The session owns model selection.

## Arguments

- PR number or URL, optional when the current branch already has a PR.
- `--spec <path>`, optional explicit spec.

## Boundaries

- Run from the same-repository PR head branch with a clean worktree. Support one active Review Session per PR, including loop sessions.
- **Inspection-only:** review sources and existing evidence. Do not run local tests, linters, builds, formatters, type checks, or validation commands.
- Derive conclusions from this Review Cycle. Never read PR conversation comments, review bodies, inline comments, or their markers. Linked issue comments are available as spec evidence.
- Do not checkout, stash, reset, rebase, force-push, merge, edit code, or change PR metadata. The one Review Result comment is the publication output.

## Preflight

1. Resolve repository, PR number, URL, state, base branch, head branch, and head SHA with `gh`. Stop if the PR is not open or is from a fork.
2. Require the current branch to equal the PR head branch and the worktree to be clean. If the remote head is ahead, fetch and fast-forward only. Stop on divergent history or if local `HEAD` still differs from the remote head.
3. Fetch the base branch. Capture its commit SHA as `REVIEWED_BASE` and the exact PR head SHA as `REVIEWED_HEAD`. Use `git diff <REVIEWED_BASE>...<REVIEWED_HEAD>` and the corresponding commit list throughout this Review Cycle.

## Review

Read the repository instructions, relevant domain docs and standards. Resolve the Spec from `--spec` when supplied; otherwise inspect originating issue references in the PR description and commit messages, using the repository's issue-tracker instructions, then matching spec files under `docs/`, `specs/`, or `.scratch/`. Read linked issues and relevant issue comments. An unavailable explicit spec is a blocker, not permission to substitute another source.

Inspect the entire diff once, sharing context across the following perspectives. Follow affected callers, implementations, contracts, and existing tests as needed to establish behavior; the diff is the entry point, not the evidence boundary. Revisit code when a finding needs verification, rather than performing three separate full reads.

- **Standards:** identify documented repository-standard violations, citing the rule and source. Repository rules override general style preferences. Treat code smells as advisory judgments; skip style checks already enforced by tooling.
- **Spec:** check missing or partial requirements, incorrect implementations, and unrequested scope. Cite the requirement supporting each finding. Trace correctness, safety, and security consequences of the changed behavior, including relevant sibling callers.
- **Ponytail:** identify concrete opportunities to delete unnecessary abstractions, speculative flexibility, duplicate code, or custom implementations covered by existing code, stdlib, or native features. State the location, what to cut, and the simpler replacement. Preserve required behavior and safeguards.

Record findings with file/line references, evidence, and the concrete consequence. Separate **Blocking findings** from **Advisories** and deduplicate defects without losing their supporting evidence.

A finding blocks only for a documented-standard violation, concrete Spec defect or scope violation, or diff-attributable correctness, safety, or security defect. Code smells and Ponytail suggestions are advisory. If the same behavior violates the Spec, support that blocking finding with Spec evidence rather than promoting a simplification preference.

## Result and publication

Classify the result:

- `blocked`: the diff is empty, the Spec or required evidence is unavailable, or any perspective could not be completed. Explain the gap; never claim a pass from an incomplete review.
- `changes-requested`: the review completed and at least one Blocking finding exists.
- `pass`: all three perspectives completed with no Blocking findings; Advisories may remain.

Immediately before publication, re-read the PR state and head SHA. If closed, stop. If the head changed, discard the result, report the reviewed and current SHAs to the user, and stop without publishing or restarting. A later invocation must review the new head afresh.

Publish exactly one new top-level comment with `gh pr comment --body-file`, using a temporary file outside the worktree. Never edit or delete earlier results. Use the existing marker below for compatibility with `pr-fix-loop`; its name identifies the protocol, not the execution mode.

```md
Review mode: single agent, one Review Cycle

## Blocking findings

### Standards
<findings, or None.>

### Spec
<findings, or None.>

### Correctness, safety, or security
<defects not already listed, or None.>

## Advisories

### Standards
<observations, or None.>

### Ponytail
<simplifications, or None.>

Reviewed base: <REVIEWED_BASE>
Reviewed head: <REVIEWED_HEAD>

<!-- pr-review-loop:v1 head=<REVIEWED_HEAD> verdict=<verdict> -->
```

For `pass`, start with `LGTM` and put `None.` under Blocking findings. For `blocked`, add `## Review blocker` with the exact gap and mark unevaluated finding sections `Not evaluated.`; retain any established findings without implying complete coverage. The authoritative marker must be the final line.

After publication, report the result URL, reviewed head, and verdict, then end the turn for every verdict. On publication failure, report the failure and stop; if the write outcome is uncertain, do not retry blindly. Do not wait for commits or feedback, begin another Review Cycle, or apply fixes. Fixes require a separate fix invocation; reviewing its successor requires a new review invocation.
