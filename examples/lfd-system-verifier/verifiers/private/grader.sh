#!/usr/bin/env bash
# grader.sh — held-out grader for the LFD system verifier.
#
# This grader runs the held-out tasks (test-tasks/held-out/hNN).
# The number of held-out tasks is configurable in the project's
# harness; the default for the LFD system verifier is 6 (5 baseline
# + 1 lfd-thinking-protocols-wired).
#
# The agent never reads this file or the held-out tasks; only
# run-verification.sh invokes it.
#
# Output: writes the held-out score to
# $PROJECT_DIR/logs/held-out-score.json and prints each task's
# result to stdout.
#
# Exit codes:
#   0: all held-out tasks passed (score == 1.0)
#   1: at least one task failed
#   2: setup error (e.g., wrong number of held-out tasks)

set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
TASKS_DIR="$PROJECT_DIR/test-tasks/held-out"
SCORE_FILE="${SCORE_FILE:-$PROJECT_DIR/logs/held-out-score.json}"
LOG_DIR="$(dirname "$SCORE_FILE")"
LOG_FILE="$LOG_DIR/held-out.log"

mkdir -p "$LOG_DIR"

# ----- enumerate held-out tasks -----

if [[ ! -d "$TASKS_DIR" ]]; then
  echo "error: held-out tasks dir not found: $TASKS_DIR" >&2
  exit 2
fi

TASKS=()
for d in "$TASKS_DIR"/*/; do
  [[ -d "$d" ]] || continue
  if [[ -x "$d/grade.sh" ]]; then
    TASKS+=("$(basename "$d")")
  fi
done

if [[ ${#TASKS[@]} -lt 5 || ${#TASKS[@]} -gt 10 ]]; then
  echo "error: expected 5-10 held-out tasks, found ${#TASKS[@]}" >&2
  exit 2
fi

# ----- run each held-out task -----

n_pass=0
n_fail=0
SCORES="{"

for i in "${!TASKS[@]}"; do
  task="${TASKS[$i]}"
  task_dir="$TASKS_DIR/$task"
  task_log="$LOG_DIR/$task.log"

  # Set up a per-task dir for the grader
  TASK_RUN_DIR="$(mktemp -d)"

  echo "=== running $task ==="
  if ! (cd "$task_dir" && PROJECT_DIR="$PROJECT_DIR" TASK_DIR="$TASK_RUN_DIR" \
         ./grade.sh > "$task_log" 2>&1); then
    n_fail=$((n_fail + 1))
    score=0.0
  else
    score=$(grep -oE '^score=[0-9.]+$' "$task_log" | tail -1 | cut -d= -f2)
    score="${score:-0.0}"
    n_pass=$((n_pass + 1))
  fi

  # Show the result
  cat "$task_log" | sed 's/^/  /'
  echo "  -> $task: score=$score"

  if [[ $i -gt 0 ]]; then
    SCORES+=","
  fi
  SCORES+="\"$task\": $score"

  # Clean
  rm -rf "$TASK_RUN_DIR"
done

pass_rate=$(python3 -c "print($n_pass / ($n_pass + $n_fail))")

# ----- emit aggregate score -----

cat > "$SCORE_FILE" <<EOF
{
  "pass_rate": $pass_rate,
  "n_pass": $n_pass,
  "n_fail": $n_fail,
  "scores": $SCORES
}
EOF

# ----- emit human-readable log -----

cat > "$LOG_FILE" <<EOF
# LFD System Verifier — Held-out Grader Log
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Results

EOF

for i in "${!TASKS[@]}"; do
  task="${TASKS[$i]}"
  task_log="$LOG_DIR/$task.log"
  score=$(grep -oE '^score=[0-9.]+$' "$task_log" | tail -1 | cut -d= -f2)
  passed=$([ "${score:-0}" = "1.0" ] && echo "✅ PASS" || echo "❌ FAIL")
  cat >> "$LOG_FILE" <<ENTRY
### $task — $passed

\`\`\`
$(cat "$task_log")
\`\`\`

ENTRY
done

cat >> "$LOG_FILE" <<EOF
## Aggregate

- $n_pass / $(($n_pass + $n_fail)) passed (pass_rate=$pass_rate)
EOF

echo
echo "[held-out grader] $n_pass / $(($n_pass + $n_fail)) passed (pass_rate=$pass_rate)"

if [[ $n_fail -gt 0 ]]; then
  exit 1
fi
exit 0
