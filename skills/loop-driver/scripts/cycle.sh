#!/usr/bin/env bash
# cycle.sh — run one cycle of the loss-function-driven loop.
#
# This is the loop-driver's main executable. It runs ONE
# cycle (not the whole loop). For the whole loop, call
# cycle.sh in a loop from your driver-of-driver (Hermes
# session, shell script, CI runner, etc.).
#
# Usage:
#   cycle.sh --project-root PATH [--cycle N] [--delta 0.05] \
#            [--max-stall 3] [--success-after 2] [--wrapper-timeout 600] \
#            [--runtime cline|codex|aider] \
#            [--artifact-name NAME] [--dry-run]
#
# The script:
#   1. Reads the iteration log + best cycle
#   2. Forms a hypothesis (cycle 0: baseline; cycle 1+: from log)
#   3. Builds the cycle input JSON
#   4. Invokes the wrapper (or skips with --dry-run)
#   5. Runs the design set
#   6. Scores the cycle
#   7. Appends to the iteration log
#   8. Updates best-cycle.json if improved
#   9. Emits a stop-check JSON to stdout
#
# Exit codes:
#   0: cycle completed (may or may not have improved)
#   1: cycle failed (wrapper error, scorer error)
#   2: usage error
#   3: stop condition fired (success, wall-clock, tokens, stall)
#
# This script is portable — it does not depend on any
# profile-specific paths. The harness-scaffold skill
# generates the wrapper, design-set-runner, and instruments
# the script calls. As long as those exist, cycle.sh works.

set -euo pipefail

# ----- argument parsing -----

PROJECT_ROOT=""
CYCLE=""
DELTA="0.05"
MAX_STALL="3"
SUCCESS_AFTER="2"
WRAPPER_TIMEOUT="600"
RUNTIME=""
ARTIFACT_NAME=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --cycle) CYCLE="$2"; shift 2 ;;
    --delta) DELTA="$2"; shift 2 ;;
    --max-stall) MAX_STALL="$2"; shift 2 ;;
    --success-after) SUCCESS_AFTER="$2"; shift 2 ;;
    --wrapper-timeout) WRAPPER_TIMEOUT="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --artifact-name) ARTIFACT_NAME="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help)
      sed -n '2,/^[^#]/{/^[^#]/q; p}' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "usage: cycle.sh --project-root PATH [--cycle N] ..." >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "error: project-root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

# ----- resolve runtime -----

if [[ -z "$RUNTIME" ]]; then
  # Try multiple patterns to find the runtime.
  RUNTIME=""
  if [[ -f "$PROJECT_ROOT/GOAL.md" ]]; then
    RUNTIME=$(grep -oE 'inner loop is the `\w+` CLI' "$PROJECT_ROOT/GOAL.md" 2>/dev/null | head -1 | sed 's/.*`\([^`]*\)`.*/\1/' || true)
    if [[ -z "$RUNTIME" ]]; then
      RUNTIME=$(grep -oE 'verifiers/[a-z]+-wrapper\.sh' "$PROJECT_ROOT/GOAL.md" 2>/dev/null | head -1 | sed 's|verifiers/||; s|-wrapper.sh||' || true)
    fi
    if [[ -z "$RUNTIME" ]]; then
      RUNTIME=$(grep -oE 'the only \w+ invocation' "$PROJECT_ROOT/GOAL.md" 2>/dev/null | head -1 | awk '{print $3}' || true)
    fi
  fi
  RUNTIME="${RUNTIME:-cline}"
fi

# ----- resolve artifact name -----

if [[ -z "$ARTIFACT_NAME" ]]; then
  # Try to parse from GOAL.md
  ARTIFACT_NAME=""
  if [[ -f "$PROJECT_ROOT/GOAL.md" ]]; then
    ARTIFACT_NAME=$(grep -oE '`skills/[^/`]+/' "$PROJECT_ROOT/GOAL.md" 2>/dev/null | head -1 | sed 's|`skills/||; s|/||' || true)
  fi
  ARTIFACT_NAME="${ARTIFACT_NAME:-driver-skill}"
fi

# ----- find the wrapper and the design-set runner -----

WRAPPER="$PROJECT_ROOT/verifiers/${RUNTIME}-wrapper.sh"
DESIGN_SET="$PROJECT_ROOT/verifiers/run-design-set.sh"
SKILLS_DIR_INSTRUMENT="$PROJECT_ROOT/verifiers/instruments/${RUNTIME}-skills-dir.sh"

