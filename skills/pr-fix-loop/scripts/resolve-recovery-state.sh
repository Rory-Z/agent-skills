#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 3 ]]; then
  echo "usage: resolve-recovery-state.sh <owner/repo> <pr-number> <trusted-login>..." >&2
  exit 64
fi

repo="$1"
pr="$2"
shift 2
trusted_reviewers=("$@")

is_trusted() {
  local candidate="$1" trusted
  for trusted in "${trusted_reviewers[@]}"; do
    [[ "$candidate" == "$trusted" ]] && return 0
  done
  return 1
}

is_meaningful_decision() {
  local decision="$1" normalized
  normalized="${decision#"${decision%%[![:space:]]*}"}"
  normalized="${normalized%"${normalized##*[![:space:]]}"}"
  [[ -n "$normalized" ]] || return 1
  case "${normalized,,}" in
    continue*|try\ again*|retry*|proceed*|go\ ahead*|resume*|keep\ going*|keep\ fixing*|carry\ on*|move\ forward*|run\ again*|rerun*|do\ not\ recover*|继续*|再试一次*|授权*继续修复*)
      return 1
      ;;
  esac
  return 0
}

has_substance() {
  local text="$1" normalized compact
  normalized="${text#"${text%%[![:space:]]*}"}"
  normalized="${normalized%"${normalized##*[![:space:]]}"}"
  compact="${normalized//[[:space:]]/}"
  [[ "${#compact}" -ge 8 ]] || return 1
  case "${normalized,,}" in
    '<'*'>'|'['*']'|x|xx|xxx|foo|bar|baz|none|n/a|na|tbd*|todo*|unknown|placeholder)
      return 1
      ;;
  esac
}

fetch() {
  local output
  if ! output="$("$@" 2>&1)"; then
    echo "$output" >&2
    exit 2
  fi
  printf '%s' "$output"
}

normalize_pages() {
  jq -c 'if type == "array" and (length == 0 or (.[0] | type) == "array") then (add // []) else . end'
}

snapshot="$(fetch gh pr view "$pr" --repo "$repo" --json state,headRefOid --jq '[.state, .headRefOid] | @tsv')"
IFS=$'\t' read -r state current_head <<<"$snapshot"
if [[ -z "$state" || ( "$state" == OPEN && -z "$current_head" ) ]]; then
  echo "invalid PR state: $snapshot" >&2
  exit 2
fi

case "$state" in
  CLOSED|MERGED)
    printf 'closed\t%s\n' "$state"
    exit 0
    ;;
  OPEN) ;;
  *)
    echo "unknown PR state: $state" >&2
    exit 2
    ;;
esac

current_login="$(fetch gh api user --jq .login)"
[[ -n "$current_login" ]] || { echo "GitHub identity is empty" >&2; exit 2; }
is_trusted "$current_login" || trusted_reviewers+=("$current_login")
comments_raw="$(fetch gh api --paginate --slurp "repos/$repo/issues/$pr/comments?per_page=100")"
commits_raw="$(fetch gh api --paginate --slurp "repos/$repo/pulls/$pr/commits?per_page=100")"
comments="$(printf '%s' "$comments_raw" | normalize_pages)"
commits="$(printf '%s' "$commits_raw" | normalize_pages)"

declare -A result_head result_verdict
result_ids=()
review_records="$(jq -r '
  .[] | try (
    (.body | capture("<!-- pr-review-loop:v1 head=(?<head>[0-9a-f]{40}) verdict=(?<verdict>changes-requested|pass|blocked) -->[\\r\\n]*$")) as $marker |
    [$marker.head, $marker.verdict, (.id | tostring), .user.login] | @tsv
  )
' <<<"$comments")"
while IFS=$'\t' read -r reviewed_head verdict result_id author; do
  [[ "${result_id:-}" =~ ^[0-9]+$ ]] || continue
  is_trusted "$author" || continue
  result_head["$result_id"]="$reviewed_head"
  result_verdict["$result_id"]="$verdict"
  result_ids+=("$result_id")
done <<<"$review_records"

effective_id=0
effective_verdict=""
for result_id in "${result_ids[@]}"; do
  if [[ "${result_head[$result_id]}" == "$current_head" && "$result_id" -gt "$effective_id" ]]; then
    effective_id="$result_id"
    effective_verdict="${result_verdict[$result_id]}"
  fi
