#!/usr/bin/env bash
# run-verification.sh — orchestrator for the LFD system dogfood verifier.
#
# The LFD system verifies itself: this script scaffolds a complete
# loss-function-driven loop against the deterministic fake-agent
# adapter, runs 1 cycle with 5 design tasks + 5 held-out tasks,
# produces a verification report, and cleans all per-cycle
# artifacts.
#
# Determinism: the fake agent has no model and no network. The
# output is bit-exact reproducible. Two consecutive runs of this
# script produce byte-identical verification-report.md and
# verification-report.json (modulo the run timestamp).
#
# Time budget: the verifier's wall-clock budget is whatever the
# project sets in GOAL.md. There is no hard 5-minute cap from the
# verifier itself; we report wall-clock in the verification report.
#
# Usage:
#   ./run-verification.sh [REPO_ROOT] [PROFILE_DIR]
#     REPO_ROOT:   the LFD bundle repo (default: parent of examples/)
#     PROFILE_DIR: the test profile to install into (default: /tmp/lfd-verify-XXXXXX)
#
# Exit codes:
#   0: all design + held-out tasks passed
#   1: at least one task failed
#   2: setup error (bundle not found, profile dir not writable)
#   3: loop driver error

set -uo pipefail

# ----- argument parsing -----

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CUSTOM_PROFILE="${2:-}"

# Use a system-temp profile by default (cleaned at end).
if [[ -z "$CUSTOM_PROFILE" ]]; then
  PROFILE_DIR="$(mktemp -d -t lfd-verify-profile-XXXXXX)"
  CLEANUP_PROFILE=true
else
  PROFILE_DIR="$CUSTOM_PROFILE"
  CLEANUP_PROFILE=false
fi

echo "============================================================"
echo "  LFD System Verifier (dogfood)"
echo "  repo:   $REPO_ROOT"
echo "  profile: $PROFILE_DIR"
echo "  started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"
echo

# ----- preconditions -----

if [[ ! -f "$REPO_ROOT/install.sh" ]] || [[ ! -f "$REPO_ROOT/bundle.json" ]]; then
  echo "FAIL: $REPO_ROOT does not look like the LFD bundle repo" >&2
  echo "  (expected: install.sh and bundle.json in the root)" >&2
  exit 2
fi

if [[ ! -x "$REPO_ROOT/install.sh" ]]; then
  echo "FAIL: $REPO_ROOT/install.sh is not executable" >&2
  exit 2
fi

# ----- phase 1: install bundle into the test profile -----

echo "[phase 1/5] Installing LFD bundle into test profile..."
mkdir -p "$PROFILE_DIR/skills"
if ! "$REPO_ROOT/install.sh" "$PROFILE_DIR" --force >/tmp/lfd-verify-install.log 2>&1; then
  echo "FAIL: install.sh --force failed. See /tmp/lfd-verify-install.log:" >&2
  cat /tmp/lfd-verify-install.log >&2
  exit 2
fi

# Verify install
if ! "$REPO_ROOT/install.sh" --check "$PROFILE_DIR" >/dev/null 2>&1; then
  echo "FAIL: install.sh --check failed after install" >&2
  exit 2
fi
echo "  PASS: 11-12 skills installed and verified"
echo

# ----- phase 2: install the loop driver into the verifier-project -----

echo "[phase 2/5] Setting up verifier-project structure..."
LOOP_DRIVER_SRC="$REPO_ROOT/skills/loop-driver/scripts"
INSTRUMENTS_SRC="$REPO_ROOT/skills/cline-orchestration/references/compute-sub-losses.py"
if [[ ! -d "$LOOP_DRIVER_SRC" ]] || [[ ! -f "$INSTRUMENTS_SRC" ]]; then
  echo "FAIL: loop driver or sub-loss scorer not found in repo" >&2
  exit 2
fi

# Copy the per-cycle sub-loss scorer into the verifier's verifiers/
cp "$INSTRUMENTS_SRC" "$SCRIPT_DIR/verifiers/compute_sub_losses.py"
chmod +x "$SCRIPT_DIR/verifiers/compute_sub_losses.py"

# Symlink the loop driver so the verifier can invoke it
if [[ ! -e "$SCRIPT_DIR/loop-driver" ]]; then
  ln -s "$REPO_ROOT/skills/loop-driver" "$SCRIPT_DIR/loop-driver"
fi

# Create the .iterations dir for the loop
mkdir -p "$SCRIPT_DIR/.iterations"

# Remove any stale state from previous runs
rm -f "$SCRIPT_DIR/logs/.loop_start_ts" "$SCRIPT_DIR/logs/tokens_used.txt" "$SCRIPT_DIR/logs/tokens_last_cycle.txt"