if [[ ! -x "$WRAPPER" ]]; then
  echo "error: wrapper not found or not executable: $WRAPPER" >&2
  exit 2
fi
if [[ ! -x "$DESIGN_SET" ]]; then
  echo "error: design-set runner not found: $DESIGN_SET" >&2
  exit 2
fi

# ----- reject incomplete harnesses -----
#
# The harness must be complete (every grade.sh a real grader,
# every held-out task populated) before the /goal prompt is
# emitted. If we find stub markers or empty held-out dirs,
# refuse to run -- the user must finish the harness first.

STUB_HITS=0
STUB_FILES=()
# 1. Look for "TODO" / "stub" markers in design-task grade.sh files.
if [[ -d "$PROJECT_ROOT/test-tasks/design" ]]; then
  while IFS= read -r -d '' g; do
    # Anything that says "TODO" or has an `exit 1` with a comment
    # that doesn't actually check anything is a stub. We grep for
    # the explicit stub marker, plus a defensive "exit 1" + "TODO"
    # co-occurrence.
    if grep -qE '(TODO.*grade|TODO.*meta-fill|exit 1[[:space:]]*#.*TODO)' "$g" 2>/dev/null; then
      STUB_HITS=$((STUB_HITS + 1))
      STUB_FILES+=("$g")
    fi
  done < <(find "$PROJECT_ROOT/test-tasks/design" -name 'grade.sh' -print0 2>/dev/null || true)