done

if (( effective_id == 0 )); then
  printf 'waiting\t%s\n' "$current_head"
  exit 0
fi

declare -A commit_parent
all_commit_records="$(jq -r '
  to_entries[] |
  [.value.sha, (.value.parents[0].sha // "")] | @tsv
' <<<"$commits")"
while IFS=$'\t' read -r sha parent; do
  [[ "${sha:-}" =~ ^[0-9a-f]{40}$ ]] || continue
  commit_parent["$sha"]="$parent"
done <<<"$all_commit_records"

declare -A ancestor_depth
sha="$current_head"
depth=0
while [[ -n "$sha" && -z "${ancestor_depth[$sha]+present}" ]]; do
  ancestor_depth["$sha"]="$depth"
  sha="${commit_parent[$sha]:-}"
  depth=$((depth + 1))
done

commit_records="$(jq -r '
  to_entries[] |
  (.value.commit.message | split("\n") | map(select(test("^PR-Fix-Cycle: result=[0-9]+ head=[0-9a-f]{40}$"))) | .[0]) as $trailer |
  select($trailer != null) |
  ($trailer | capture("^PR-Fix-Cycle: result=(?<result>[0-9]+) head=(?<head>[0-9a-f]{40})$")) as $marker |
  [.key, .value.sha, (.value.parents[0].sha // ""), (.value.author.login // ""), $marker.result, $marker.head] | @tsv
' <<<"$commits")"
cycle_indices=()
cycle_shas=()
cycle_results=()
declare -A seen_cycle_results
while IFS=$'\t' read -r index sha parent author result_id reviewed_head; do
  [[ -n "${sha:-}" ]] || continue
  if ! is_trusted "$author"; then
    continue
  fi
  [[ -n "${ancestor_depth[$sha]+present}" ]] || continue
  [[ "$parent" == "$reviewed_head" ]] || continue
  [[ "${result_head[$result_id]:-}" == "$reviewed_head" ]] || continue
  [[ "${result_verdict[$result_id]:-}" == changes-requested ]] || continue
  if [[ -n "${seen_cycle_results[$result_id]:-}" ]]; then
    continue
  fi
  seen_cycle_results["$result_id"]=1
  cycle_indices+=("$index")
  cycle_shas+=("$sha")
  cycle_results+=("$result_id")
done <<<"$commit_records"

auth_ids=()
auth_heads=()
auth_results=()
auth_records="$(jq -r '
  .[] | try (
    (.body | capture("<!-- pr-fix-loop:recovery-v1 head=(?<head>[0-9a-f]{40}) result=(?<result>[0-9]+) -->[\\r\\n]*$")) as $marker |
    (.body | capture("(?m)^Decision:[[:space:]]*(?<decision>[^\\r\\n]+)")) as $decision |
    (.body | capture("(?m)^Change:[[:space:]]*(?<change>[^\\r\\n]+)")) as $change |
    (.body | capture("(?m)^Convergence basis:[[:space:]]*(?<basis>[^\\r\\n]+)")) as $basis |
    [$marker.head, $marker.result, (.id | tostring), .user.login, $decision.decision, $change.change, $basis.basis] | @tsv
  )
' <<<"$comments" | sort -n -k3,3)"
while IFS=$'\t' read -r auth_head auth_result auth_id auth_author decision_text change_text convergence_basis; do
  [[ "${auth_id:-}" =~ ^[0-9]+$ ]] || continue
  [[ "$auth_author" == "$current_login" ]] || continue
  is_meaningful_decision "$decision_text" || continue
  has_substance "$change_text" || continue
  has_substance "$convergence_basis" || continue
  has_substance "$decision_text" || continue
  [[ -n "${result_head[$auth_result]:-}" ]] || continue
  [[ "${result_head[$auth_result]}" == "$auth_head" ]] || continue
  [[ "${result_verdict[$auth_result]}" == changes-requested ]] || continue
  [[ -n "${ancestor_depth[$auth_head]+present}" ]] || continue
  [[ "$auth_result" -le "$auth_id" ]] || continue
  if [[ "$auth_head" != "$current_head" ]]; then
    [[ "$auth_id" -lt "$effective_id" ]] || continue
    current_result_at_auth=0
    for result_id in "${result_ids[@]}"; do
      if [[ "$result_id" -le "$auth_id" && "${result_head[$result_id]}" == "$current_head" && "$result_id" -gt "$current_result_at_auth" ]]; then
        current_result_at_auth="$result_id"
      fi
    done
    [[ "$current_result_at_auth" == 0 ]] || continue
  fi

  latest_at_auth=0
  for result_id in "${result_ids[@]}"; do
    if [[ "$result_id" -le "$auth_id" && "${result_head[$result_id]}" == "$auth_head" && "$result_id" -gt "$latest_at_auth" ]]; then
      latest_at_auth="$result_id"
    fi
  done
  [[ "$latest_at_auth" == "$auth_result" ]] || continue

  auth_ids+=("$auth_id")
  auth_heads+=("$auth_head")
  auth_results+=("$auth_result")
done <<<"$auth_records"

epoch_id=initial
epoch_anchor_head=""
epoch_anchor_depth=-1
epoch_anchor_result=""
declare -A seen_auth_keys

cycle_is_after_anchor() {
  local cycle_sha="$1" cycle_depth
  [[ -n "${ancestor_depth[$cycle_sha]+present}" ]] || return 1
  [[ -z "$epoch_anchor_head" ]] && return 0
  cycle_depth="${ancestor_depth[$cycle_sha]}"
  (( cycle_depth < epoch_anchor_depth ))
}

cycle_count_after_anchor() {
  local count=0 cycle_index
  for cycle_index in "${!cycle_indices[@]}"; do
    cycle_is_after_anchor "${cycle_shas[$cycle_index]}" && count=$((count + 1))
  done
  printf '%s' "$count"
}

for auth_index in "${!auth_ids[@]}"; do
  auth_id="${auth_ids[$auth_index]}"
  auth_head="${auth_heads[$auth_index]}"
  auth_result="${auth_results[$auth_index]}"
  auth_key="$auth_head:$auth_result"
  [[ -n "${seen_auth_keys[$auth_key]:-}" ]] && continue
  if [[ -n "$epoch_anchor_head" ]]; then
    [[ "${ancestor_depth[$auth_head]}" -lt "$epoch_anchor_depth" ]] || continue
  fi
  prior_cycles="$(cycle_count_after_anchor)"
  (( prior_cycles >= 3 )) || continue
  seen_auth_keys["$auth_key"]=1
  epoch_id="$auth_id"
  epoch_anchor_head="$auth_head"
  epoch_anchor_depth="${ancestor_depth[$auth_head]}"
  epoch_anchor_result="$auth_result"
done

cycles_used="$(cycle_count_after_anchor)"
if [[ "$epoch_id" != initial && "$cycles_used" == 0 && \
  ( "$current_head" != "$epoch_anchor_head" || "$effective_id" != "$epoch_anchor_result" ) ]]; then
  epoch_id=initial
  epoch_anchor_head=""
  epoch_anchor_depth=-1
  epoch_anchor_result=""
  cycles_used="$(cycle_count_after_anchor)"
fi

case "$effective_verdict" in
  pass)
    printf 'pass\t%s\t%s\n' "$current_head" "$effective_id"
    ;;
  blocked)
    printf 'review-blocked\t%s\t%s\n' "$current_head" "$effective_id"
    ;;
  changes-requested)
    cycle_list=()
    for cycle_index in "${!cycle_indices[@]}"; do
      if cycle_is_after_anchor "${cycle_shas[$cycle_index]}"; then
        cycle_list+=("${cycle_shas[$cycle_index]}")
      fi
    done
    cycle_csv="$(IFS=,; printf '%s' "${cycle_list[*]}")"
    if (( cycles_used >= 3 )); then
      printf 'recovery-required\t%s\t%s\t%s\t%s\t%s\n' \
        "$current_head" "$effective_id" "$epoch_id" "$cycles_used" "$cycle_csv"
    else
      printf 'fixable\t%s\t%s\t%s\t%s\t%s\n' \
        "$current_head" "$effective_id" "$epoch_id" "$cycles_used" "$cycle_csv"
    fi
    ;;
  *)
    echo "unknown Review Result verdict: $effective_verdict" >&2
    exit 2
    ;;
esac
