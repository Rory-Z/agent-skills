#!/usr/bin/env bash
# Gather a GitHub user's activity for one UTC+8 day.
#
# Usage:
#   gather-activity.sh                  # previous weekday, current gh user
#   gather-activity.sh 2026-06-24       # explicit UTC+8 date
#   gather-activity.sh 2026-06-24 user  # explicit UTC+8 date and GitHub login
set -euo pipefail

TZ_SH='Asia/Shanghai'
CALENDAR_FILE="${DAILY_REPORT_CALENDAR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data/china-workdays.tsv}"

calendar_kind() {
  local day="$1"
  [[ -f "$CALENDAR_FILE" ]] || return 1
  awk -F '\t' -v day="$day" '$1 == day { print $2; found = 1; exit } END { exit found ? 0 : 1 }' "$CALENDAR_FILE"
}

is_workday() {
  local day="$1" kind dow
  if kind="$(calendar_kind "$day")"; then
    [[ "$kind" == workday ]]
    return
  fi
  dow="$(TZ="$TZ_SH" date -d "$day" +%u)"
  [[ "$dow" -le 5 ]]
}

if [[ -n "${1:-}" ]]; then
  DAY="$1"
else
  today="${DAILY_REPORT_TODAY:-$(TZ="$TZ_SH" date +%Y-%m-%d)}"
  DAY="$(TZ="$TZ_SH" date -d "$today -1 day" +%Y-%m-%d)"
  while ! is_workday "$DAY"; do
    DAY="$(TZ="$TZ_SH" date -d "$DAY -1 day" +%Y-%m-%d)"
  done
fi
USER="${2:-$(gh api user --jq '.login')}"

START="${DAY}T00:00:00+08:00"
END="${DAY}T23:59:59+08:00"
START_UTC="$(TZ=UTC date -d "${DAY} 00:00:00 +0800" +%Y-%m-%dT%H:%M:%SZ)"
END_UTC="$(TZ=UTC date -d "${DAY} 23:59:59 +0800" +%Y-%m-%dT%H:%M:%SZ)"

echo "# daily-report data"
echo "# user:  ${USER}"
echo "# date:  ${DAY} [UTC+8 / Asia/Shanghai]"
echo ""

echo "=== PRS CREATED ==="
created_prs="$(gh search prs --author="$USER" --created="${START}..${END}" --limit 100 \
  --json repository,number,title,state,createdAt \
  --jq '.[] | "\(.createdAt[0:10])\t[\(.state)]\t\(.repository.nameWithOwner)#\(.number)\t\(.title)"' \
  | sort)"
printf '%s\n' "$created_prs"

echo ""
echo "=== PRS MERGED ==="
merged_prs="$(gh search prs --author="$USER" --merged-at="${START}..${END}" --limit 100 \
  --json repository,number,title,closedAt \
  --jq '.[] | "\(.closedAt[0:10])\t\(.repository.nameWithOwner)#\(.number)\t\(.title)"' \
  | sort)"
printf '%s\n' "$merged_prs"

echo ""
echo "=== ISSUES CREATED ==="
gh search issues --author="$USER" --created="${START}..${END}" --limit 100 \
  --json repository,number,title,state,createdAt \
  --jq '.[] | "\(.createdAt[0:10])\t[\(.state)]\t\(.repository.nameWithOwner)#\(.number)\t\(.title)"' \
  | sort

echo ""
echo "=== ISSUES CLOSED ==="
gh search issues --involves="$USER" --closed="${START}..${END}" --limit 100 \
  --json repository,number,title,state,closedAt \
  --jq '.[] | "\(.closedAt[0:10])\t[\(.state)]\t\(.repository.nameWithOwner)#\(.number)\t\(.title)"' \
  | sort

echo ""
echo "=== RELEASES ==="
repos="$(
  {
    printf '%s\n' "$created_prs" | awk -F '\t' 'NF >= 3 { sub(/#[0-9]+$/, "", $3); print $3 }'
    printf '%s\n' "$merged_prs" | awk -F '\t' 'NF >= 2 { sub(/#[0-9]+$/, "", $2); print $2 }'
  } | sort -u
)"

if [[ -n "$repos" ]]; then
  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    gh release list --repo "$repo" --limit 100 \
      --json name,tagName,publishedAt \
      --jq ".[] | select(.publishedAt >= \"${START_UTC}\" and .publishedAt <= \"${END_UTC}\") | \"\(.publishedAt[0:10])\t${repo}\t\(.tagName)\t\(.name)\""
  done <<< "$repos" | sort
fi