fi
# 2. Look for empty held-out task directories (placeholder README
#    is fine; missing task content is not).
if [[ -d "$PROJECT_ROOT/test-tasks/held-out" ]]; then
  while IFS= read -r -d '' d; do
    # Each held-out task dir should have at least a prompt.txt
    # AND a starting file AND a grade.sh. The scaffold places a
    # README.md placeholder; we want real task content.
    if [[ ! -f "$d/prompt.txt" || ! -f "$d/grade.sh" ]]; then
      STUB_HITS=$((STUB_HITS + 1))
      STUB_FILES+=("$d")
    fi
  done < <(find "$PROJECT_ROOT/test-tasks/held-out" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
fi

if [[ "$STUB_HITS" -gt 0 ]]; then
  echo "error: harness is incomplete — found $STUB_HITS stub/missing files:" >&2
  for f in "${STUB_FILES[@]}"; do
    echo "  - $f" >&2
  done
  echo "" >&2
  echo "The /goal prompt was emitted against a harness that did not" >&2
  echo "pass the harness-completeness-checklist. Re-run the" >&2
  echo "meta-loss-function-development skill, complete the" >&2
  echo "checklist (fill stub graders, populate held-out tasks)," >&2
  echo "and re-emit the /goal prompt." >&2
  exit 2
fi

# ----- ensure logs dir -----

mkdir -p "$PROJECT_ROOT/logs"
LOG_FILE="$PROJECT_ROOT/logs/iteration-log.md"
[[ -f "$LOG_FILE" ]] || : > "$LOG_FILE"
BEST_FILE="$PROJECT_ROOT/logs/best-cycle.json"
[[ -f "$BEST_FILE" ]] || echo '{"weighted_normalized": 0.0, "pass_rate": 0.0}' > "$BEST_FILE"

# ----- resolve cycle number -----

if [[ -z "$CYCLE" ]]; then
  if [[ -f "$LOG_FILE" ]]; then
    LAST_CYCLE=$(sed -n 's/.*cycle \([0-9]*\).*/\1/p' "$LOG_FILE" | tail -1 || echo "0")
    CYCLE=$((LAST_CYCLE + 1))
  else
    CYCLE=1
  fi
fi

# ----- read prior state -----

PRIOR_PSR=$(python3 -c "import json; d=json.load(open('$BEST_FILE')); print(d.get('pass_rate', 0.0))" 2>/dev/null || echo "0.0")
PRIOR_WSUM=$(python3 -c "import json; d=json.load(open('$BEST_FILE')); print(d.get('weighted_normalized', 0.0))" 2>/dev/null || echo "0.0")
PRIOR_GATES=$(python3 -c "import json; d=json.load(open('$BEST_FILE')); print(d.get('gates_passed', False))" 2>/dev/null || echo "False")

# ----- check stop conditions -----

# Wall-clock
TIME_REMAINING="$PROJECT_ROOT/verifiers/instruments/time-remaining.sh"
WALL_CLOCK_LEFT=999999
if [[ -x "$TIME_REMAINING" ]]; then
  WALL_CLOCK_LEFT=$("$TIME_REMAINING" 2>/dev/null || echo "999999")
fi
if [[ "$WALL_CLOCK_LEFT" -le 0 ]]; then
  echo '{"stop": "wall-clock", "reason": "wall-clock budget exhausted"}'
  exit 3
fi

# Tokens
TOKENS_REMAINING="$PROJECT_ROOT/verifiers/instruments/tokens-remaining.sh"
TOKENS_LEFT=999999999
if [[ -x "$TOKENS_REMAINING" ]]; then
  TOKENS_LEFT=$("$TOKENS_REMAINING" 2>/dev/null || echo "999999999")
fi
if [[ "$TOKENS_LEFT" -le 0 ]]; then
  echo '{"stop": "tokens", "reason": "token budget exhausted"}'
  exit 3
fi

# ----- pre-cycle anti-cheat firewall -----
#
# The integrity script is the harness's anti-cheat guard.
# It runs 5 default checks (no TODO stub grade.sh, no
# stub-always-passes, no sleep-in-grader, AGENTS.md has hard
# rules, no transcript references the held-out or private
# surfaces). On any failure we refuse to run the cycle —
# the harness is incomplete or has been tampered with.
INTEGRITY="$PROJECT_ROOT/verifiers/integrity.sh"
if [[ -x "$INTEGRITY" ]]; then
  if ! "$INTEGRITY" >&2; then
    echo '{"stop": "integrity", "reason": "verifiers/integrity.sh failed; harness incomplete or tampered"}'
    exit 3
  fi
fi

# ----- parse multi-axis target from GOAL.md -----
#
# The stop condition requires all multi-axis thresholds
# to hold simultaneously. We parse the Target section
# of GOAL.md for explicit threshold fields. The default
# if a field is missing is the single-axis "pass_rate=1.0"
# legacy behavior, so old GOAL.md files still work.
TARGET_PASSRATE="1.0"
TARGET_WEIGHTED="0.85"
TARGET_REQUIRE_INTEGRITY="true"
TARGET_REQUIRE_FRESHNESS="true"
TARGET_REQUIRE_HIDDEN="true"
GOAL_FILE="$PROJECT_ROOT/GOAL.md"
if [[ -f "$GOAL_FILE" ]]; then
  parsed_passrate=$(python3 -c "
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'pass[_ ]?rate\s*>=\s*([0-9]+(?:\.[0-9]+)?)', text, re.I)
print(m.group(1) if m else '')
" "$GOAL_FILE" 2>/dev/null || true)
  [[ -n "$parsed_passrate" ]] && TARGET_PASSRATE="$parsed_passrate"
  parsed_wsum=$(python3 -c "
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'weighted[_ ]?sum\s*>=\s*([0-9]+(?:\.[0-9]+)?)', text, re.I)
print(m.group(1) if m else '')
" "$GOAL_FILE" 2>/dev/null || true)
  [[ -n "$parsed_wsum" ]] && TARGET_WEIGHTED="$parsed_wsum"
fi

# ----- read recent log for hypothesis + stall detection -----

LAST_5=$(tail -5 "$LOG_FILE" 2>/dev/null || true)
CONSECUTIVE_NO_IMPROVEMENT=0
FORCED_ENTROPY_APPLIED=0
LAST_PSR="$PRIOR_PSR"
LAST_WSUM="$PRIOR_WSUM"
LAST_G="g"

# Count stalls in last MAX_STALL cycles
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == STOP:* ]] && continue
  [[ "$line" == OVERRIDE:* ]] && continue

  cycle_psr=$(echo "$line" | sed -n 's/.*pass_rate=\([0-9.]*\).*/\1/p' | head -1)
  cycle_wsum=$(echo "$line" | sed -n 's/.*weighted_sum=\([0-9.]*\).*/\1/p' | head -1)
  cycle_g=$(echo "$line" | sed -n 's/.*generalizing_or_memorizing=\([gm]\).*/\1/p' | head -1)
  forced=$(echo "$line" | sed -n 's/.*FORCED_ENTROPY=\([a-zA-Z0-9_]*\).*/\1/p' | head -1)

  if [[ -n "$cycle_wsum" ]]; then
    delta=$(python3 -c "print(0 if '$cycle_wsum' == '' else float('$cycle_wsum') - float('$LAST_WSUM'))")
    if python3 -c "import sys; sys.exit(0 if float('$delta') >= $DELTA else 1)"; then
      CONSECUTIVE_NO_IMPROVEMENT=0
    else
      CONSECUTIVE_NO_IMPROVEMENT=$((CONSECUTIVE_NO_IMPROVEMENT + 1))
    fi
    [[ "$forced" == "true" ]] && FORCED_ENTROPY_APPLIED=$((FORCED_ENTROPY_APPLIED + 1))
    LAST_WSUM="$cycle_wsum"
    LAST_PSR="$cycle_psr"
    LAST_G="$cycle_g"
  fi
