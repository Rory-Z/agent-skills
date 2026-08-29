#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: wait-for-head.sh <owner/repo> <pr-number> <last-head>" >&2
  exit 64
fi

repo="$1"
pr="$2"
last_head="$3"
failures=0

retry_or_exit() {
  local error="$1"
  failures=$((failures + 1))
  if (( failures >= 3 )); then
    echo "GitHub read failed three times: $error" >&2
    exit 2
  fi
  sleep 600
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
  failures=0

  case "$state" in
    CLOSED|MERGED)
      printf 'closed\t%s\n' "$state"
      exit 0
      ;;
    OPEN)
      if [[ "$head" != "$last_head" ]]; then
        printf 'head\t%s\n' "$head"
        exit 0
      fi
      ;;
    *)
      retry_or_exit "unknown PR state: $state"
      continue
      ;;
  esac

  sleep 600
done
