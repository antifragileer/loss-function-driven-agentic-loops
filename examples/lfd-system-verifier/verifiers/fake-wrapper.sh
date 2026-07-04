#!/usr/bin/env bash
# fake-wrapper.sh — the ONLY way to invoke the inner
# agent inside the LFD system verifier (dogfood).
#
# This is the deterministic stub. It does NOT invoke a
# model, does NOT make network calls, and produces
# bit-exact reproducible output.
#
# Usage:
#   verifiers/fake-wrapper.sh "<task-prompt>" --cwd PATH \
#       --timeout 30 --cycle cycle-1 > cycle-summary.json
#
# Why these properties:
# - No model: the verifier is dogfood; we're testing
#   the LFD system, not a coding agent.
# - No network: the verifier must run offline.
# - Bit-exact: two consecutive runs of the verifier
#   must produce byte-identical output.
#
# Compatibility:
# - Positional TASK: same as the other 5 adapter wrappers
# - --cwd / --timeout / --cycle: same shape
# - JSON output on stdout with the 8 shared keys
# - Exit 0 on success, 2 on usage error
#
# See skills/fake-agent-orchestration/ for the adapter
# contract this wrapper implements.

set -euo pipefail

# ----- argument parsing -----

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

# ----- deterministic output -----

# The candidate text is the task prompt itself. This
# makes the loop's legibility_score sub-loss see a
# real candidate (not empty) without any model.
# Use printf (not echo) to avoid trailing newlines
# from echo varying across shells.
CANDIDATE_TEXT="$TASK"

# Raw output path (deterministic, no $RANDOM, no $$)
RAW_OUTPUT_PATH="${CWD}/.iterations/${CYCLE}/fake.json"

# Build the deterministic JSON. We use python for
# exact JSON formatting (no trailing spaces, no
# locale-dependent number formatting).
START_NS=$(date +%s)
python3 - "$TASK" "$CYCLE" "$CWD" "$RAW_OUTPUT_PATH" <<'PYEOF'
import json, sys
task, cycle, cwd, raw_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
out = {
    "cycle": cycle,
    "exit_code": 0,
    "elapsed_seconds": 0,
    "claude_duration_ms": 0,
    "tokens": 0,
    "model": "fake",
    "provider": "stub",
    "candidate_text": task,
    "tool_calls": [
        {"name": "write_candidate", "args": {"path": "candidate.md"}}
    ],
    "finish_reason": "completed",
    "iterations": 1,
    "raw_output_path": raw_path,
}
print(json.dumps(out, indent=2))
PYEOF
END_NS=$(date +%s)

# Write the deterministic candidate.md to the cwd
# (a fixed 10-line stub). This is the "candidate skill"
# the agent would have produced.
mkdir -p "${CWD}/.iterations/${CYCLE}"
cat > "${CWD}/.iterations/${CYCLE}/candidate.md" <<'CANDIDATE_EOF'
# Candidate Skill (fake-agent stub)

This file was written by the deterministic fake-agent
wrapper. It is intentionally trivial: the verifier
tests the LFD system, not the agent's coding ability.

## Inputs
- cwd
- cycle
- task prompt

## Outputs
- this file (candidate.md)
- cycle-summary.json (printed to stdout)
CANDIDATE_EOF

exit 0
