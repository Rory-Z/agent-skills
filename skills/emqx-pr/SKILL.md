---
name: emqx-pr
description: Create or update an EMQX pull request, optionally track it in GitHub Projects, and require passing PR checks; use when the user invokes /emqx-pr or asks for the EMQX PR workflow
---

# EMQX PR Workflow

Publish the current branch as an EMQX pull request.

This skill prepares and publishes a committed snapshot, optionally tracks it in a project, and waits for the PR checks to pass. It does not independently run local tests, invoke code review, or run Ponytail review before publishing.

## Args

- `--project` (optional, bare flag): track a draft issue item in org `emqx`. Use project `32` when the repository name contains `flowmq` case-insensitively; otherwise use project `18`.

## Workflow

### 1. Prepare a committed snapshot

1. Confirm the branch with `git branch --show-current`. If it is empty, stop and report the detached HEAD. In Codex App, tell the user to use **Create branch** or **Hand off to local**.
2. Determine the base branch:
   - Prefer `gh pr view --json baseRefName --jq .baseRefName` for an existing PR.
   - Otherwise use `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
   - If that fails, use the first existing local branch among `master` and `main`; ask only if neither exists.
3. Refresh the base with `git fetch origin <base-branch>` and use `origin/<base-branch>` as `<base-ref>` when available; otherwise use the resolved local base branch.
4. Inspect `git status --short` and the diff. Preserve unrelated user changes. If unrelated changes prevent a clean PR snapshot, stop and ask the user to isolate them; do not stash or commit them.
5. Treat uncommitted requested changes as direct edits. Do not run tests, linters, builds, or other validation here.
6. Stage only requested files and commit them with a Conventional Commit message. If the worktree is already clean, do not create a no-op commit.
7. Stop when `<base>...HEAD` is empty, whether or not a PR already exists. Do not create a no-op commit or PR.
8. For an existing PR, fetch and use its title and body. Otherwise derive a Conventional Commit title and body from the commits, diff, linked issue or spec, and repository PR template. Ask only if materially ambiguous.

### 2. Push and create or find the PR

1. Push the prepared committed snapshot with `git push -u origin HEAD`.
2. Create the PR with `gh pr create --base <base> --head <branch> --title "<title>" --body "<body>"`. If one already exists, fetch it with `gh pr view --json number,url,title,body,headRefOid` and continue.
3. Assign it to the current GitHub user:
   ```sh
   login=$(gh api user --jq .login)
   gh pr edit <pr-number> --add-assignee "$login"
   ```
   Record an assignment failure and continue.
4. Confirm the PR's remote `headRefOid` equals local `HEAD`. Keep the PR, branch, and worktree available for follow-up work.

### 3. Create optional project tracking

When `--project` is present:

1. Select the project:
   ```sh
   repo_name=$(gh repo view --json name --jq .name 2>/dev/null || basename "$(git rev-parse --show-toplevel)")
   case "$(printf '%s' "$repo_name" | tr '[:upper:]' '[:lower:]')" in
     *flowmq*) project_number=32; project_url=https://github.com/orgs/emqx/projects/32 ;;
     *) project_number=18; project_url=https://github.com/orgs/emqx/projects/18 ;;
   esac
   ```
2. Create a draft issue item whose title is the PR title verbatim and whose body is the PR body followed by `PR: <pr-url>`.
3. Resolve the project ID plus the `Status` field and its exact `In Progress` and `In Review` option IDs with `gh project view` and `gh project field-list`, then set the item to `In Progress` with `gh project item-edit`.
4. Track the draft issue item, not the PR itself, unless explicitly requested. After the PR exists, set the item to `In Review`. Treat missing tools, scopes, permissions, project access, fields, options, or network access as non-fatal. Record the exact failure and any created item ID or URL, then continue.

### 4. Require passing PR checks

1. Run `gh pr checks <pr-number> --watch --fail-fast` after the PR is created or found. A new PR can briefly report no checks before workflows register; wait briefly and retry. If no checks appear, report that checks could not be verified rather than calling them passed.
2. If a check fails, inspect its details and use the smallest applicable path:
   - Fix an obvious, scoped lint, formatting, generated-file, build-wiring, or code error directly. An existing failing test already supplies the red step; do not add a duplicate test.
   - For a hard, intermittent, or regression failure without a clear root cause, invoke `/diagnosing-bugs` with the check name, exact PR head SHA, failure details, and the smallest reproducible command. It owns diagnosis and the regression test, so do not also invoke `/tdd`.
   - Invoke `/tdd` only for a well-understood behavior fix that lacks regression coverage, after confirming the public test seam with the user. If the original issue or spec is incomplete, return to `/implement`; it drives `/tdd` internally, so do not invoke it separately.
   - Report unrelated, external-flake, infrastructure, permission, or authentication failures as blockers instead of changing unrelated code.
3. For an attributable fix, commit and push it, confirm the remote `headRefOid` equals local `HEAD`, and wait again.
4. Before reporting success, confirm the PR's `headRefOid` still equals local `HEAD` and rerun `gh pr checks <pr-number>`. Do not report success while any check is pending or failing, or when the exact-head result could not be verified.

## Final response

Report the PR link, final `HEAD_SHA`, and exact-head PR check result. Include the project URL plus item ID or URL when requested. Name any check-fix skill and local verification used; otherwise state that local tests were not independently run before publishing. State that code review and Ponytail review were not independently run by this skill. Report `Project: failed - <reason>` when project tracking failed, and name any check that prevents success.
