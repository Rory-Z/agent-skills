#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/data"
cat >"$TEST_DIR/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == pr && "$2" == view ]]; then
  printf 'OPEN\t%s\n' "$GH_TEST_HEAD"
  exit 0
fi

if [[ "$1" == api && "$2" == user ]]; then
  printf '%s\n' fixer
  exit 0
fi

if [[ "$1" == api ]]; then
  endpoint="${!#}"
  case "$endpoint" in
    */issues/*/comments?*) cat "$GH_TEST_DATA/comments.json" ;;
    */pulls/*/commits?*) cat "$GH_TEST_DATA/commits.json" ;;
    *) exit 2 ;;
  esac
  exit 0
fi

exit 2
SH
chmod +x "$TEST_DIR/bin/gh"

base=0000000000000000000000000000000000000000
h0=1111111111111111111111111111111111111111
c1=2222222222222222222222222222222222222222
c2=3333333333333333333333333333333333333333
c3=4444444444444444444444444444444444444444
c4=5555555555555555555555555555555555555555
c5=6666666666666666666666666666666666666666
c6=7777777777777777777777777777777777777777
c7=8888888888888888888888888888888888888888
c8=9999999999999999999999999999999999999999
c9=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
repair=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
side=cccccccccccccccccccccccccccccccccccccccc

write_commits() {
  case "$1" in
    base)
      cat >"$TEST_DIR/data/commits.json" <<JSON
[{"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}}]
JSON
      ;;
    three)
      cat >"$TEST_DIR/data/commits.json" <<JSON
[
  {"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}},
  {"sha":"$c1","author":{"login":"fixer"},"parents":[{"sha":"$h0"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=101 head=$h0"}},
  {"sha":"$c2","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=102 head=$c1"}},
  {"sha":"$c3","author":{"login":"fixer"},"parents":[{"sha":"$c2"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=103 head=$c2"}}
]
JSON
      ;;
    six)
      cat >"$TEST_DIR/data/commits.json" <<JSON
[
  {"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}},
  {"sha":"$c1","author":{"login":"fixer"},"parents":[{"sha":"$h0"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=101 head=$h0"}},
  {"sha":"$c2","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=102 head=$c1"}},
  {"sha":"$c3","author":{"login":"fixer"},"parents":[{"sha":"$c2"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=103 head=$c2"}},
  {"sha":"$c4","author":{"login":"fixer"},"parents":[{"sha":"$c3"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=106 head=$c3"}},
  {"sha":"$c5","author":{"login":"fixer"},"parents":[{"sha":"$c4"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=107 head=$c4"}},
  {"sha":"$c6","author":{"login":"fixer"},"parents":[{"sha":"$c5"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=108 head=$c5"}}
]
JSON
      ;;
    nine)
      cat >"$TEST_DIR/data/commits.json" <<JSON
[
  {"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}},
  {"sha":"$c1","author":{"login":"fixer"},"parents":[{"sha":"$h0"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=101 head=$h0"}},
  {"sha":"$c2","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=102 head=$c1"}},
  {"sha":"$c3","author":{"login":"fixer"},"parents":[{"sha":"$c2"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=103 head=$c2"}},
  {"sha":"$c4","author":{"login":"fixer"},"parents":[{"sha":"$c3"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=106 head=$c3"}},
  {"sha":"$c5","author":{"login":"fixer"},"parents":[{"sha":"$c4"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=107 head=$c4"}},
  {"sha":"$c6","author":{"login":"fixer"},"parents":[{"sha":"$c5"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=108 head=$c5"}},
  {"sha":"$c7","author":{"login":"fixer"},"parents":[{"sha":"$c6"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=111 head=$c6"}},
  {"sha":"$c8","author":{"login":"fixer"},"parents":[{"sha":"$c7"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=112 head=$c7"}},
  {"sha":"$c9","author":{"login":"fixer"},"parents":[{"sha":"$c8"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=113 head=$c8"}}
]
JSON
      ;;
    check-repair)
      cat >"$TEST_DIR/data/commits.json" <<JSON
[
  {"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}},
  {"sha":"$c1","author":{"login":"fixer"},"parents":[{"sha":"$h0"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=101 head=$h0"}},
  {"sha":"$c2","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=102 head=$c1"}},
  {"sha":"$c3","author":{"login":"fixer"},"parents":[{"sha":"$c2"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=103 head=$c2"}},
  {"sha":"$repair","author":{"login":"fixer"},"parents":[{"sha":"$c3"}],"commit":{"message":"check repair"}}
]
JSON
      ;;
    side-branch)
      cat >"$TEST_DIR/data/commits.json" <<JSON
[
  {"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}},
  {"sha":"$c1","author":{"login":"fixer"},"parents":[{"sha":"$h0"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=101 head=$h0"}},
  {"sha":"$c2","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"pre-merge"}},
  {"sha":"$side","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"side fix\n\nPR-Fix-Cycle: result=102 head=$c1"}},
  {"sha":"$c3","author":{"login":"fixer"},"parents":[{"sha":"$c2"},{"sha":"$side"}],"commit":{"message":"merge fix\n\nPR-Fix-Cycle: result=103 head=$c2"}}
]
JSON
      ;;
    *)
      return 64
      ;;
  esac
}

write_comments() {
  case "$1" in
    initial)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[{"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"}]
JSON
      ;;
    three)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"}
]
JSON
      ;;
    auth)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: narrowed the work\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"},
  {"id":201,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: duplicate\nChange: duplicate request\nConvergence basis: same evidence\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"}
]
JSON
      ;;
    six)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":105,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: narrowed the work\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"},
  {"id":106,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":107,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c4 verdict=changes-requested -->"},
  {"id":108,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c5 verdict=changes-requested -->"},
  {"id":109,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c6 verdict=changes-requested -->"}
]
JSON
      ;;
    invalid)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":201,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: stale\nChange: wrong result\nConvergence basis: invalid binding\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=101 -->"}
]
JSON
      ;;
    generic)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: continue\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"},
  {"id":201,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: proceed with recovery\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"}
]
JSON
      ;;
    weak)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: x\nChange: x\nConvergence basis: y\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"}
]
JSON
      ;;
    placeholder)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: <confirmed Recovery Decision>\nChange: <what changed since the exhausted epoch>\nConvergence basis: <why the next bounded epoch may converge>\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"}
]
JSON
      ;;
    newer-result)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: stale soon\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"},
  {"id":201,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"}
]
JSON
      ;;
    late-descendant)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":106,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":107,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c4 verdict=changes-requested -->"},
  {"id":108,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c5 verdict=changes-requested -->"},
  {"id":150,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c6 verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: narrowed the work\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"},
  {"id":250,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c6 verdict=changes-requested -->"}
]
JSON
      ;;
    nine)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":105,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: narrowed the work\nChange: narrowed scope\nConvergence basis: added focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c3 result=104 -->"},
  {"id":106,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"},
  {"id":107,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c4 verdict=changes-requested -->"},
  {"id":108,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c5 verdict=changes-requested -->"},
  {"id":109,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c6 verdict=changes-requested -->"},
  {"id":110,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: narrowed the work again\nChange: narrowed scope again\nConvergence basis: added more focused tests\n<!-- pr-fix-loop:recovery-v1 head=$c6 result=109 -->"},
  {"id":111,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c6 verdict=changes-requested -->"},
  {"id":112,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c7 verdict=changes-requested -->"},
  {"id":113,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c8 verdict=changes-requested -->"},
  {"id":114,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c9 verdict=changes-requested -->"}
]
JSON
      ;;
    check-repair)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$repair verdict=changes-requested -->"},
  {"id":200,"user":{"login":"fixer"},"body":"## Recovery Authorization\nDecision: check repair is complete\nChange: completed check repair\nConvergence basis: checks now isolate the issue\n<!-- pr-fix-loop:recovery-v1 head=$repair result=104 -->"}
]
JSON
      ;;
    side-branch)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"}
]
JSON
      ;;
    pass)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"LGTM\n<!-- pr-review-loop:v1 head=$h0 verdict=pass -->"}
]
JSON
      ;;
    blocked)
      cat >"$TEST_DIR/data/comments.json" <<JSON
[{"id":101,"user":{"login":"fixer"},"body":"Review failed\n<!-- pr-review-loop:v1 head=$h0 verdict=blocked -->"}]
JSON
      ;;
    *)
      return 64
      ;;
  esac
}

run_state() {
  local trusted_login="${2:-fixer}"
  GH_TEST_DATA="$TEST_DIR/data" GH_TEST_HEAD="$1" PATH="$TEST_DIR/bin:$PATH" \
    "$ROOT/scripts/resolve-recovery-state.sh" owner/repo 7 "$trusted_login"
}

write_commits base
write_comments initial
output="$(run_state "$h0" other)"
[[ "$output" == $'fixable\t'$h0$'\t101\tinitial\t0'* ]]

write_commits three
write_comments three
output="$(run_state "$c3")"
[[ "$output" == $'recovery-required\t'$c3$'\t104\tinitial\t3\t'$c1,* ]]

write_comments auth
output="$(run_state "$c3")"
[[ "$output" == $'fixable\t'$c3$'\t104\t200\t0'* ]]

write_commits six
write_comments six
output="$(run_state "$c6")"
[[ "$output" == $'recovery-required\t'$c6$'\t109\t105\t3\t'$c4,* ]]

write_commits three
write_comments invalid
output="$(run_state "$c3")"
[[ "$output" == $'recovery-required\t'$c3$'\t104\tinitial\t3\t'$c1,* ]]

write_comments newer-result
output="$(run_state "$c3")"
[[ "$output" == $'recovery-required\t'$c3$'\t201\tinitial\t3\t'$c1,* ]]

write_comments generic
output="$(run_state "$c3")"
[[ "$output" == $'recovery-required\t'$c3$'\t104\tinitial\t3\t'$c1,* ]]

write_comments weak
output="$(run_state "$c3")"
[[ "$output" == $'recovery-required\t'$c3$'\t104\tinitial\t3\t'$c1,* ]]

write_comments placeholder
output="$(run_state "$c3")"
[[ "$output" == $'recovery-required\t'$c3$'\t104\tinitial\t3\t'$c1,* ]]

write_commits six
write_comments late-descendant
output="$(run_state "$c6")"
[[ "$output" == $'recovery-required\t'$c6$'\t250\tinitial\t6\t'$c1,* ]]

write_commits nine
write_comments nine
output="$(run_state "$c9")"
[[ "$output" == $'recovery-required\t'$c9$'\t114\t110\t3\t'$c7,* ]]

write_commits check-repair
write_comments check-repair
output="$(run_state "$repair")"
[[ "$output" == $'fixable\t'$repair$'\t104\t200\t0'* ]]

write_commits side-branch
write_comments side-branch
output="$(run_state "$c3")"
[[ "$output" == $'fixable\t'$c3$'\t104\tinitial\t2\t'$c1,* ]]

write_commits base
write_comments pass
output="$(run_state "$h0")"
[[ "$output" == $'pass\t'$h0$'\t102' ]]

write_comments blocked
output="$(run_state "$h0")"
[[ "$output" == $'review-blocked\t'$h0$'\t101' ]]
