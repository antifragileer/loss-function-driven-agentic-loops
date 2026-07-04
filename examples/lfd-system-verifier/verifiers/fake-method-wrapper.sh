#!/usr/bin/env bash
# fake-method-wrapper.sh — the deterministic stub that
# exercises the LFD *method* (candidate → score → improvement →
# forced-entropy), as opposed to fake-wrapper.sh which only
# exercises the LFD *tools* (parser, install, driver).
#
# Same wrapper contract as the other adapters (positional TASK,
# --cwd, --timeout, --cycle). The difference: the candidate
# text varies by cycle to simulate an agent's improvement
# across cycles of the loss-function-driven loop.
#
# Cycle-to-candidate mapping:
#   cycle 1 → poor candidate (legibility 0.0, no candidate_text)
#             so the loop's legibility sub-loss is 0.0 and
#             pass_rate is 0.
#   cycle 2 → great candidate (legibility 1.0, 10+ line
#             candidate_text) so the loop sees a big improvement
#             and best-cycle.json gets updated.
#   cycle 3+ → plateau (same great candidate as cycle 2),
#             so the loop's "consecutive_no_improvement" counter
#             increments and the cycle's LOG_LINE includes
#             FORCED_ENTROPY=true on the next cycle.
#
# The simulator's behavior is bit-exact deterministic: same
# cycle → same output, every run.
#
# Usage:
#   verifiers/fake-method-wrapper.sh "<task-prompt>" --cwd PATH \
#       --timeout 30 --cycle cycle-2 > cycle-summary.json
#
# This stub is part of the LFD system verifier (dogfood) and
# is NOT a real coding agent. For real development cycles,
# use one of the 5 real adapter skills: cline, claude-code,
# codex, hermes-agent, opencode.

set -euo pipefail

# ----- argument parsing (same shape as the other wrappers) -----

TASK=""
CWD=""
TIMEOUT=30
CYCLE="cycle-0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --cycle)
      CYCLE="${2:-cycle-0}"
      shift 2
      ;;
    --cycle=*) CYCLE="${1#--cycle=}"; shift ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) TASK="$1"; shift ;;
  esac
done

if [[ -z "$TASK" ]]; then
  echo '{"error":"missing positional TASK arg"}' >&2
  exit 2
fi
if [[ -z "$CWD" ]]; then
  echo '{"error":"missing --cwd"}' >&2
  exit 2
fi
if [[ ! -d "$CWD" ]]; then
  echo "{\"error\":\"cwd does not exist: $CWD\"}" >&2
  exit 2
fi

# ----- cycle-to-candidate mapping -----

# Parse the cycle number from $CYCLE (e.g. "cycle-2" -> 2).
# Default to 1 if the format is unexpected.
CYCLE_NUM=1
if [[ "$CYCLE" =~ cycle-([0-9]+) ]]; then
  CYCLE_NUM="${BASH_REMATCH[1]}"
fi

case "$CYCLE_NUM" in
  1)
    # Cycle 1: poor candidate. Empty candidate_text → legibility=0.0.
    # The loop's score is the floor (0.0).
    CANDIDATE_TEXT=""
    ;;
  2)
    # Cycle 2: great candidate. The loop's score should jump
    # dramatically and best-cycle.json gets updated.
    CANDIDATE_TEXT="This is a great candidate skill.
It contains 10 or more lines so the legibility sub-loss
returns its full score. It addresses the task prompt
directly and demonstrates the agent's improvement after
the baseline cycle.
The verifier uses this candidate text to exercise the
loss-function-driven loop's improvement-tracking machinery:
the cycle 2 candidate is much better than cycle 1, so the
loop's best-cycle tracking updates and the iteration log
records the improvement."
    ;;
  *)
    # Cycle 3+: plateau. Same great candidate as cycle 2, so the
    # loop's "consecutive_no_improvement" counter increments
    # and the cycle's LOG_LINE includes FORCED_ENTROPY=true.
    CANDIDATE_TEXT="This is a great candidate skill.
It contains 10 or more lines so the legibility sub-loss
returns its full score. It addresses the task prompt
directly and demonstrates the agent's improvement after
the baseline cycle.
The verifier uses this candidate text to exercise the
loss-function-driven loop's improvement-tracking machinery:
the cycle 2 candidate is much better than cycle 1, so the
loop's best-cycle tracking updates and the iteration log
records the improvement."
    ;;
esac

# Raw output path (deterministic, no $RANDOM, no $$)
RAW_OUTPUT_PATH="${CWD}/.iterations/${CYCLE}/fake-method.json"

# Build the deterministic JSON. Use python for exact JSON
# formatting (no trailing spaces, no locale-dependent number
# formatting).
python3 - "$TASK" "$CYCLE" "$CWD" "$RAW_OUTPUT_PATH" "$CANDIDATE_TEXT" <<'PYEOF'
import json, sys
task, cycle, cwd, raw_path, candidate_text = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
out = {
    "cycle": cycle,
    "exit_code": 0,
    "elapsed_seconds": 0,
    "claude_duration_ms": 0,
    "tokens": 0,
    "model": "fake-method",
    "provider": "stub",
    "candidate_text": candidate_text,
    "tool_calls": [
        {"name": "write_candidate", "args": {"path": "candidate.md"}}
    ],
    "finish_reason": "completed",
    "iterations": 1,
    "raw_output_path": raw_path,
}
print(json.dumps(out, indent=2))
PYEOF

# Write the candidate to the cwd
mkdir -p "${CWD}/.iterations/${CYCLE}"
cat > "${CWD}/.iterations/${CYCLE}/candidate.md" <<CANDIDATE_EOF
# Candidate (fake-method stub, cycle $CYCLE_NUM)

${CANDIDATE_TEXT}
CANDIDATE_EOF

exit 0
