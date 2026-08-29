#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin"
cat >"$TEST_DIR/bin/sleep" <<'SH'
#!/usr/bin/env bash
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
  change)
    case "$count" in
      1) echo "temporary failure" >&2; exit 1 ;;
      2) printf 'OPEN\told-head\n' ;;
      *) printf 'OPEN\tnew-head\n' ;;
    esac
    ;;
  closed) printf 'MERGED\told-head\n' ;;
  fail) echo "unavailable" >&2; exit 1 ;;
  *) exit 2 ;;
esac
SH
chmod +x "$TEST_DIR/bin/gh" "$TEST_DIR/bin/sleep"

state="$TEST_DIR/state"
output="$(GH_TEST_MODE=change GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-head.sh" owner/repo 7 old-head)"
[[ "$output" == $'head\tnew-head' ]]
[[ "$(<"$state")" == 3 ]]

: >"$state"
output="$(GH_TEST_MODE=closed GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-head.sh" owner/repo 7 old-head)"
[[ "$output" == $'closed\tMERGED' ]]

: >"$state"
set +e
GH_TEST_MODE=fail GH_TEST_STATE="$state" PATH="$TEST_DIR/bin:$PATH" \
  "$ROOT/scripts/wait-for-head.sh" owner/repo 7 old-head >"$TEST_DIR/out" 2>"$TEST_DIR/err"
rc=$?
set -e
[[ "$rc" == 2 ]]
[[ "$(<"$state")" == 3 ]]
grep -F "GitHub read failed three times" "$TEST_DIR/err" >/dev/null
