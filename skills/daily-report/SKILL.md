---
name: daily-report
description: Generate a casual Chinese daily report from the user's GitHub pull request, issue, and release activity. Use when the user asks for a daily report, 日报, the previous workday's work, or a short work recap for a specific day.
---

# Daily Report (日报)

## Overview

Generate a short, conversational Chinese daily report from GitHub activity for
the previous workday in UTC+8 (Asia/Shanghai), unless the user gives a specific
date. The previous workday uses Mainland China public holidays and makeup
workdays from `data/china-workdays.tsv` when available. Prefer natural
status-update prose over formal weekly-report structure. Do not include PR
links in the final report.

## Workflow

1. Gather activity with the bundled script. By default it uses the previous
   Mainland China workday in UTC+8 and the current authenticated `gh` user:

   ```bash
   ${CODEX_HOME:-$HOME/.codex}/skills/daily-report/scripts/gather-activity.sh
   ```

   For a specific UTC+8 day or user:

   ```bash
   ${CODEX_HOME:-$HOME/.codex}/skills/daily-report/scripts/gather-activity.sh 2026-06-24
   ${CODEX_HOME:-$HOME/.codex}/skills/daily-report/scripts/gather-activity.sh 2026-06-24 github-login
   ```

   Update `data/china-workdays.tsv` when the next year's State Council holiday
   notice is published. Only list exceptions: statutory holidays on weekdays
   and makeup workdays on weekends.

2. Write the report in Chinese:

   - Title: `# 日报（YYYY-MM-DD）`
   - Start with 1-2 conversational sentences summarizing the day.
   - Use 2-5 bullets for concrete work completed or moved forward.
   - Mention merged PRs, created PRs, issues, or releases only when they appear
     in the data.
   - Use repository names, issue numbers, PR numbers, and release tags when
     useful, but do not format PRs as Markdown links and do not paste PR URLs.
   - Skip empty sections.

3. Keep the tone like a teammate's end-of-day update: clear, relaxed, and
   specific. Avoid corporate phrasing, inflated impact claims, and long
   explanations.

## Output Style

- Always write the report body in Chinese, regardless of the session language.
- Prefer "昨天主要把 X 梳理完了，也顺手处理了 Y" over "完成了 X、Y、Z".
- Keep technical identifiers in their original form.
- Do not add "明日计划" unless the user explicitly asks for it.
- Do not include PR links. Issue or release links are also unnecessary unless
  the user explicitly asks for links.
