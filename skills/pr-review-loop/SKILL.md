---
name: pr-review-loop
description: Review a pull request from scratch with code-review and Ponytail, publish a SHA-bound Review Result, and wait for new commits. Use for an adversarial PR review loop; do not use to apply fixes.
---

# PR Review Loop

Review every new pull-request head in the current Review Session without inheriting conclusions from PR conversation history or earlier Review Sessions.

## Arguments

- PR number or URL, optional when the current branch already has a PR.
- `--spec <path>`, optional explicit spec for `$code-review`.

## Boundaries

- Run from the same-repository PR head branch. Support one active Review Session per PR.
- **Inspection-only:** review repository sources and existing evidence. Do not run local tests, linters, builds, formatters, type checks, or validation commands.
- Never read PR conversation comments, review bodies, inline comments, or their markers. Linked issue comments remain available to `$code-review` as spec evidence.
- Do not choose or rotate models. The Codex session owns model selection.
- Do not checkout, stash, reset, rebase, force-push, merge, edit code, or change PR metadata.

## Preflight

1. Resolve the repository, PR number, URL, state, base branch, head branch, and head SHA with `gh`. Stop if the PR is not open or comes from a fork.
2. Require the current branch to equal the PR head branch. Require a clean worktree.
3. If the remote head is ahead, fetch and fast-forward the current branch. Stop on divergent history or if local `HEAD` still differs from the PR head SHA.
4. Fetch the base branch and use `origin/<base>` as the fixed point. Confirm `<fixed-point>...HEAD` is non-empty.

## Review Cycle

1. Capture the exact PR head SHA as `REVIEWED_HEAD`.
2. Use `$code-review` against `<fixed-point>...HEAD`, passing the Inspection-only boundary to both review sub-agents. Pass `--spec` when supplied. If its normal discovery finds no Spec, do not pause the monitoring workflow to ask for one; classify the Review Cycle as blocked.
3. Independently use `$ponytail:ponytail-review` against the same diff with the Inspection-only boundary. Do not feed either review's conclusions into the other.
4. Separate the review output into **Blocking findings** and **Advisories**. A finding blocks only when it identifies at least one of:
   - a documented repository-standard violation;
   - a concrete Spec omission, incorrect implementation, or scope violation;
   - a concrete correctness, safety, or security defect attributable to the diff.

   Fowler baseline smells from `$code-review` are always advisories unless separate evidence establishes one of those blocking categories. Every `$ponytail:ponytail-review` finding is advisory; when the same behavior is unrequested scope, state the independently supported Spec finding under Blocking findings rather than promoting the Ponytail text.
5. Classify the Review Result:
   - `changes-requested`: at least one Blocking finding exists.
   - `pass`: both reviews completed and no Blocking finding exists, including when Advisories are present.
   - `blocked`: the Spec or a required skill is unavailable, the diff is empty, or a review fails.
6. Re-read the PR state and head SHA before publishing. If the PR closed, stop. If the SHA changed, discard the entire Review Result without publishing, synchronize the clean worktree, and start a new Review Cycle.
7. Publish exactly one new top-level Review Result with `gh pr comment --body-file`. Never edit or delete an earlier Review Result.

For `changes-requested`, preserve the separate review perspectives:

```md
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
