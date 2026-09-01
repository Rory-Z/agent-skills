#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/recovery-authorization.sh"

dry_run=false
if [[ "${1:-}" == --dry-run ]]; then
  dry_run=true
  shift
fi

if [[ "$#" -lt 8 ]]; then
  echo "usage: publish-recovery-authorization.sh [--dry-run] <owner/repo> <pr-number> <head> <result-id> <decision> <change> <convergence-basis> <trusted-login>..." >&2
  exit 64
fi

repo="$1"
pr="$2"
expected_head="$3"
expected_result="$4"
decision="$5"
change="$6"
basis="$7"
shift 7
trusted_reviewers=("$@")

[[ "$repo" =~ ^[^/]+/[^/]+$ && "$pr" =~ ^[0-9]+$ && "$expected_head" =~ ^[0-9a-f]{40}$ && "$expected_result" =~ ^[0-9]+$ ]] || {
  echo "invalid Recovery Authorization target" >&2
  exit 64
}

for field in "$decision" "$change" "$basis"; do
  [[ "$field" != *$'\n'* && "$field" != *$'\r'* ]] || {
    echo "Recovery Authorization fields must be single-line" >&2
    exit 64
  }
  recovery_field_has_substance "$field" || {
    echo "Recovery Authorization fields must contain at least eight non-whitespace characters and must not be placeholders" >&2
    exit 64
  }
done
recovery_decision_is_meaningful "$decision" || {
  echo "Recovery Decision must not be a generic continuation instruction" >&2
  exit 64
}

before="$("$SCRIPT_DIR/resolve-recovery-state.sh" "$repo" "$pr" "${trusted_reviewers[@]}")"
IFS=$'\t' read -r before_state before_head before_result _ <<<"$before"
if [[ "$before_state" != recovery-required || "$before_head" != "$expected_head" || "$before_result" != "$expected_result" ]]; then
  echo "Recovery Authorization precondition changed: $before" >&2
  exit 2
fi

body="$(render_recovery_authorization "$expected_head" "$expected_result" "$decision" "$change" "$basis")"
if $dry_run; then
  printf '%s\n' "$body"
  exit 0
fi

if ! comment_id="$(gh api "repos/$repo/issues/$pr/comments" --method POST --raw-field "body=$body" --jq .id 2>&1)"; then
  echo "$comment_id" >&2
  exit 2
fi
[[ "$comment_id" =~ ^[0-9]+$ ]] || {
  echo "invalid Recovery Authorization comment ID: $comment_id" >&2
  exit 2
}

after="$("$SCRIPT_DIR/resolve-recovery-state.sh" "$repo" "$pr" "${trusted_reviewers[@]}")"
IFS=$'\t' read -r after_state after_head after_result after_epoch after_cycles _ <<<"$after"
if [[ "$after_state" != fixable || "$after_head" != "$expected_head" || "$after_result" != "$expected_result" || "$after_epoch" != "$comment_id" || "$after_cycles" != 0 ]]; then
  echo "Recovery Authorization was not accepted: $after" >&2
  exit 2
fi

printf 'authorized\t%s\t%s\t%s\n' "$expected_head" "$expected_result" "$comment_id"
