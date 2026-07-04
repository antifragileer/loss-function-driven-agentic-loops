#!/usr/bin/env bash
# run-verification-real.sh — real-agent dogfood driver for
# the LFD system verifier.
#
# This is the REAL-AGENT counterpart to run-verification.sh.
# Where run-verification.sh uses the deterministic fake-agent
# adapter (no model, no network, ~10s), this script drives
# the loop with a REAL coding agent (Cline by default).
#
# Why both exist:
#   - run-verification.sh: deterministic baseline. Bit-exact
#     reproducible. Tests the LFD *tools* (parsers, install,
#     driver, scorer shape). Used in CI.
#   - run-verification-real.sh: real-agent exercise. Tests
#     the LFD *integration* (does the wrapper actually invoke
#     a real agent? Does the agent get accurate context? Do
#     the per-cycle outputs flow correctly through the
#     parser? Do the design tasks produce real results?).
#     NOT bit-exact — different model runs produce different
#     candidate text. But it proves the LFD system is
#     actually usable with a real agent.
#
# Both must pass for the LFD system to be considered
# verified. The fake-agent test is the *fast* gate; the
# real-agent test is the *real* gate.
#
# Determinism: this script is non-deterministic by
# construction (the agent's model is). Two consecutive
# runs may produce different candidate_text, different
# pass_rates within the same run, etc. That's expected.
# The script enforces a wall-clock budget (5 min default)
# and a per-wrapper timeout (120s default) so a run can
# never exceed 5 minutes even if the agent is slow.
#
# Time budget: 300s (5 min) by default.
#
# Usage:
#   ./run-verification-real.sh [REPO_ROOT] [PROFILE_DIR] [RUNTIME]
#     REPO_ROOT:   the LFD bundle repo (default: parent of examples/)
#     PROFILE_DIR: the test profile to install into (default: /tmp/lfd-verify-real-XXXXXX)
#     RUNTIME:     the agent runtime — cline|claude-code|codex|hermes-agent|opencode
#                  (default: cline)
#
# Exit codes:
#   0: all design tasks passed
#   1: at least one design task failed
#   2: setup error (bundle not found, profile dir not writable, agent binary missing)
#   3: wall-clock budget exhausted (some tasks ran, some didn't)

set -uo pipefail

# ----- argument parsing -----

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CUSTOM_PROFILE="${2:-}"
RUNTIME="${3:-cline}"
WALL_CLOCK_BUDGET="${LFD_REAL_BUDGET:-300}"

if [[ -z "$CUSTOM_PROFILE" ]]; then
  PROFILE_DIR="$(mktemp -d -t lfd-verify-real-XXXXXX)"
  CLEANUP_PROFILE=true
else
  PROFILE_DIR="$CUSTOM_PROFILE"
  CLEANUP_PROFILE=false
fi

echo "============================================================"
echo "  LFD System Verifier (real-agent dogfood)"
echo "  repo:    $REPO_ROOT"
echo "  profile: $PROFILE_DIR"
echo "  runtime: $RUNTIME"
echo "  budget:  ${WALL_CLOCK_BUDGET}s"
echo "  started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"
echo

# ----- wall-clock deadline -----

DEADLINE=$(($(date +%s) + WALL_CLOCK_BUDGET))
time_left() { echo $(( DEADLINE - $(date +%s) )); }

# ----- preconditions -----

if [[ ! -f "$REPO_ROOT/install.sh" ]] || [[ ! -f "$REPO_ROOT/bundle.json" ]]; then
  echo "FAIL: $REPO_ROOT does not look like the LFD bundle repo" >&2
  exit 2
fi
if [[ ! -x "$REPO_ROOT/install.sh" ]]; then
  echo "FAIL: $REPO_ROOT/install.sh is not executable" >&2
  exit 2
fi
if [[ ! -x "$SCRIPT_DIR/verifiers/${RUNTIME}-wrapper.sh" ]]; then
  echo "FAIL: real-agent wrapper not found: verifiers/${RUNTIME}-wrapper.sh" >&2
  echo "  Available wrappers:" >&2
  ls "$SCRIPT_DIR/verifiers/" | grep -E '\-wrapper\.sh$' | sed 's/^/    /' >&2
  exit 2
