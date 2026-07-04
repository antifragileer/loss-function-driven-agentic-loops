#!/usr/bin/env bash
# time-remaining.sh — print seconds remaining since the
# loop started. Used by cycle.sh's wall-clock stop condition.
set -euo pipefail

STATE_FILE="${PROJECT_DIR:-.}/logs/.loop_start_ts"

if [[ "${1:-}" == "--set" ]]; then
  date +%s > "$STATE_FILE"
  echo "loop start set: $(cat "$STATE_FILE")"
  exit 0
fi

if [[ ! -s "$STATE_FILE" ]]; then
  date +%s > "$STATE_FILE"
fi

START=$(cat "$STATE_FILE")
NOW=$(date +%s)
WALL_BUDGET="${WALL_BUDGET_SECONDS:-300}"  # 5 minutes for the verifier
echo $(( WALL_BUDGET - (NOW - START) ))