done <<< "$LAST_5"

# Success: SUCCESS_AFTER consecutive cycles where ALL
# multi-axis target conditions hold AND the overfit-
# reflections say "generalizing". The default
# --success-after is 2, configurable; --success-after 0
# disables the early-success stop.
#
# We grep the last 10 log lines and count consecutive
# cycles from the tail that satisfy the multi-axis target.
# A cycle's log line encodes "axes_met=true" if it
# satisfied every axis (pass_rate >= TARGET_PASSRATE,
# weighted_sum >= TARGET_WEIGHTED, integrity ok, freshness
# ok, hidden-unread ok). Older cycles (without the
# axes_met field) are treated as single-axis passes if
# pass_rate=1.0 + g — preserves backward compat.
SUCCESS_COUNT=$(tail -10 "$LOG_FILE" 2>/dev/null | python3 -c "
import sys, re
threshold_passrate = float('${TARGET_PASSRATE}')
threshold_wsum = float('${TARGET_WEIGHTED}')
consecutive = 0
for line in sys.stdin:
    line = line.strip()
    if not line or line.startswith('STOP:') or line.startswith('OVERRIDE:'):
        continue
    g_match = re.search(r'generalizing_or_memorizing=([gm])', line)
    if not g_match or g_match.group(1) != 'g':
        break
    pass_match = re.search(r'pass_rate=([0-9]+(?:\.[0-9]+)?)', line)
    wsum_match = re.search(r'weighted_sum=([0-9]+(?:\.[0-9]+)?)', line)
    if not pass_match or not wsum_match:
        break
    pass_ok = float(pass_match.group(1)) >= threshold_passrate
    wsum_ok = float(wsum_match.group(1)) >= threshold_wsum
    axes_match = re.search(r'axes_met=(true|false)', line)
    if axes_match:
        # New-format line: enforce multi-axis.
        if axes_match.group(1) == 'true':
            consecutive += 1
        else:
            break
    else:
        # Legacy line: single-axis pass.
        if pass_ok:
            consecutive += 1
        else:
            break
sys.stdout.write(str(consecutive))
sys.exit(0)
" 2>/dev/null || echo 0)
# Defensive: an empty substitution under set -euo pipefail can
# leak through. Force a numeric default.
[[ -z "$SUCCESS_COUNT" ]] && SUCCESS_COUNT=0
# Coerce to integer; bash's (( )) treats empty as 0 but the
# subsequent [[ -ge ]] comparison is stricter.
case "$SUCCESS_COUNT" in
  ''|*[!0-9]*) SUCCESS_COUNT=0 ;;
esac
echo "[cycle] SUCCESS_COUNT=$SUCCESS_COUNT (threshold $SUCCESS_AFTER, target pass_rate>=${TARGET_PASSRATE} weighted>=${TARGET_WEIGHTED})" >&2
if [[ "$SUCCESS_COUNT" -ge "$SUCCESS_AFTER" && "$SUCCESS_AFTER" -gt 0 ]]; then
  echo "{\"stop\": \"success\", \"reason\": \"multi-axis target met for $SUCCESS_AFTER consecutive cycles, all generalizing\"}"
  exit 3
fi

# Stall: max-stall consecutive stalls AND at least 1 forced entropy
if [[ "$CONSECUTIVE_NO_IMPROVEMENT" -ge "$MAX_STALL" && "$FORCED_ENTROPY_APPLIED" -ge 1 ]]; then
  echo '{"stop": "stall", "reason": "max-stall reached with forced entropy applied"}'
  exit 3
