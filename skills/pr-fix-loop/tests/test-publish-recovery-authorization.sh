#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/data"

base=0000000000000000000000000000000000000000
h0=1111111111111111111111111111111111111111
c1=2222222222222222222222222222222222222222
c2=3333333333333333333333333333333333333333
c3=4444444444444444444444444444444444444444

cat >"$TEST_DIR/data/comments.json" <<JSON
[
  {"id":101,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$h0 verdict=changes-requested -->"},
  {"id":102,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c1 verdict=changes-requested -->"},
  {"id":103,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c2 verdict=changes-requested -->"},
  {"id":104,"user":{"login":"fixer"},"body":"Blocking\n<!-- pr-review-loop:v1 head=$c3 verdict=changes-requested -->"}
]
JSON

cat >"$TEST_DIR/data/commits.json" <<JSON
[
  {"sha":"$h0","author":{"login":"fixer"},"parents":[{"sha":"$base"}],"commit":{"message":"initial"}},
  {"sha":"$c1","author":{"login":"fixer"},"parents":[{"sha":"$h0"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=101 head=$h0"}},
  {"sha":"$c2","author":{"login":"fixer"},"parents":[{"sha":"$c1"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=102 head=$c1"}},
  {"sha":"$c3","author":{"login":"fixer"},"parents":[{"sha":"$c2"}],"commit":{"message":"fix\n\nPR-Fix-Cycle: result=103 head=$c2"}}
]
JSON

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

if [[ "$1" == api && "$2" == repos/owner/repo/issues/7/comments ]]; then
  shift 2
  body=""
  while (( $# )); do
    case "$1" in
      --method) shift; [[ "$1" == POST ]] ;;
      --raw-field) shift; body="${1#body=}" ;;
    esac
    shift
  done
  tmp="$GH_TEST_DATA/comments.tmp"
  jq --arg body "$body" '. + [{"id":200,"user":{"login":"fixer"},"body":$body}]' \
    "$GH_TEST_DATA/comments.json" >"$tmp"
  mv "$tmp" "$GH_TEST_DATA/comments.json"
  printf '200\n'
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

decision="Authorize one bounded Recovery Epoch for the reviewed result."
change="Split the confirmed defect from non-authorizing advisories."
basis="Focused regression coverage now isolates the remaining defect."
expected="$(printf '## Recovery Authorization\n\nDecision: %s\nChange: %s\nConvergence basis: %s\n\nReviewed head: %s\nEffective Review Result: %s\n\n<!-- pr-fix-loop:recovery-v1 head=%s result=%s -->' \
  "$decision" "$change" "$basis" "$c3" 104 "$c3" 104)"

for missing_field in 0 1 2; do
  fields=("$decision" "$change" "$basis")
  fields[$missing_field]=""
  set +e
  output="$(GH_TEST_DATA="$TEST_DIR/data" GH_TEST_HEAD="$c3" PATH="$TEST_DIR/bin:$PATH" \
    "$ROOT/scripts/publish-recovery-authorization.sh" --dry-run \
    owner/repo 7 "$c3" 104 "${fields[@]}" fixer 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == 64 ]]
  [[ "$output" == *"fields must contain"* ]]
  [[ "$(jq length "$TEST_DIR/data/comments.json")" == 4 ]]
done

output="$(GH_TEST_DATA="$TEST_DIR/data" GH_TEST_HEAD="$c3" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/publish-recovery-authorization.sh" --dry-run \
  owner/repo 7 "$c3" 104 "$decision" "$change" "$basis" fixer)"
[[ "$output" == "$expected" ]]
[[ "$(jq length "$TEST_DIR/data/comments.json")" == 4 ]]

output="$(GH_TEST_DATA="$TEST_DIR/data" GH_TEST_HEAD="$c3" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/publish-recovery-authorization.sh" \
  owner/repo 7 "$c3" 104 "$decision" "$change" "$basis" fixer)"
[[ "$output" == $'authorized\t'$c3$'\t104\t200' ]]
[[ "$(jq -r '.[-1].body' "$TEST_DIR/data/comments.json")" == "$expected" ]]

output="$(GH_TEST_DATA="$TEST_DIR/data" GH_TEST_HEAD="$c3" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/resolve-recovery-state.sh" owner/repo 7 fixer)"
[[ "$output" == $'fixable\t'$c3$'\t104\t200\t0\t' ]]
