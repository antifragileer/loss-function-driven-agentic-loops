#!/usr/bin/env bash
# run-loop.sh — drive cycle.sh in a loop until a stop condition.
#
# This is the *driver of the driver*. cycle.sh is the inner
# driver (one cycle). run-loop.sh is the outer driver (many
# cycles, until a stop).
#
# Usage:
#   run-loop.sh --project-root PATH [--max-cycles 100] \
#               [--delta 0.05] [--max-stall 3] \
#               [--wrapper-timeout 600]
#
# Exit codes:
#   0: loop completed (success or stall)
#   1: usage error or cycle.sh failed unexpectedly
#   2: project-root does not exist
#
# Output: a final iteration-log entry and best-cycle.json,
# same as cycle.sh. The loop-driver is purely a wrapper that
# invokes cycle.sh repeatedly.

set -euo pipefail

PROJECT_ROOT=""
MAX_CYCLES=100
DELTA=0.05
MAX_STALL=3
WRAPPER_TIMEOUT=600

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --max-cycles) MAX_CYCLES="$2"; shift 2 ;;
    --delta) DELTA="$2"; shift 2 ;;
    --max-stall) MAX_STALL="$2"; shift 2 ;;
    --wrapper-timeout) WRAPPER_TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^[^#]/{/^[^#]/q; p}' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "usage: run-loop.sh --project-root PATH [--max-cycles N] ..." >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "error: project-root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CYCLE_SH="$SCRIPT_DIR/cycle.sh"

if [[ ! -x "$CYCLE_SH" ]]; then
  echo "error: cycle.sh not found or not executable: $CYCLE_SH" >&2
  exit 2
fi

echo "[loop] starting, project=$PROJECT_ROOT, max_cycles=$MAX_CYCLES" >&2

n_cycles=0
exit_reason="unknown"
while [[ $n_cycles -lt $MAX_CYCLES ]]; do
  n_cycles=$((n_cycles + 1))
  echo "[loop] === cycle $n_cycles ===" >&2

  # Run the cycle. cycle.sh exits 3 on stop conditions, 0 on
  # success-or-no-improvement, 1 on errors.
  set +e
  CYCLE_OUT=$("$CYCLE_SH" --project-root "$PROJECT_ROOT" \
              --delta "$DELTA" --max-stall "$MAX_STALL" \
              --wrapper-timeout "$WRAPPER_TIMEOUT" 2>&1)
  rc=$?
  set -e

  # Print the cycle output (cycle.sh writes JSON to stdout,
  # everything else to stderr)
  echo "$CYCLE_OUT" | head -20

  if [[ $rc -eq 3 ]]; then
    # Stop condition. cycle.sh already printed the reason as JSON.
    exit_reason=$(echo "$CYCLE_OUT" | sed -n 's/.*"stop": *"\([^"]*\)".*/\1/p' | head -1)
    echo "[loop] stopped: $exit_reason (after $n_cycles cycles)" >&2
    # Log the stop in the iteration log
    BEST_WSUM=$(python3 -c "import json; print(json.load(open('$PROJECT_ROOT/logs/best-cycle.json')).get('weighted_normalized', 0.0))" 2>/dev/null || echo "0.0")
    # pass_rate lives in the design-set-score.json, not the sub-losses;
    # find the most recent one
    BEST_PSR=$(python3 -c "
import json, glob, os
files = sorted(glob.glob('$PROJECT_ROOT/logs/cycle-*/design-set-score.json'))
if files:
    d = json.load(open(files[-1]))
    print(d.get('pass_rate', 0.0))
else:
    print(0.0)
" 2>/dev/null || echo "0.0")
    echo "STOP: $exit_reason. After $n_cycles cycles. Best weighted_sum=$BEST_WSUM. Best pass_rate=$BEST_PSR." >> "$PROJECT_ROOT/logs/iteration-log.md"
    break
  elif [[ $rc -ne 0 ]]; then
    echo "[loop] cycle.sh exited $rc — continuing" >&2
  fi
done

if [[ $n_cycles -ge $MAX_CYCLES ]]; then
  echo "[loop] reached max_cycles=$MAX_CYCLES, exiting" >&2
fi

echo "[loop] done. Reason: $exit_reason. Cycles: $n_cycles." >&2
