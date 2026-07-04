#!/usr/bin/env bash
# run-design-set.sh — run the wrapper + per-task grader for
# every design task in test-tasks/design/ and emit an
# aggregate JSON score to stdout.
#
# Usage:
#   PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh [task-name]
#
# If [task-name] is given, runs only that one design task
# (used by the held-out graders to test individual tasks).
# Otherwise runs all design tasks.
#
# Output (stdout): aggregate JSON score.
# Output (stderr): progress messages.
#
# Exit codes:
#   0: all design tasks passed (pass_rate == 1.0)
#   1: at least one task failed
#   2: usage error
#
# The cycle driver calls this with stdout redirected to
# $CYCLE_DIR/design-set-score.json. We must NOT print
# anything else to stdout — only the JSON.

set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
TASKS_DIR="$PROJECT_DIR/test-tasks/design"
TASK_FILTER="${1:-}"

if [[ ! -d "$TASKS_DIR" ]]; then
  echo "error: design tasks dir not found: $TASKS_DIR" >&2
  exit 2
fi

# Discover tasks: subdirectories of TASKS_DIR sorted by name
TASKS=()
for d in "$TASKS_DIR"/*/; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  if [[ -n "$TASK_FILTER" && "$name" != "$TASK_FILTER" ]]; then
    continue
  fi
  if [[ -f "$d/prompt.txt" ]] && [[ -x "$d/grade.sh" ]]; then
    TASKS+=("$name")
  fi
done

if [[ ${#TASKS[@]} -eq 0 ]]; then
  if [[ -n "$TASK_FILTER" ]]; then
    echo "error: no design task named '$TASK_FILTER' in $TASKS_DIR" >&2
  else
    echo "error: no design tasks found in $TASKS_DIR" >&2
  fi
  exit 2
fi

# Where to put per-task logs (NOT stdout)
LOGS_DIR="${RUN_DESIGN_SET_LOGS_DIR:-$PROJECT_DIR/logs/cycle-1}"
mkdir -p "$LOGS_DIR"

# ----- run each design task -----

n_pass=0
n_fail=0
SCORES_JSON=""

for i in "${!TASKS[@]}"; do
  task="${TASKS[$i]}"
  task_dir="$TASKS_DIR/$task"
  task_run_dir="$LOGS_DIR/$task"
  mkdir -p "$task_run_dir"

  # Read the task prompt
  prompt=$(cat "$task_dir/prompt.txt")

  # Run the wrapper
  cycle_name="cycle-${CYCLE:-1}-${task}"
  if ! "$PROJECT_DIR/verifiers/fake-wrapper.sh" "$prompt" \
        --cwd "$task_run_dir" --timeout 30 --cycle "$cycle_name" \
        > "$task_run_dir/cycle-summary.json" 2>"$task_run_dir/wrapper.stderr"; then
    echo "[run-design-set] wrapper failed for $task (exit $?)" >&2
  fi

  # Run the grader
  task_log="$task_run_dir/grade.log"
  if ! (cd "$task_dir" && PROJECT_DIR="$PROJECT_DIR" TASK_DIR="$task_run_dir" \
         ./grade.sh > "$task_log" 2>&1); then
    n_fail=$((n_fail + 1))
    score=0.0
  else
    # Parse score from the grader's grade.log
    score=$(grep -oE '^score=[0-9.]+$' "$task_log" | tail -1 | cut -d= -f2)
    score="${score:-0.0}"
    n_pass=$((n_pass + 1))
  fi

  # Build the per-task score entry
  if [[ -n "$SCORES_JSON" ]]; then
    SCORES_JSON+=","
  fi
  passed=$(python3 -c "print('true' if float('$score') > 0 else 'false')")
  SCORES_JSON+="\"$task\": {\"score\": $score, \"passed\": $passed}"
done

pass_rate=$(python3 -c "print($n_pass / ($n_pass + $n_fail) if ($n_pass + $n_fail) > 0 else 0)")

# ----- emit aggregate score to stdout (only!) -----

cat <<EOF
{
  "pass_rate": $pass_rate,
  "n_pass": $n_pass,
  "n_fail": $n_fail,
  "scores": {$SCORES_JSON}
}
EOF

# Progress messages go to stderr (NOT stdout; the cycle driver
# redirects stdout to design-set-score.json and we don't want
# to corrupt that file).
echo "[run-design-set] $n_pass passed, $n_fail failed (pass_rate=$pass_rate)" >&2

if [[ $n_fail -gt 0 ]]; then
  exit 1
fi
exit 0
