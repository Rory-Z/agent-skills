#!/usr/bin/env bash
# Gather a GitHub user's PR and release activity for a given week, in UTC+8
# (Asia/Shanghai).
#
# Usage:
#   gather-prs.sh                         # last full calendar week, current gh user
#   gather-prs.sh 2026-06-01 2026-06-07   # explicit start/end dates, inclusive
#   gather-prs.sh 2026-06-01 2026-06-07 someuser
#
# Output: tab-separated lines grouped under CREATED / MERGED / RELEASES headers,
# plus a per-repo count. The calling agent turns this into weekly-report prose.
set -euo pipefail

TZ_SH='Asia/Shanghai'
CALENDAR_FILE="${WEEKLY_REPORT_CALENDAR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/daily-report/data/china-workdays.tsv}"

if [[ -n "${1:-}" && -n "${2:-}" ]]; then
  START_DATE="$1"
  END_DATE="$2"
else
  # Default: previous full calendar week (Mon-Sun) relative to today in UTC+8.
  dow=$(TZ="$TZ_SH" date +%u)
  this_mon=$(TZ="$TZ_SH" date -d "-$((dow - 1)) days" +%Y-%m-%d)
  START_DATE=$(TZ="$TZ_SH" date -d "$this_mon -7 days" +%Y-%m-%d)
  END_DATE=$(TZ="$TZ_SH" date -d "$START_DATE +6 days" +%Y-%m-%d)
fi

USER="${3:-$(gh api user --jq '.login')}"

# Append +08:00 so GitHub interprets the range in Asia/Shanghai time.
START="${START_DATE}T00:00:00+08:00"
END="${END_DATE}T23:59:59+08:00"
START_UTC="$(TZ=UTC date -d "${START_DATE} 00:00:00 +0800" +%Y-%m-%dT%H:%M:%SZ)"
END_UTC="$(TZ=UTC date -d "${END_DATE} 23:59:59 +0800" +%Y-%m-%dT%H:%M:%SZ)"

echo "# weekly-report data"
echo "# user:  ${USER}"
echo "# range: ${START_DATE} (Mon) .. ${END_DATE} (Sun)  [UTC+8 / Asia/Shanghai]"
echo ""

echo "=== CHINA WORKDAY CALENDAR (exceptions in window) ==="
if [[ -f "$CALENDAR_FILE" ]]; then
  awk -F '\t' -v start="$START_DATE" -v end="$END_DATE" '
    $1 !~ /^#/ && $1 >= start && $1 <= end { print }
  ' "$CALENDAR_FILE"
fi
echo ""

echo "=== CREATED (opened in window) ==="
created_prs="$(gh search prs --author="$USER" --created="${START}..${END}" --limit 100 \
  --json repository,number,title,state,createdAt,url \
  --jq '.[] | "\(.createdAt[0:10])\t[\(.state)]\t\(.repository.nameWithOwner)#\(.number)\t\(.title)\t\(.url)"' \
  | sort)"
printf '%s\n' "$created_prs"

echo ""
echo "=== MERGED (merged-at in window; may include PRs opened earlier) ==="
merged_prs="$(gh search prs --author="$USER" --merged-at="${START}..${END}" --limit 100 \
  --json repository,number,title,closedAt,url \
  --jq '.[] | "\(.closedAt[0:10])\t\(.repository.nameWithOwner)#\(.number)\t\(.title)\t\(.url)"' \
  | sort)"
printf '%s\n' "$merged_prs"

echo ""
echo "=== COUNT BY REPO (created in window) ==="
printf '%s\n' "$created_prs" \
  | awk -F '\t' 'NF >= 3 { sub(/#[0-9]+$/, "", $3); counts[$3]++ } END { for (repo in counts) printf "%7d %s\n", counts[repo], repo }' \
  | sort -rn

echo ""
echo "=== RELEASES (published in window for touched repos) ==="
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
      --jq ".[] | select(.publishedAt >= \"${START_UTC}\" and .publishedAt <= \"${END_UTC}\") | \"\(.publishedAt[0:10])\t${repo}\t\(.tagName)\t\(.name)\thttps://github.com/${repo}/releases/tag/\(.tagName)\""
  done <<< "$repos" | sort
fi
