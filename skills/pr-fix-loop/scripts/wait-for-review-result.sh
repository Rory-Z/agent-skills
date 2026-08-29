#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 3 ]]; then
  echo "usage: wait-for-review-result.sh <owner/repo> <pr-number> <trusted-login>..." >&2
  exit 64
fi

repo="$1"
pr="$2"
shift 2
trusted_reviewers=("$@")
failures=0

is_trusted() {
  local author="$1" trusted
  for trusted in "${trusted_reviewers[@]}"; do
    [[ "$author" != "$trusted" ]] || return 0
  done
  return 1
}

retry_or_exit() {
  local error="$1"
  failures=$((failures + 1))
  if (( failures >= 3 )); then
    echo "GitHub read failed three times: $error" >&2
    exit 2
  fi
  sleep 300
}

while :; do
  if ! snapshot="$(gh pr view "$pr" --repo "$repo" --json state,headRefOid --jq '[.state, .headRefOid] | @tsv' 2>&1)"; then
    retry_or_exit "$snapshot"
    continue
  fi

  IFS=$'\t' read -r state head <<<"$snapshot"
  if [[ -z "$state" || ( "$state" == "OPEN" && -z "$head" ) ]]; then
    retry_or_exit "invalid PR state"
    continue
  fi

  case "$state" in
    CLOSED|MERGED)
      printf 'closed\t%s\n' "$state"
      exit 0
      ;;
    OPEN) ;;
    *)
      retry_or_exit "unknown PR state: $state"
      continue
      ;;
  esac

  if ! results="$(gh api --paginate "repos/$repo/issues/$pr/comments?per_page=100" --jq '
    .[] as $comment |
    try (
      ($comment.body | capture("<!-- pr-review-loop:v1 head=(?<head>[0-9a-f]+) verdict=(?<verdict>changes-requested|pass|blocked) -->[\\r\\n]*$")) as $marker |
      [$comment.id, $comment.user.login, $marker.head, $marker.verdict] | @tsv
    )
  ' 2>&1)"; then
    retry_or_exit "$results"
    continue
  fi
  failures=0

  latest_id=0
  latest_author=""
  latest_verdict=""
  while IFS=$'\t' read -r id author reviewed_head verdict; do
    [[ "$id" =~ ^[0-9]+$ && "$reviewed_head" == "$head" ]] || continue
    is_trusted "$author" || continue
    if (( id > latest_id )); then
      latest_id="$id"
      latest_author="$author"
      latest_verdict="$verdict"
    fi
  done <<<"$results"

  if (( latest_id > 0 )); then
    printf 'review\t%s\t%s\t%s\t%s\n' "$head" "$latest_verdict" "$latest_id" "$latest_author"
    exit 0
  fi

  sleep 300
done
