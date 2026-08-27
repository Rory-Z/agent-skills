---
name: weekly-report
description: Generate a Chinese-style weekly report (周报) from the user's recent GitHub pull request, issue, and release activity. Use when the user asks for a weekly report, 周报, a summary of what they did last week, or a recap of GitHub PRs, issues, and releases during a specific week.
---

# Weekly Report (周报)

## Overview

Generate a concise Chinese-style weekly report from GitHub PR, issue, and
release activity for a calendar week computed in UTC+8 (Asia/Shanghai). Group
work by repository, summarize themes, and link every PR, issue, and release in
Markdown format. Use Mainland China public holiday and makeup-workday
exceptions from the script output when discussing workday/weekend activity. Do
not add a "下周计划" section.

## Workflow

1. Gather PR and release data with the bundled script. By default it uses the
   previous full calendar week (Monday-Sunday) in UTC+8 and the current
   authenticated `gh` user. The script also prints Mainland China holiday and
   makeup-workday exceptions from `daily-report/data/china-workdays.tsv`:

   ```bash
   ${CODEX_HOME:-$HOME/.codex}/skills/weekly-report/scripts/gather-prs.sh
   ```

   For a specific week or user, pass explicit dates in UTC+8, inclusive:

   ```bash
   ${CODEX_HOME:-$HOME/.codex}/skills/weekly-report/scripts/gather-prs.sh 2026-06-01 2026-06-07
   ${CODEX_HOME:-$HOME/.codex}/skills/weekly-report/scripts/gather-prs.sh 2026-06-01 2026-06-07 github-login
   ```

   Keep the queried range as the full calendar week so makeup weekend work is
   not missed. Update the shared `daily-report/data/china-workdays.tsv` when
   the next year's State Council holiday notice is published.

2. Gather issue data for the same UTC+8 week. Include issues created by the
   user in the window, and issues fixed in the window. Treat "fixed" as issues
   closed in the window involving the user plus `closingIssuesReferences` from
   merged PRs in the report:

   ```bash
   gh search issues --author USER --created "${START}T00:00:00+08:00..${END}T23:59:59+08:00" --limit 100 --json repository,number,title,state,url,createdAt,closedAt
   gh search issues --involves USER --closed "${START}T00:00:00+08:00..${END}T23:59:59+08:00" --limit 100 --json repository,number,title,state,url,createdAt,closedAt
   gh pr view PR_URL --json closingIssuesReferences
   ```

3. Write the report from the script and issue output:

   - Title: `# 周报（START ~ END）`
   - `本周概览`: total merged PR count, release count when present, main
     workstreams, issue counts when present, and whether the weekend was clear
     if the data and China workday calendar show no weekend workday activity.
   - Project sections: one `##` section per repo, or per theme when a repo has
     many PRs. Include every repository; never filter out repos.
   - PR bullets: include only merged PRs. Do not include PRs that were closed
     without being merged.
   - PR bullets: describe in Chinese what changed and why it matters, then end
     with Markdown links such as `[owner/repo#123](https://github.com/owner/repo/pull/123)`.
   - Issue bullets: include created and fixed issues when present, using
     Markdown links such as `[owner/repo#123](https://github.com/owner/repo/issues/123)`.
   - Release bullets: include published releases from the script output when
     present. Explain what shipped and use Markdown links such as
     `[owner/repo@tag](https://github.com/owner/repo/releases/tag/tag)`.
   - `本周亮点`: 2-4 cross-cutting highlights such as API changes, security
     fixes, issues fixed, releases, or cross-repo coordination.

4. Always write the weekly report body in Chinese, regardless of the active
   session language preference or English Tutor level. Preserve technical
   identifiers, repository names, tag names, PR titles, and issue titles when
   useful.

## GitHub Query Gotchas

| Gotcha | Rule |
|--------|------|
| `--merged` is a boolean flag in `gh search prs` | Use `--merged-at="START..END"` for a date range. |
| GitHub date qualifiers default to UTC | Append `+08:00` timestamps so midnight work lands on the correct UTC+8 day. |
| Release timestamps are returned in UTC | Convert the UTC+8 week bounds to UTC before filtering release `publishedAt`. |
| Closed PRs are not shipped work | Include merged PRs only; exclude PRs closed without merge. |
| `gh search prs` defaults to a low limit | Pass `--limit 100` so a busy week is not truncated. |
| Issue search cannot prove every fixing PR | Combine closed issues involving the user with PR `closingIssuesReferences`. |
| China holidays and makeup workdays change yearly | Use the script's `CHINA WORKDAY CALENDAR` section; update the shared TSV after the State Council notice. |

## Output Style

- Keep the report concise and scannable so a manager or teammate can understand
  the week in about 30 seconds.
- Always write headings, summaries, PR explanations, release explanations, and
  highlights in Chinese. Do not switch the report prose to English even if the
  surrounding Codex session is using English.
- Describe impact, not mechanics. Prefer "副本数下降时保持 Degraded 而非误报
  Provisioning" over restating the PR title.
- Include merged PRs as shipped work. Mention opened PRs only if they were also
  merged, or if the user explicitly asks for in-progress work.
- Include GitHub releases as shipped work when the script reports them, grouped
  with the relevant repo or called out in highlights.
- Include issues created and issues fixed when present, grouped with the
  relevant repo or in a compact `本周 Issue` section.
- Format every PR, issue, and release as Markdown links:
  `[owner/repo#123](https://github.com/owner/repo/pull/123)`,
  `[owner/repo#123](https://github.com/owner/repo/issues/123)`, and
  `[owner/repo@tag](https://github.com/owner/repo/releases/tag/tag)`.