fi

# ----- forced-entropy decision -----

FORCED_ENTROPY="false"
if [[ "$CONSECUTIVE_NO_IMPROVEMENT" -ge 1 ]]; then
  # Was the last cycle forced? If not, force this one.
  LAST_FORCED=$(tail -1 "$LOG_FILE" 2>/dev/null | sed -n 's/.*FORCED_ENTROPY=\([a-zA-Z0-9_]*\).*/\1/p' | head -1)
  if [[ "$LAST_FORCED" != "true" ]]; then
    FORCED_ENTROPY="true"
    FORCED_ENTROPY_APPLIED=$((FORCED_ENTROPY_APPLIED + 1))
  fi
fi

# ----- form hypothesis -----

if [[ "$CYCLE" -eq 0 || "$CYCLE" -eq 1 ]]; then
  HYPOTHESIS="Baseline cycle: run the design set with no candidate skill installed. The expected outcome is pass_rate=0.0 — establishes the floor."
  EXPECTED_FAILURE="All 5 design tasks fail; the design-set-runner can't run without a candidate."
  G_OR_M="g"
else
  # Form hypothesis from the last cycle's outcome
  LAST_HYP=$(tail -1 "$LOG_FILE" | sed -n 's/.*hypothesis="\([^"]*\)".*/\1/p' | head -1 | sed 's/hypothesis="//;s/"$//')
  LAST_EF=$(tail -1 "$LOG_FILE" | sed -n 's/.*expected_failure="\([^"]*\)".*/\1/p' | head -1 | sed 's/expected_failure="//;s/"$//')
  LAST_G=$(tail -1 "$LOG_FILE" | sed -n 's/.*generalizing_or_memorizing=\([gm]\).*/\1/p' | head -1)
  LAST_WSUM=$(tail -1 "$LOG_FILE" | sed -n 's/.*weighted_sum=\([0-9.]*\).*/\1/p' | head -1)

  if [[ "$FORCED_ENTROPY" == "true" ]]; then
    HYPOTHESIS="Forced entropy: pick the OPPOSITE of the last change. Last change was: $LAST_HYP"
    EXPECTED_FAILURE="The opposite change might regress. That's OK — forced entropy trades short-term regression for escape from local maxima."
    G_OR_M="g"
  elif [[ "$LAST_G" == "m" ]]; then
    HYPOTHESIS="Last change was eval-shaped (memorizing). REMOVE an eval-shaped artifact. Last change was: $LAST_HYP"
    EXPECTED_FAILURE="Removing artifacts may regress pass_rate. That's the trade for generalization."
    G_OR_M="g"
  else
    HYPOTHESIS="Refine the candidate. Last change was: $LAST_HYP. Build on what worked."
    EXPECTED_FAILURE="Refinement may overfit. Watch the g/m flag."
    G_OR_M="g"
  fi
fi

# ----- write cycle input -----

CYCLE_DIR="$PROJECT_ROOT/logs/cycle-$CYCLE"
mkdir -p "$CYCLE_DIR"
CYCLE_INPUT="$CYCLE_DIR/input.json"

LOOP_START_TS="${LOOP_START_TS:-}"
[[ -z "$LOOP_START_TS" ]] && LOOP_START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$CYCLE_INPUT" <<EOF
{
  "cycle": $CYCLE,
  "hypothesis": "$HYPOTHESIS",
  "expected_failure": "$EXPECTED_FAILURE",
  "generalizing_or_memorizing": "$G_OR_M",
  "prior_pass_rate": $PRIOR_PSR,
  "prior_weighted_sum": $PRIOR_WSUM,
  "prior_gates_passed": $( [[ "$PRIOR_GATES" == "True" ]] && echo "true" || echo "false" ),
  "forced_entropy": $( [[ "$FORCED_ENTROPY" == "true" ]] && echo "true" || echo "false" ),
  "consecutive_no_improvement": $CONSECUTIVE_NO_IMPROVEMENT,
  "forced_entropy_applied_count": $FORCED_ENTROPY_APPLIED,
  "wrapper_timeout_s": $WRAPPER_TIMEOUT,
  "loop_start_ts": "$LOOP_START_TS",
  "cycle_start_ts": "$NOW_TS",
  "runtime": "$RUNTIME",
  "artifact_name": "$ARTIFACT_NAME",
  "project_root": "$PROJECT_ROOT"
}
EOF