# Initialize the iteration log
LOG_FILE="$SCRIPT_DIR/logs/iteration-log.md"
BEST_FILE="$SCRIPT_DIR/logs/best-cycle.json"
LOOP_START_FILE="$SCRIPT_DIR/logs/.loop_start_ts"
echo "VERIFY: LFD system verification, $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOG_FILE"
echo '{"weighted_normalized": 0.0, "pass_rate": 0.0}' > "$BEST_FILE"
# Reset the loop start timestamp so time-remaining.sh starts fresh
date +%s > "$LOOP_START_FILE"
echo "  PASS: verifier-project structure ready"
echo

# ----- phase 3: run the loss-function-driven loop for 1 cycle -----

echo "[phase 3/5] Running 1 cycle of the loss-function-driven loop..."
START_TS=$(date +%s)

# Run cycle.sh from the loop-driver (via the symlink)
CYCLE_SH="$SCRIPT_DIR/loop-driver/scripts/cycle.sh"
if [[ ! -x "$CYCLE_SH" ]]; then
  echo "FAIL: cycle.sh not found or not executable at $CYCLE_SH" >&2
  exit 2
fi

# Run one cycle. The agent (fake) writes a stub candidate skill.
# The cycle driver runs the design set, scores, and updates
# the iteration log.
CYCLE_OUT=$("$CYCLE_SH" \
  --project-root "$SCRIPT_DIR" \
  --cycle 1 \
  --delta 0.0 \
  --max-stall 100 \
  --wrapper-timeout 30 \
  --runtime fake \
  --artifact-name lfd-system-driver \
  2>&1) || CYCLE_RC=$?
CYCLE_RC=${CYCLE_RC:-0}
END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
echo "  cycle.sh exit: $CYCLE_RC, elapsed: ${ELAPSED}s"
echo "  cycle output: $CYCLE_OUT" | head -10

# The verifier runs 1 cycle then exits. The cycle's rc is
# informational; the real pass/fail is from the per-task
# graders + the held-out grader.

# ----- snapshot phase 3 outputs (BEFORE phase 3.5 wipes them) -----
#
# Phase 3.5 (the method test) runs cycle.sh 3 times. Each
# cycle.sh invocation overwrites logs/cycle-1/, etc., and
# the d6 grader cleans its cycle dirs at the end. Without
# this snapshot, phase 5 would read stale or missing data.
#
# Important: the snapshot filenames use a distinct prefix
# so they're not clobbered by anything else.

DESIGN_SNAPSHOT="$SCRIPT_DIR/logs/design-set-score.snapshot.json"
SUB_LOSSES_SNAPSHOT="$SCRIPT_DIR/logs/sub-losses.snapshot.json"
if [[ -f "$SCRIPT_DIR/logs/cycle-1/design-set-score.json" ]]; then
  cp "$SCRIPT_DIR/logs/cycle-1/design-set-score.json" "$DESIGN_SNAPSHOT"
fi
if [[ -f "$SCRIPT_DIR/logs/cycle-1/sub-losses.json" ]]; then
  cp "$SCRIPT_DIR/logs/cycle-1/sub-losses.json" "$SUB_LOSSES_SNAPSHOT"
fi

echo

# ----- phase 3.5: method test (3 cycles with fake-method wrapper) -----

# The method test exercises the LFD *method* (candidate → score →
# improvement → forced-entropy), not just the tools. It runs the
# loop 3 cycles using the fake-method wrapper (which emits
# different candidates per cycle to simulate an agent's
# improvement), and asserts that the loop's improvement-tracking
# machinery actually works (best-cycle updated, iteration log
# has 3 entries, cycle 3's log line includes FORCED_ENTROPY=true).
#
# This is a separate phase from phase 3 because:
#   - The method test runs 3 cycles (not 1), so it can't be
#     a single design task (which would recurse infinitely).
#   - The method test's "deliverable" is the iteration log +
#     best-cycle.json + per-cycle sub-losses.json, not a
#     single score.
#   - The method test must run BEFORE the held-out grader
#     (because the held-out grader wipes logs/cycle-*/).

echo "[phase 3.5/5] Running method test (3 cycles with fake-method)..."
METHOD_START=$(date +%s)

# Run d6 (now at test-tasks/method/method-drives-improvement/grade.sh)
# as an explicit invocation, not via run-design-set.sh (which
# would recurse).
METHOD_GRADER="$SCRIPT_DIR/test-tasks/method/method-drives-improvement/grade.sh"
if [[ -x "$METHOD_GRADER" ]]; then
  # Reset state for the method test
  date +%s > "$SCRIPT_DIR/logs/.loop_start_ts"

  if PROJECT_DIR="$SCRIPT_DIR" bash "$METHOD_GRADER" >/dev/null 2>&1; then
    METHOD_RC=0
    echo "  PASS: method test (3 cycles, improvement + force-entropy)"
  else
    METHOD_RC=1
    echo "  FAIL: method test (see logs/method-drives-improvement.log for details)" >&2
    # Re-run with stderr visible to show the failure
    PROJECT_DIR="$SCRIPT_DIR" bash "$METHOD_GRADER" 2>&1 | head -20 >&2
  fi
