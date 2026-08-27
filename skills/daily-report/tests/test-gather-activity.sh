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

if [[ "$args" == search\ prs* && "$args" == *"--created="* ]]; then
  echo $'2026-06-24\t[open]\temqx/example#10\tfeat: add daily report'
  exit 0
fi

if [[ "$args" == search\ prs* && "$args" == *"--merged-at="* ]]; then
  echo $'2026-06-24\temqx/example#9\tfix: tighten report wording'
  exit 0
fi

if [[ "$args" == search\ issues* && "$args" == *"--created="* ]]; then
  echo $'2026-06-24\t[open]\temqx/example#11\tTrack daily report output'
  exit 0
fi

if [[ "$args" == search\ issues* && "$args" == *"--closed="* ]]; then
  echo $'2026-06-24\t[closed]\temqx/example#8\tOld report format'
  exit 0
fi

if [[ "$args" == release\ list* && "$args" == *"--repo emqx/example"* ]]; then
  echo $'2026-06-24\temqx/example\tv1.0.0\tDaily report release'
  exit 0
fi

if [[ "$args" == api\ user* ]]; then
  echo "test-user"
  exit 0
fi

echo "unexpected gh invocation: $args" >&2
exit 2
GH
chmod +x "$TMPDIR/bin/gh"

output="$(PATH="$TMPDIR/bin:$PATH" "$ROOT/scripts/gather-activity.sh" 2026-06-24 test-user)"

grep -F "# date:  2026-06-24 [UTC+8 / Asia/Shanghai]" <<<"$output" >/dev/null
grep -F $'2026-06-24\t[open]\temqx/example#10\tfeat: add daily report' <<<"$output" >/dev/null
grep -F $'2026-06-24\temqx/example#9\tfix: tighten report wording' <<<"$output" >/dev/null
grep -F $'2026-06-24\t[closed]\temqx/example#8\tOld report format' <<<"$output" >/dev/null
grep -F $'2026-06-24\temqx/example\tv1.0.0\tDaily report release' <<<"$output" >/dev/null

default_output="$(DAILY_REPORT_TODAY=2026-06-24 PATH="$TMPDIR/bin:$PATH" "$ROOT/scripts/gather-activity.sh")"
grep -F "# date:  2026-06-23 [UTC+8 / Asia/Shanghai]" <<<"$default_output" >/dev/null

holiday_output="$(DAILY_REPORT_TODAY=2026-02-24 PATH="$TMPDIR/bin:$PATH" "$ROOT/scripts/gather-activity.sh")"
grep -F "# date:  2026-02-14 [UTC+8 / Asia/Shanghai]" <<<"$holiday_output" >/dev/null

makeup_output="$(DAILY_REPORT_TODAY=2026-09-21 PATH="$TMPDIR/bin:$PATH" "$ROOT/scripts/gather-activity.sh")"
grep -F "# date:  2026-09-20 [UTC+8 / Asia/Shanghai]" <<<"$makeup_output" >/dev/null