# ----- build the prompt for the inner agent -----

PROMPT_FILE="$CYCLE_DIR/prompt.txt"
cat > "$PROMPT_FILE" <<EOF
You are cycle $CYCLE of the loss-function-driven loop.

# Hypothesis
$HYPOTHESIS

# Expected failure mode
$EXPECTED_FAILURE

# Generalizing or memorizing?
$G_OR_M

# Forced entropy?
$FORCED_ENTROPY

# Your job
Read $PROJECT_ROOT/GOAL.md and $PROJECT_ROOT/AGENTS.md. Write a
candidate artifact at $PROJECT_ROOT/skills/$ARTIFACT_NAME/.
The artifact should help the inner agent (you) complete the
5 design tasks listed in GOAL.md.

# Hard rules
- DO NOT read $PROJECT_ROOT/verifiers/private/ or
  $PROJECT_ROOT/test-tasks/held-out/
- DO NOT modify $PROJECT_ROOT/verifiers/private/ or
  $PROJECT_ROOT/test-tasks/held-out/ (held-out target)
- The rest of the harness (design tasks, instruments,
  AGENTS.md, run-design-set.sh, the wrapper) is fair
  game — fix it when it's wrong, log the patch in
  $LOG_FILE
- Your only $RUNTIME invocation is via $WRAPPER

# Overfit reflection
Before you do anything, append to $LOG_FILE:
  cycle $CYCLE: hypothesis="$HYPOTHESIS", expected_failure="$EXPECTED_FAILURE", generalizing_or_memorizing=$G_OR_M, pass_rate=$PRIOR_PSR

If this cycle is a forced entropy cycle (FORCED_ENTROPY=true
above), your change must be the OPPOSITE of the last cycle's
change. Read the last 5 entries of $LOG_FILE to see what the
last cycles did, then pick the opposite.
EOF

# ----- run the cycle (unless --dry-run) -----

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN: would have invoked $WRAPPER and $DESIGN_SET"
  echo "Cycle input: $CYCLE_INPUT"
  echo "Prompt: $PROMPT_FILE"
  exit 0
fi

# Invoke the wrapper
echo "[cycle $CYCLE] invoking wrapper..." >&2
if "$WRAPPER" "$(cat $PROMPT_FILE)" \
     --cwd "$PROJECT_ROOT" --timeout "$WRAPPER_TIMEOUT" --cycle "cycle-$CYCLE" \
     > "$CYCLE_DIR/cycle-summary.json" 2>"$CYCLE_DIR/wrapper.stderr"; then
  echo "[cycle $CYCLE] wrapper exited 0" >&2
else
  echo "[cycle $CYCLE] wrapper exited $? — continuing anyway" >&2
fi

