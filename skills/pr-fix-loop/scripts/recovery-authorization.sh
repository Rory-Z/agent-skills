#!/usr/bin/env bash

recovery_decision_is_meaningful() {
  local decision="$1" normalized
  normalized="${decision#"${decision%%[![:space:]]*}"}"
  normalized="${normalized%"${normalized##*[![:space:]]}"}"
  [[ -n "$normalized" ]] || return 1
  case "${normalized,,}" in
    continue*|try\ again*|retry*|proceed*|go\ ahead*|resume*|keep\ going*|keep\ fixing*|carry\ on*|move\ forward*|run\ again*|rerun*|do\ not\ recover*|继续*|再试一次*|授权*继续修复*)
      return 1
      ;;
  esac
}

recovery_field_has_substance() {
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

render_recovery_authorization() {
  local head="$1" result="$2" decision="$3" change="$4" basis="$5"
  printf '## Recovery Authorization\n\nDecision: %s\nChange: %s\nConvergence basis: %s\n\nReviewed head: %s\nEffective Review Result: %s\n\n<!-- pr-fix-loop:recovery-v1 head=%s result=%s -->' \
    "$decision" "$change" "$basis" "$head" "$result" "$head" "$result"
}
