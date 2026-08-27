#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail

args="$*"

if [[ "$args" == search\ prs* && "$args" == *"--created="* && "$args" == *"--json repository,number,title,state,createdAt,url"* ]]; then
  echo $'2026-06-01\t[merged]\temqx/example#1\tfeat: add example\thttps://github.com/emqx/example/pull/1'
  exit 0
fi

if [[ "$args" == search\ prs* && "$args" == *"--merged-at="* ]]; then
  echo $'2026-06-02\temqx/example#1\tfeat: add example\thttps://github.com/emqx/example/pull/1'
  exit 0
fi

if [[ "$args" == search\ prs* && "$args" == *"--json repository --jq"* ]]; then
  echo "emqx/example"
  exit 0
fi

if [[ "$args" == release\ list* && "$args" == *"--json name,tagName,publishedAt,url"* ]]; then
  echo 'Unknown JSON field: "url"' >&2
  exit 1
fi

if [[ "$args" == release\ list* && "$args" == *"--repo emqx/example"* && "$args" == *"--json name,tagName,publishedAt"* ]]; then
  echo $'2026-06-03\temqx/example\tv1.2.3\tExample release\thttps://github.com/emqx/example/releases/tag/v1.2.3'
  exit 0
fi

echo "unexpected gh invocation: $args" >&2
exit 2
GH
chmod +x "$TMPDIR/bin/gh"

output="$(PATH="$TMPDIR/bin:$PATH" "$ROOT/scripts/gather-prs.sh" 2026-06-01 2026-06-07 test-user)"

grep -F "=== RELEASES (published in window for touched repos) ===" <<<"$output" >/dev/null
grep -F $'2026-06-03\temqx/example\tv1.2.3\tExample release\thttps://github.com/emqx/example/releases/tag/v1.2.3' <<<"$output" >/dev/null

calendar_output="$(PATH="$TMPDIR/bin:$PATH" "$ROOT/scripts/gather-prs.sh" 2026-09-14 2026-09-20 test-user)"
grep -F "=== CHINA WORKDAY CALENDAR (exceptions in window) ===" <<<"$calendar_output" >/dev/null
grep -F $'2026-09-20\tworkday\t国庆节调休' <<<"$calendar_output" >/dev/null
