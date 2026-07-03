#!/usr/bin/env bash
# fake-cline.sh — a fake cline binary for loop-driver
# integration testing.
#
# This script stands in for the real `cline` CLI during
# end-to-end tests of cycle.sh / run-loop.sh. It:
#   1. Reads --cwd <dir> from cline's argv
#   2. Writes a fake cline.json NDJSON event into <dir>
#   3. Optionally varies the candidate_text by the task
#      name embedded in the dir path (so different design
#      tasks can pass/fail differently)
#   4. Exits 0
#
# Use it to verify the loop end-to-end without invoking
# a real LLM:
#
#   mkdir -p /tmp/fake-bin
#   cp templates/fake-cline.sh /tmp/fake-bin/cline
#   chmod +x /tmp/fake-bin/cline
#   PATH=/tmp/fake-bin:$PATH \
#     run-loop.sh --project-root /tmp/test-loop \
#                 --wrapper-timeout 30
#
# Customize the task-name → text mapping by editing the
# `case "$DEST"` block below. Default behavior: any dir
# containing "01-implement" gets a "send-message" answer
# (so a `grade.sh` that greps for "send|message" passes).
# Other dirs get a generic "fake output" that fails the
# grep.

set -euo pipefail

DEST=""
MODEL_ID="${FAKE_CLINE_MODEL:-fake}"
PROVIDER="${FAKE_CLINE_PROVIDER:-fake-test}"
INPUT_TOKENS="${FAKE_CLINE_INPUT_TOKENS:-100}"
OUTPUT_TOKENS="${FAKE_CLINE_OUTPUT_TOKENS:-200}"
DURATION_MS="${FAKE_CLINE_DURATION_MS:-1000}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) DEST="$2"; shift 2 ;;
    --*) shift ;;
    *) shift ;;
  esac
done

[[ -z "$DEST" ]] && DEST="."
mkdir -p "$DEST"

# Per-task text overrides. The dir path contains the
# task slug (e.g., "01-implement-a-function-that-takes-a").
# Set FAKE_CLINE_FAIL_ALL=1 to make every task fail (for
# negative testing).
TEXT="fake cline output for $DEST"
if [[ "${FAKE_CLINE_FAIL_ALL:-0}" == "1" ]]; then
  TEXT="this output intentionally fails any grade.sh that checks for keywords"
elif [[ "$DEST" == *"01-implement"* ]] || [[ "$DEST" == *"01-send"* ]]; then
  TEXT="Wrote a send-message function that takes a channel name and a message string, posts the message, and returns the message ID."
elif [[ "$DEST" == *"02-list"* ]] || [[ "$DEST" == *"02-channels"* ]]; then
  TEXT="Wrote a list-channels function that returns the list of channels the current user belongs to."
elif [[ "$DEST" == *"03-react"* ]] || [[ "$DEST" == *"03-emoji"* ]]; then
  TEXT="Wrote a react-emoji function that adds a :fire: reaction and returns the count."
elif [[ "$DEST" == *"04-thread"* ]]; then
  TEXT="Wrote a thread-reply function that posts a threaded reply and returns the thread root ID."
elif [[ "$DEST" == *"05-mark"* ]]; then
  TEXT="Wrote a mark-read function that marks a channel as read up to a given message ID."
fi

# Emit the NDJSON run_result event into <dir>/cline.json
# (the wrapper expects this path).
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))
TEXT_ESCAPED=$(printf '%s' "$TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

cat > "$DEST/cline.json" <<JSON
{"type":"run_result","aggregateUsage":{"inputTokens":${INPUT_TOKENS},"outputTokens":${OUTPUT_TOKENS},"cacheReadTokens":0},"durationMs":${DURATION_MS},"text":${TEXT_ESCAPED},"model":{"id":"${MODEL_ID}","provider":"${PROVIDER}"},"finishReason":"completed","iterations":1}
JSON

# Emit a stderr line for the wrapper to capture
echo "[fake-cline] wrote $DEST/cline.json (${TOTAL_TOKENS} tokens, ${DURATION_MS}ms)" >&2

exit 0