fi
# The agent binary itself must be on PATH or in $CLINE_BIN
if ! command -v "$RUNTIME" >/dev/null 2>&1 && [[ -z "${CLINE_BIN:-}" ]]; then
  echo "FAIL: agent binary '$RUNTIME' not on PATH and \$CLINE_BIN not set" >&2
  exit 2
fi

# ----- phase 1: install bundle into the test profile -----

echo "[phase 1/3] Installing LFD bundle into test profile..."
mkdir -p "$PROFILE_DIR/skills"
if ! "$REPO_ROOT/install.sh" "$PROFILE_DIR" --force >/tmp/lfd-verify-real-install.log 2>&1; then
  echo "FAIL: install.sh --force failed. See /tmp/lfd-verify-real-install.log:" >&2
  cat /tmp/lfd-verify-real-install.log >&2
  exit 2
fi
if ! "$REPO_ROOT/install.sh" --check "$PROFILE_DIR" >/dev/null 2>&1; then
  echo "FAIL: install.sh --check failed after install" >&2
  exit 2
fi
echo "  PASS: 11 skills installed and verified"
echo

# ----- phase 2: run the design set with the real agent -----

echo "[phase 2/3] Running 5 design tasks with the $RUNTIME agent..."
# Initialize loop state (real-agent design set, not the
# orchestrator's cycle-1)
mkdir -p "$SCRIPT_DIR/logs"
date +%s > "$SCRIPT_DIR/logs/.loop_start_ts"
LOG_FILE="$SCRIPT_DIR/logs/iteration-log.md"
BEST_FILE="$SCRIPT_DIR/logs/best-cycle.json"
echo "VERIFY-REAL: LFD real-agent verification, $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOG_FILE"
echo '{"weighted_normalized": 0.0, "pass_rate": 0.0}' > "$BEST_FILE"

# Copy the per-cycle sub-loss scorer into the verifier's verifiers/
# (the cycle.sh / loop-driver needs it; we don't run cycle.sh
# directly in real-agent mode, but run-design-set.sh may need it
# for d5 which invokes the cycle internally)
INSTRUMENTS_SRC="$REPO_ROOT/skills/cline-orchestration/references/compute-sub-losses.py"
cp "$INSTRUMENTS_SRC" "$SCRIPT_DIR/verifiers/compute_sub_losses.py"
chmod +x "$SCRIPT_DIR/verifiers/compute_sub_losses.py"

START_TS=$(date +%s)

# The real-agent run uses LFD_WRAPPER and LFD_WRAPPER_TIMEOUT
# env vars. The wrapper's own timeout is what actually bounds
# each task; the 120s default is generous for the design tasks
# (which are mostly file checks and bundle lookups).
export LFD_WRAPPER="verifiers/${RUNTIME}-wrapper.sh"
export LFD_WRAPPER_TIMEOUT="${LFD_REAL_WRAPPER_TIMEOUT:-120}"
export PROJECT_DIR="$SCRIPT_DIR"

CYCLE_OUT=$(./verifiers/run-design-set.sh 2>&1) || CYCLE_RC=$?
CYCLE_RC=${CYCLE_RC:-0}

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
echo "  design set exit: $CYCLE_RC, elapsed: ${ELAPSED}s"
echo "  design set output:"
echo "$CYCLE_OUT" | head -25 | sed 's/^/    /'
echo