# Install the candidate (the agent wrote to skills/<artifact>/;
# the inner agent's tools are responsible for putting it there)
SKILL_SRC="$PROJECT_ROOT/skills/$ARTIFACT_NAME"
if [[ -d "$SKILL_SRC" ]]; then
  if [[ -x "$SKILLS_DIR_INSTRUMENT" ]]; then
    AGENT_SKILLS_DIR=$("$SKILLS_DIR_INSTRUMENT")
    mkdir -p "$AGENT_SKILLS_DIR/$ARTIFACT_NAME"
    cp -r "$SKILL_SRC"/* "$AGENT_SKILLS_DIR/$ARTIFACT_NAME/" 2>/dev/null || true
    echo "[cycle $CYCLE] installed candidate at $AGENT_SKILLS_DIR/$ARTIFACT_NAME" >&2
  fi
fi

# Run the design set
echo "[cycle $CYCLE] running design set..." >&2
CYCLE_START_TS=$(date +%s)
PROJECT_DIR="$PROJECT_ROOT" "$DESIGN_SET" > "$CYCLE_DIR/design-set-score.json" 2>"$CYCLE_DIR/design-set.stderr" || true
CYCLE_END_TS=$(date +%s)
CYCLE_WALL_SEC=$((CYCLE_END_TS - CYCLE_START_TS))

# Record per-cycle wall-clock for the speed/anti-overfit signal.
PER_CYCLE_CLOCK="$PROJECT_ROOT/verifiers/instruments/per-cycle-wall-clock.sh"
if [[ -x "$PER_CYCLE_CLOCK" ]]; then
  "$PER_CYCLE_CLOCK" --record "$CYCLE_WALL_SEC" "cycle-$CYCLE" >/dev/null 2>&1 || true
fi

# Score the cycle
echo "[cycle $CYCLE] scoring..." >&2
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/score-cycle.py" "$CYCLE_DIR" > "$CYCLE_DIR/sub-losses.json" 2>"$CYCLE_DIR/score.stderr" || {
  echo "error: scoring failed" >&2
  cat "$CYCLE_DIR/score.stderr" >&2
  exit 1
}

# Read scores
PASS_RATE=$(python3 -c "import json; d=json.load(open('$CYCLE_DIR/design-set-score.json')); print(d.get('pass_rate', 0.0))")
WSUM=$(python3 -c "import json; d=json.load(open('$CYCLE_DIR/sub-losses.json')); print(d.get('weighted_normalized', 0.0))")
GATES=$(python3 -c "import json; d=json.load(open('$CYCLE_DIR/sub-losses.json')); print(d.get('gates_passed', False))")

# ----- post-cycle anti-cheat checks -----
#
# Run the two loop-side instruments: test-freshness
# (design-set SHA unchanged) and hidden-unread
# (transcript doesn't reference held-out / private).
# These are recorded on the cycle dir and contribute
# to the multi-axis `axes_met` field.
FRESHNESS_OK="true"
HIDDEN_OK="true"
FRESHNESS_INSTRUMENT="$PROJECT_ROOT/verifiers/instruments/test-freshness.sh"
HIDDEN_INSTRUMENT="$PROJECT_ROOT/verifiers/instruments/hidden-unread.sh"
if [[ -x "$FRESHNESS_INSTRUMENT" ]]; then
  if "$FRESHNESS_INSTRUMENT" > "$CYCLE_DIR/test-freshness.txt" 2>&1; then
    echo "ok    test-freshness" > "$CYCLE_DIR/test-freshness.txt"
  else
    FRESHNESS_OK="false"
    echo "FAIL  test-freshness" >> "$CYCLE_DIR/test-freshness.txt"
  fi
fi
if [[ -x "$HIDDEN_INSTRUMENT" ]]; then
  # Pass an explicit list of agent-output files (NOT the loop's own
  # writes like cycle-summary.json, input.json, prompt.txt, which
  # echo the loop's prompt and would trigger false positives).
  HIDDEN_TARGETS=""
  for f in "$CYCLE_DIR/wrapper.stderr" \
           "$CYCLE_DIR/transcript.txt" \
           "$CYCLE_DIR/response.txt" \
           "$CYCLE_DIR/agent_output.json" \
           "$CYCLE_DIR/agent_output.txt" \
           "$CYCLE_DIR/agent.ndjson"; do
    [[ -f "$f" ]] && HIDDEN_TARGETS="$HIDDEN_TARGETS $f"
  done
  # Also scan .iterations/<cycle>/ if the wrapper wrote there.
  if [[ -d "$PROJECT_ROOT/.iterations/cycle-$CYCLE" ]]; then
    for f in "$PROJECT_ROOT/.iterations/cycle-$CYCLE"/*; do
      [[ -f "$f" ]] && HIDDEN_TARGETS="$HIDDEN_TARGETS $f"
    done
  fi
  HIDDEN_TARGETS="${HIDDEN_TARGETS# }"
  if [[ -n "$HIDDEN_TARGETS" ]]; then
    if "$HIDDEN_INSTRUMENT" $HIDDEN_TARGETS > "$CYCLE_DIR/hidden-unread.txt" 2>&1; then
      echo "ok    hidden-unread" > "$CYCLE_DIR/hidden-unread.txt"
    else
      HIDDEN_OK="false"
      echo "FAIL  hidden-unread" >> "$CYCLE_DIR/hidden-unread.txt"
    fi
  else
    # No agent output to scan; vacuously clean
    echo "ok    hidden-unread (no agent output to scan)" > "$CYCLE_DIR/hidden-unread.txt"
  fi
fi

# Record the freshness baseline on the first cycle (so subsequent
# cycles can detect tampering). Idempotent — the instrument
# itself is a pass-through if a baseline already exists.
if [[ "$CYCLE" -eq 0 && -x "$FRESHNESS_INSTRUMENT" ]]; then
  "$FRESHNESS_INSTRUMENT" --record >/dev/null 2>&1 || true
fi

# ----- smallness measurement (real, non-stub) -----
#
# smallness.sh parses MAX_LOC_PER_CYCLE from GOAL.md and returns
# 1.0 if LOC <= budget, decaying to 0.0 above. We capture the
# measurement and add it to the cycle result. If smallness.sh
# isn't executable, we treat smallness as vacuously satisfied
# (multi-axis stop condition ignores axes that aren't in GOAL.md).
SMALLNESS="1.0"
SMALLNESS_INSTRUMENT="$PROJECT_ROOT/verifiers/instruments/smallness.sh"
if [[ -x "$SMALLNESS_INSTRUMENT" ]]; then
  SMALLNESS_RAW=$("$SMALLNESS_INSTRUMENT" 2>/dev/null || echo "0.0")
  # Validate it's a float
  if python3 -c "import sys; float('$SMALLNESS_RAW')" 2>/dev/null; then
    SMALLNESS="$SMALLNESS_RAW"
  fi
fi

# Compute multi-axis satisfaction.
AXES_MET=$(python3 -c "
threshold_passrate = float('${TARGET_PASSRATE}')
threshold_wsum = float('${TARGET_WEIGHTED}')
require_integrity = '${TARGET_REQUIRE_INTEGRITY}' == 'true'
require_freshness = '${TARGET_REQUIRE_FRESHNESS}' == 'true'
require_hidden = '${TARGET_REQUIRE_HIDDEN}' == 'true'
smallness = float('${SMALLNESS}')
pass_rate = float('${PASS_RATE}')
wsum = float('${WSUM}')
gates = '${GATES}' == 'True'
freshness = '${FRESHNESS_OK}' == 'true'
hidden = '${HIDDEN_OK}' == 'true'
# integrity was run pre-cycle (it would have stopped the script if it failed),
# so the pre-check itself counts as the integrity axis being met.
ok = (
    pass_rate >= threshold_passrate
    and wsum >= threshold_wsum
    and (gates or not require_integrity)
    and (freshness or not require_freshness)
    and (hidden or not require_hidden)
)
print('true' if ok else 'false')
")

# Append to iteration log
LOG_LINE="cycle $CYCLE: hypothesis=\"$HYPOTHESIS\", expected_failure=\"$EXPECTED_FAILURE\", generalizing_or_memorizing=$G_OR_M, pass_rate=$PASS_RATE, weighted_sum=$WSUM, gates=$GATES, axes_met=$AXES_MET, wall_clock_s=$CYCLE_WALL_SEC, smallness=$SMALLNESS"
[[ "$FORCED_ENTROPY" == "true" ]] && LOG_LINE="$LOG_LINE, FORCED_ENTROPY=true"
echo "$LOG_LINE" >> "$LOG_FILE"

# Update best-cycle if improved
PRIOR_WSUM_NUM=$(python3 -c "print(float('$PRIOR_WSUM'))" 2>/dev/null || echo "0.0")
WSUM_NUM=$(python3 -c "print(float('$WSUM'))" 2>/dev/null || echo "0.0")
if python3 -c "import sys; sys.exit(0 if $WSUM_NUM > $PRIOR_WSUM_NUM else 1)"; then
  cp "$CYCLE_DIR/sub-losses.json" "$BEST_FILE"
  echo "[cycle $CYCLE] new best: weighted_sum=$WSUM, pass_rate=$PASS_RATE, axes_met=$AXES_MET" >&2
fi

# Emit cycle result
cat <<EOF
{
  "cycle": $CYCLE,
  "pass_rate": $PASS_RATE,
  "weighted_sum": $WSUM,
  "gates_passed": $GATES,
  "axes_met": $AXES_MET,
  "freshness_ok": $FRESHNESS_OK,
  "hidden_unread_ok": $HIDDEN_OK,
  "wall_clock_s": $CYCLE_WALL_SEC,
  "smallness": $SMALLNESS,
  "forced_entropy": $FORCED_ENTROPY,
  "improved": $( python3 -c "import sys; print('true' if $WSUM_NUM > $PRIOR_WSUM_NUM else 'false')" ),
  "cycle_dir": "$CYCLE_DIR",
  "best_file": "$BEST_FILE"
}
EOF