else
  METHOD_RC=2
  echo "  FAIL: method grader not found or not executable at $METHOD_GRADER" >&2
fi
METHOD_ELAPSED=$(($(date +%s) - METHOD_START))
echo "  method test elapsed: ${METHOD_ELAPSED}s"
echo

# ----- phase 4: run the held-out grader -----

echo "[phase 4/5] Running held-out grader..."

# The held-out grader (specifically h4-force-entropy-trigger) runs
# cycle.sh itself, which creates its own logs/cycle-1/ and
# wipes ours at the end. The snapshot we made in phase 3
# (before phase 3.5 ran) is the source of truth for phase 5.
#
# Important: the snapshot filenames use a prefix that does NOT
# match the h4 grader's `rm -rf logs/cycle-*` cleanup pattern
# (which would match `cycle-1-*` filenames). Use a distinct
# prefix like `cycle1-` or `design-set-snapshot-` to avoid
# being clobbered.

HELD_OUT_LOG="$SCRIPT_DIR/logs/held-out.log"
HELD_OUT_SCORE="$SCRIPT_DIR/logs/held-out-score.json"
if ! PROJECT_DIR="$SCRIPT_DIR" "$SCRIPT_DIR/verifiers/private/grader.sh" \
     > "$HELD_OUT_LOG" 2>&1; then
  echo "  FAIL: held-out grader failed. See logs/held-out.log" >&2
  cat "$HELD_OUT_LOG" >&2
  HELD_OUT_RC=1
else
  HELD_OUT_RC=0
fi
echo

# ----- phase 5: produce report + clean artifacts -----

echo "[phase 5/5] Producing verification report..."
REPORT_MD="$SCRIPT_DIR/verification-report.md"
REPORT_JSON="$SCRIPT_DIR/verification-report.json"

# Aggregate the design set's per-task scores
DESIGN_SCORE="${DESIGN_SNAPSHOT:-$SCRIPT_DIR/logs/cycle-1/design-set-score.json}"
SUB_LOSSES="${SUB_LOSSES_SNAPSHOT:-$SCRIPT_DIR/logs/cycle-1/sub-losses.json}"

# Determine overall pass/fail
OVERALL_PASS=true
if [[ ! -f "$DESIGN_SCORE" ]]; then
  OVERALL_PASS=false
  DESIGN_PASS_RATE=0
else
  DESIGN_PASS_RATE=$(python3 -c "import json; print(json.load(open('$DESIGN_SCORE')).get('pass_rate', 0.0))" 2>/dev/null || echo 0)
  if python3 -c "import sys; sys.exit(0 if float('$DESIGN_PASS_RATE') < 1.0 else 1)"; then
    OVERALL_PASS=false
  fi
fi
if [[ $HELD_OUT_RC -ne 0 ]]; then
  OVERALL_PASS=false
fi

# Read sub-losses if present
if [[ -f "$SUB_LOSSES" ]]; then
  SUB_LOSSES_BODY=$(cat "$SUB_LOSSES")
  WEIGHTED_SUM=$(python3 -c "import json; print(json.load(open('$SUB_LOSSES')).get('weighted_normalized', 0.0))" 2>/dev/null || echo 0)
  GATES_PASSED=$(python3 -c "import json; print(json.load(open('$SUB_LOSSES')).get('gates_passed', False))" 2>/dev/null || echo False)
else
  SUB_LOSSES_BODY='{}'
  WEIGHTED_SUM=0
  GATES_PASSED=False
fi

# Build the report
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUNDLE_VERSION=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/bundle.json'))['version'])" 2>/dev/null || echo "unknown")
PASS_LABEL=$([ "$OVERALL_PASS" = true ] && echo "PASS" || echo "FAIL")

# JSON report
python3 - <<PYEOF > "$REPORT_JSON"
import json
report = {
    "timestamp": "$TIMESTAMP",
    "bundle_version": "$BUNDLE_VERSION",
    "repo": "$REPO_ROOT",
    "profile": "$PROFILE_DIR",
    "elapsed_seconds": $ELAPSED,
    "overall": "$PASS_LABEL",
    "design_pass_rate": $DESIGN_PASS_RATE,
    "weighted_normalized": $WEIGHTED_SUM,
    "gates_passed": "$GATES_PASSED" == "True",
    "cycle_driver_exit": $CYCLE_RC,
    "held_out_grader_exit": $HELD_OUT_RC,
    "sub_losses": json.loads('''$SUB_LOSSES_BODY''') if '''$SUB_LOSSES_BODY''' else {},
}
print(json.dumps(report, indent=2))
PYEOF