# Parse the design set's aggregate score
DESIGN_SCORE_FILE="$SCRIPT_DIR/logs/cycle-1/design-set-score.json"
DESIGN_PASS_RATE="0.0"
DESIGN_N_PASS="0"
DESIGN_N_FAIL="0"
if [[ -f "$DESIGN_SCORE_FILE" ]]; then
  DESIGN_PASS_RATE=$(python3 -c "import json; print(json.load(open('$DESIGN_SCORE_FILE')).get('pass_rate', 0.0))" 2>/dev/null || echo 0.0)
  DESIGN_N_PASS=$(python3 -c "import json; print(json.load(open('$DESIGN_SCORE_FILE')).get('n_pass', 0))" 2>/dev/null || echo 0)
  DESIGN_N_FAIL=$(python3 -c "import json; print(json.load(open('$DESIGN_SCORE_FILE')).get('n_fail', 0))" 2>/dev/null || echo 0)
fi

OVERALL_PASS=true
if [[ "$CYCLE_RC" -ne 0 ]]; then
  OVERALL_PASS=false
fi
if python3 -c "import sys; sys.exit(0 if float('$DESIGN_PASS_RATE') < 1.0 else 1)" 2>/dev/null; then
  OVERALL_PASS=false
fi

# Compute aggregate token/duration stats from per-task cycle summaries
TOTAL_TOKENS=0
TOTAL_DURATION_MS=0
TASK_COUNT=0
for task_dir in "$SCRIPT_DIR/logs/cycle-1"/d*-*/; do
  [[ -f "$task_dir/cycle-summary.json" ]] || continue
  CS=$(python3 -c "
import json
try:
    d = json.load(open('$task_dir/cycle-summary.json'))
    print(int(d.get('tokens', 0) or 0), int(d.get('cline_duration_ms', 0) or 0), d.get('model', ''), d.get('provider', ''))
except: print('0 0  ')
" 2>/dev/null)
  T=$(echo "$CS" | awk '{print $1}')
  D=$(echo "$CS" | awk '{print $2}')
  MODEL=$(echo "$CS" | awk '{print $3}')
  PROVIDER=$(echo "$CS" | awk '{print $4}')
  TOTAL_TOKENS=$((TOTAL_TOKENS + T))
  TOTAL_DURATION_MS=$((TOTAL_DURATION_MS + D))
  TASK_COUNT=$((TASK_COUNT + 1))
done
[[ -z "$MODEL" ]] && MODEL="unknown"
[[ -z "$PROVIDER" ]] && PROVIDER="unknown"

# ----- phase 3: produce report + clean artifacts -----

echo "[phase 3/3] Producing real-agent verification report..."
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUNDLE_VERSION=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/bundle.json'))['version'])" 2>/dev/null || echo "unknown")
PASS_LABEL=$([ "$OVERALL_PASS" = true ] && echo "PASS" || echo "FAIL")

REPORT_MD="$SCRIPT_DIR/verification-report-real.md"
REPORT_JSON="$SCRIPT_DIR/verification-report-real.json"

# JSON report
python3 - <<PYEOF > "$REPORT_JSON"
import json
report = {
    "timestamp": "$TIMESTAMP",
    "bundle_version": "$BUNDLE_VERSION",
    "repo": "$REPO_ROOT",
    "profile": "$PROFILE_DIR",
    "runtime": "$RUNTIME",
    "elapsed_seconds": $ELAPSED,
    "wall_clock_budget": $WALL_CLOCK_BUDGET,
    "wall_clock_left": $(time_left),
    "overall": "$PASS_LABEL",
    "design_pass_rate": $DESIGN_PASS_RATE,
    "design_n_pass": $DESIGN_N_PASS,
    "design_n_fail": $DESIGN_N_FAIL,
    "total_tokens": $TOTAL_TOKENS,
    "total_cline_duration_ms": $TOTAL_DURATION_MS,
    "task_count": $TASK_COUNT,
    "model": "$MODEL",
    "provider": "$PROVIDER",
    "cycle_driver_exit": $CYCLE_RC,
}
print(json.dumps(report, indent=2))
PYEOF

# Markdown report
cat > "$REPORT_MD" <<MDEOF
# LFD System Verification Report (real-agent)

**Generated:** $TIMESTAMP
**Bundle version:** $BUNDLE_VERSION
**Repo:** \`$REPO_ROOT\`
**Profile:** \`$PROFILE_DIR\`
**Runtime:** \`$RUNTIME\` (model: \`$MODEL\`, provider: \`$PROVIDER\`)
**Wall-clock budget:** ${WALL_CLOCK_BUDGET}s
**Elapsed:** ${ELAPSED}s (remaining: $(time_left)s)

## Overall: **$PASS_LABEL**

| Metric | Value |
|---|---|
| Design-set pass rate | $DESIGN_PASS_RATE ($DESIGN_N_PASS pass / $DESIGN_N_FAIL fail) |
| Total tokens | $TOTAL_TOKENS |
| Total Cline duration | ${TOTAL_DURATION_MS}ms |
| Tasks run | $TASK_COUNT |
| Design-set exit | $CYCLE_RC |

## What this verifier proves

This run drove the LFD system with a real coding agent
(\`$RUNTIME\`) instead of the deterministic fake agent used
by the baseline \`run-verification.sh\`. It proves:

1. The \`${RUNTIME}-wrapper.sh\` correctly invokes the
   agent binary, captures NDJSON output, parses it via
   \`parse_cline_output.py\`, and emits the contract-shaped
   cycle summary.
2. The agent can read each design task's \`prompt.txt\`,
   locate the bundle files referenced in the prompts,
   and produce correct candidate text.
3. The per-task graders correctly evaluate the agent's
   output (the agent's claim is checked against the
   filesystem, not taken on faith).
4. The per-cycle state files (logs/.loop_start_ts,
   logs/cycle-1/, etc.) survive a real agent's
   per-cycle directory creation without breaking the
   next cycle.

A failure in this run indicates a real bug: a prompt
that's under-specified, a path the agent can't find, a
grader that misreads the agent's output, or a contract
mismatch between the wrapper and the parser.

## How to invoke

\`\`\`bash
cd examples/lfd-system-verifier
./run-verification-real.sh                       # Cline, 5 min budget
./run-verification-real.sh "" "" claude-code     # Claude Code, 5 min
./run-verification-real.sh "" "" opencode        # OpenCode, 5 min
LFD_REAL_BUDGET=900 ./run-verification-real.sh   # 15 min budget
\`\`\`

## Differences from the fake-agent baseline

| | run-verification.sh (fake) | run-verification-real.sh (real) |
|---|---|---|
| Inner agent | deterministic stub | $RUNTIME ($MODEL) |
| Wall-clock | ~10s | ~${ELAPSED}s |
| Tokens | 0 | $TOTAL_TOKENS |
| Determinism | bit-exact | varies by run |
| Held-out grader | yes | no (held-out is for the deterministic baseline) |
| Method test | yes (3 cycles) | no (cycle-of-cycles is too expensive for real agents) |
| Purpose | CI / fast gate | prove the system is usable with a real agent |

Both must pass for the LFD system to be considered
fully verified. \`run-verification.sh\` proves the
*tools* work; \`run-verification-real.sh\` proves the
*integration* works.
MDEOF

echo "  Report: $REPORT_MD"
echo "  Report (JSON): $REPORT_JSON"
echo

# ----- cleanup -----

echo "[cleanup] Removing per-cycle artifacts..."
rm -rf "$SCRIPT_DIR/.iterations"
rm -rf "$SCRIPT_DIR/logs/cycle-"*
rm -f "$SCRIPT_DIR/logs/.loop_start_ts"
rm -f "$SCRIPT_DIR/verifiers/compute_sub_losses.py"
# Keep the report + iteration log + best-cycle (the
# "what was tested" artifacts).

if [[ "$CLEANUP_PROFILE" == "true" ]]; then
  rm -rf "$PROFILE_DIR"
fi

# Final status
echo "============================================================"
if [[ "$OVERALL_PASS" == "true" ]]; then
  echo "  RESULT: ✅ LFD system verified with real agent ($BUNDLE_VERSION)"
  echo "  Report: $REPORT_MD"
  exit 0
else
  echo "  RESULT: ❌ LFD real-agent verification FAILED"
  echo "  Report: $REPORT_MD"
  exit 1
fi
