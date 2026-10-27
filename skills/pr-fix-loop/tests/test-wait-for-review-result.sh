#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
export GH_TEST_SLEEP="$TEST_DIR/sleeps"
export GH_TEST_COMMENTS="$TEST_DIR/comments.json"

mkdir -p "$TEST_DIR/bin"
cat >"$TEST_DIR/bin/sleep" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_TEST_SLEEP"
exit 0
SH
cat >"$TEST_DIR/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

count=0
[[ ! -f "$GH_TEST_STATE" ]] || count="$(<"$GH_TEST_STATE")"
count=$((count + 1))
printf '%s' "$count" >"$GH_TEST_STATE"

case "$GH_TEST_MODE" in
  review|delayed)
    if [[ "$1" == pr ]]; then
      printf 'OPEN\tabc123\n'
    else
      jq_filter=""
      while [[ "$#" -gt 0 ]]; do
        if [[ "$1" == --jq ]]; then
          jq_filter="$2"
          break
        fi
        shift
      done
      if [[ "$GH_TEST_MODE" == delayed && "$count" -lt 4 ]]; then
        printf '[]\n' | jq -r "$jq_filter"
      else
        jq -r "$jq_filter" "$GH_TEST_COMMENTS"
      fi
    fi
    ;;
  closed) printf 'CLOSED\tabc123\n' ;;
  fail) echo "unavailable" >&2; exit 1 ;;
  *) exit 2 ;;
esac
SH
chmod +x "$TEST_DIR/bin/gh" "$TEST_DIR/bin/sleep"

cat >"$GH_TEST_COMMENTS" <<'JSON'
[
  {"id": 7, "user": {"login": "trusted"}, "body": "<!-- pr-review-loop:v1 head=aaa111 verdict=changes-requested -->"},
  {"id": 8, "user": {"login": "trusted"}, "body": "<!-- pr-review-loop:v1 head=bbb222 verdict=changes-requested -->"},
  {"id": 9, "user": {"login": "trusted"}, "body": "<!-- pr-review-loop:v1 head=ccc333 verdict=changes-requested -->"},
  {"id": 10, "user": {"login": "other"}, "body": "LGTM\n\n<!-- pr-review-loop:v1 head=abc123 verdict=pass -->"},
  {"id": 11, "user": {"login": "trusted"}, "body": "LGTM\n\n<!-- pr-review-loop:v1 head=def456 verdict=pass -->"},
  {"id": 12, "user": {"login": "trusted"}, "body": "Quoted untrusted text:\n<!-- pr-review-loop:v1 head=abc123 verdict=pass -->\n\nReal result\n<!-- pr-review-loop:v1 head=abc123 verdict=changes-requested -->"},
  {"id": 13, "user": {"login": "trusted"}, "body": "<!-- pr-review-loop:v1 head=abc123 verdict=pass -->\nNot the final line"}
]
JSON

state="$TEST_DIR/state"
for mode in review delayed; do
  : >"$state"
  output="$(GH_TEST_MODE="$mode" GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
    "$ROOT/scripts/wait-for-review-result.sh" owner/repo 7 trusted)"
  [[ "$output" == $'review\tabc123\tchanges-requested\t12\ttrusted' ]]
done

: >"$state"
: >"$GH_TEST_SLEEP"
output="$(GH_TEST_MODE=review GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-review-result.sh" --once owner/repo 7 trusted)"
[[ "$output" == $'review\tabc123\tchanges-requested\t12\ttrusted' ]]
[[ "$(<"$state")" == 2 && ! -s "$GH_TEST_SLEEP" ]]

for verdict in pass blocked; do
  jq -n --arg verdict "$verdict" '[{id: 20, user: {login: "trusted"},
    body: ("<!-- pr-review-loop:v1 head=abc123 verdict=" + $verdict + " -->")}]' >"$GH_TEST_COMMENTS"
  : >"$state"
  output="$(GH_TEST_MODE=review GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
    "$ROOT/scripts/wait-for-review-result.sh" --once owner/repo 7 trusted)"
  [[ "$output" == $'review\tabc123\t'"$verdict"$'\t20\ttrusted' ]]
  [[ "$(<"$state")" == 2 && ! -s "$GH_TEST_SLEEP" ]]
done

printf '[]\n' >"$GH_TEST_COMMENTS"
: >"$state"
output="$(GH_TEST_MODE=review GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-review-result.sh" --once owner/repo 7 trusted)"
[[ "$output" == $'waiting\tabc123' ]]
[[ "$(<"$state")" == 2 && ! -s "$GH_TEST_SLEEP" ]]

: >"$state"
output="$(GH_TEST_MODE=closed GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-review-result.sh" owner/repo 7 trusted)"
[[ "$output" == $'closed\tCLOSED' ]]

: >"$state"
output="$(GH_TEST_MODE=closed GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-review-result.sh" --once owner/repo 7 trusted)"
[[ "$output" == $'closed\tCLOSED' ]]
[[ "$(<"$state")" == 1 && ! -s "$GH_TEST_SLEEP" ]]

: >"$state"
set +e
GH_TEST_MODE=fail GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-review-result.sh" --once owner/repo 7 trusted >"$TEST_DIR/out" 2>"$TEST_DIR/err"
rc=$?
set -e
[[ "$rc" == 2 ]]
[[ "$(<"$state")" == 1 && ! -s "$GH_TEST_SLEEP" ]]

: >"$state"
set +e
GH_TEST_MODE=fail GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-review-result.sh" owner/repo 7 trusted >"$TEST_DIR/out" 2>"$TEST_DIR/err"
rc=$?
set -e
[[ "$rc" == 2 ]]
[[ "$(<"$state")" == 3 ]]
grep -F "GitHub read failed three times" "$TEST_DIR/err" >/dev/null