# Markdown report
cat > "$REPORT_MD" <<MDEOF
# LFD System Verification Report

**Generated:** $TIMESTAMP
**Bundle version:** $BUNDLE_VERSION
**Repo:** \`$REPO_ROOT\`
**Profile:** \`$PROFILE_DIR\`
**Elapsed:** ${ELAPSED}s

## Overall: **$PASS_LABEL**

| Metric | Value |
|---|---|
| Design-set pass rate | $DESIGN_PASS_RATE |
| Weighted normalized | $WEIGHTED_SUM |
| Gates passed | $GATES_PASSED |
| Cycle driver exit | $CYCLE_RC |
| Held-out grader exit | $HELD_OUT_RC |

## Design tasks

The 5 design tasks are listed in \`test-tasks/design/\`. Each has a
\`prompt.txt\` (the cycle prompt) and a \`grade.sh\` (the per-task
grader, runs after the wrapper returns). The design set's
\`design-set-score.json\` is in \`logs/cycle-1/\`.

To re-run a single design task:

\`\`\`bash
cd examples/lfd-system-verifier
./verifiers/run-design-set.sh d1
\`\`\`

## Held-out tasks

The 5 held-out tasks are listed in \`test-tasks/held-out/\`. They
test harder properties the agent never sees during the loop.
The held-out grader is \`verifiers/private/grader.sh\`. Its output
is in \`logs/held-out.log\`.

## What the verifier proves

This verifier proves the following about the LFD system:

1. The `install.sh` script installs all 11-12 skills into a
   fresh profile and `install.sh --check` passes.
2. The 5 Python parsers (cline, claude-code, codex,
   hermes-agent, opencode) all compile and produce the
   shared 8-key JSON shape on empty input.
3. The \`bundle.json\` manifest is internally consistent
   (version, skills list, install_order, license).
4. The per-cycle sub-loss scorer (\`compute_sub_losses.py\`)
   returns all 7 sub-losses and reports gates correctly.
5. The loop driver (\`cycle.sh\`) runs a complete cycle:
   reads the iteration log, forms a hypothesis, invokes
   the wrapper, runs the design set, scores, appends to
   the log, updates best-cycle.json.
6. The fake-agent adapter produces deterministic output
   (no model, no network, bit-exact reproducible).

If this verifier passes, the LFD system is healthy.

## How to invoke

\`\`\`bash
cd examples/lfd-system-verifier
./run-verification.sh
\`\`\`

The verifier is fully self-contained. It installs the bundle
into a fresh temp profile, runs 1 cycle, and produces the
report. The temp profile is removed at the end.

## Determinism

Two consecutive runs of this script produce byte-identical
output except for the timestamp and elapsed_seconds fields.
The fake-agent adapter has no model and no network, so the
determinism guarantee is exact.

To verify determinism:

\`\`\`bash
./run-verification.sh
sha256sum verification-report.json
./run-verification.sh
sha256sum verification-report.json
# Compare the two sha256sums (modulo the timestamp field).
\`\`\`
MDEOF

echo "  Report: $REPORT_MD"
echo "  Report (JSON): $REPORT_JSON"
echo

# ----- cleanup -----

echo "[cleanup] Removing per-cycle artifacts..."
rm -rf "$SCRIPT_DIR/.iterations"
rm -rf "$SCRIPT_DIR/logs/cycle-"*
# Remove the snapshot files we created in phase 4
rm -f "$SCRIPT_DIR/logs/design-set-score.snapshot.json"
rm -f "$SCRIPT_DIR/logs/sub-losses.snapshot.json"
# Keep logs/iteration-log.md, logs/best-cycle.json,
# logs/held-out.log, logs/held-out-score.json — these are
# the "what was tested" artifacts. The report is in the
# verifier-project root, not under logs/.

# Remove the test profile if we created it
if [[ "$CLEANUP_PROFILE" == "true" ]]; then
  rm -rf "$PROFILE_DIR"
fi

# Remove the symlink to the loop driver (so the verifier-project
# stays self-contained for redistribution)
if [[ -L "$SCRIPT_DIR/loop-driver" ]]; then
  rm "$SCRIPT_DIR/loop-driver"
fi

# Remove the copied sub-loss scorer (regenerated from the
# canonical source at cline-orchestration/references/compute-sub-losses.py
# on the next run; not part of the committed tree).
rm -f "$SCRIPT_DIR/verifiers/compute_sub_losses.py"

# Final status
echo "============================================================"
if [[ "$OVERALL_PASS" == "true" ]]; then
  echo "  RESULT: ✅ LFD system verified ($BUNDLE_VERSION)"
  echo "  Report: $REPORT_MD"
  exit 0
else
  echo "  RESULT: ❌ LFD system verification FAILED"
  echo "  Report: $REPORT_MD"
  exit 1
fi
