---
name: pr-review-loop
description: Review a pull request from scratch with a single agent across Standards, Spec, and Ponytail, publish a SHA-bound Review Result, and wait for new commits. Use for an adversarial PR review loop; do not use to apply fixes.
---

# PR Review Loop

Review every new pull-request head in the current Review Session with one agent across Standards, Spec, and Ponytail. Do not inherit conclusions from PR conversation history or earlier Review Sessions.

## Arguments

- PR number or URL, optional when the current branch already has a PR.
- `--spec <path>`, optional explicit spec.

## Boundaries

- Run from the same-repository PR head branch. Support one active Review Session per PR.
- **Inspection-only:** review repository sources and existing evidence. Do not run local tests, linters, builds, formatters, type checks, or validation commands.
- Never read PR conversation comments, review bodies, inline comments, or their markers. Linked issue comments remain available as Spec evidence.
- The current agent owns model selection and the full review context. Do not spawn review sub-agents or invoke `$code-review`, `$ponytail:ponytail-review`, or `$pr-review-once`.
- Do not checkout, stash, reset, rebase, force-push, merge, edit code, or change PR metadata.

## Preflight

1. Resolve the repository, PR number, URL, state, base branch, head branch, and head SHA with `gh`. Stop if the PR is not open or comes from a fork.
2. Require the current branch to equal the PR head branch. Require a clean worktree.
3. If the remote head is ahead, fetch and fast-forward the current branch. Stop on divergent history or if local `HEAD` still differs from the PR head SHA.
4. Fetch the base branch and use `origin/<base>` as the fixed point. Confirm `<fixed-point>...HEAD` is non-empty.

## Review Cycle

1. Capture the exact PR head SHA as `REVIEWED_HEAD`.
2. Read repository instructions, relevant domain docs, and standards. Resolve the Spec from `--spec` when supplied; otherwise inspect originating issue references in the PR description and commit messages, using the repository's issue-tracker instructions, then matching spec files under `docs/`, `specs/`, or `.scratch/`. Read linked issues and relevant issue comments. If the Spec is unavailable, classify the Review Cycle as blocked.
3. Inspect the entire diff once in the current agent, sharing context across these perspectives. Follow affected callers, implementations, contracts, and existing tests as needed to establish behavior; revisit code when a finding needs verification.
   - **Standards:** identify documented repository-standard violations, citing the rule and source. Treat code smells as advisory judgments; skip style checks already enforced by tooling.
   - **Spec:** check missing or partial requirements, incorrect implementations, and unrequested scope. Cite the requirement supporting each finding. Trace correctness, safety, and security consequences of the changed behavior, including relevant sibling callers.
   - **Ponytail:** identify concrete opportunities to delete unnecessary abstractions, speculative flexibility, duplicate code, or custom implementations covered by existing code, stdlib, or native features. State the location, what to cut, and the simpler replacement. Preserve required behavior and safeguards.
4. Separate the review output into **Blocking findings** and **Advisories**, deduplicating defects without losing their supporting evidence. A finding blocks only when it identifies at least one of:
   - a documented repository-standard violation;
   - a concrete Spec omission, incorrect implementation, or scope violation;
   - a concrete correctness, safety, or security defect attributable to the diff.

   Code smells and Ponytail suggestions are advisory. When the same behavior is unrequested scope, support the Blocking finding with Spec evidence rather than promoting a simplification preference.
5. Classify the Review Result:
   - `changes-requested`: at least one Blocking finding exists.
   - `pass`: all three perspectives completed and no Blocking finding exists, including when Advisories are present.
   - `blocked`: the Spec is unavailable, the diff is empty, or the review cannot be completed.
6. Re-read the PR state and head SHA before publishing. If the PR closed, stop. If the SHA changed, discard the entire Review Result without publishing, synchronize the clean worktree, and start a new Review Cycle.
7. Publish exactly one new top-level Review Result with `gh pr comment --body-file`. Never edit or delete an earlier Review Result.

For `changes-requested`, preserve the separate review perspectives:

```md
Review mode: single agent, looping Review Session

## Blocking findings

### Standards
<documented-standard violations, or "None.">

### Spec
<concrete Spec defects or scope violations, or "None.">

### Correctness, safety, or security
<concrete diff-attributable defects not already listed, or "None.">

## Advisories

### Standards
<baseline smells and other non-blocking observations, or "None.">

### Ponytail
<full Ponytail result, or "None.">

Reviewed head: <REVIEWED_HEAD>

<!-- pr-review-loop:v1 head=<REVIEWED_HEAD> verdict=changes-requested -->
```

For `pass`, publish:

```md
LGTM

Review mode: single agent, looping Review Session

## Blocking findings

None.

## Advisories

### Standards
<baseline smells and other non-blocking observations, or "None.">

### Ponytail
<full Ponytail result, or "None.">

Reviewed head: <REVIEWED_HEAD>

<!-- pr-review-loop:v1 head=<REVIEWED_HEAD> verdict=pass -->
```

For `blocked`, keep the two finding classes explicit and end with:

```md
Review mode: single agent, looping Review Session

## Review blocker

<exact blocker>

## Blocking findings

Not evaluated.

## Advisories

Not evaluated.

Reviewed head: <REVIEWED_HEAD>

<!-- pr-review-loop:v1 head=<REVIEWED_HEAD> verdict=blocked -->
```

## Classification examples

| Evidence | Result |
| --- | --- |
| No documented Standards violation, Spec passes, a baseline smell remains, and Ponytail suggests deletion | `pass`; retain both suggestions under Advisories |
| The diff omits a concrete Spec requirement | `changes-requested`; list the omission under Blocking findings |

After `changes-requested`, run [scripts/wait-for-head.sh](scripts/wait-for-head.sh), resolving the path relative to this `SKILL.md`:

```bash
scripts/wait-for-head.sh <owner/repo> <pr-number> <REVIEWED_HEAD>
```

Keep the helper in the foreground; never detach it with `&`, `nohup`, or a service manager. If the command runner yields a live terminal session while the helper is still running, keep this agent turn open and poll that same session until the helper exits. Do not send a final answer or mark the task complete while that session is live. It reads GitHub every ten minutes without invoking an LLM. On `head<TAB><sha>`, synchronize the clean worktree and begin another Review Cycle. Stop on `closed`, three consecutive read failures, `pass`, or `blocked`.
