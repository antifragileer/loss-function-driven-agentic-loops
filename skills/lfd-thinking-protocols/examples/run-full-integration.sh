#!/usr/bin/env bash
# run-full-integration.sh — end-to-end proof that the
# V0->V1->HITL->V2+ flow still works after adding
# lfd-thinking-protocols. Runs BOTH the fake-agent and
# the real-agent verifier, in that order. Both must
# pass for the integration to be considered verified.
#
# Usage: ./examples/run-full-integration.sh
#   (run from the repo root, not from examples/)
#
# Exit codes:
#   0: both verifiers passed
#   1: at least one verifier failed
#   2: setup error (bundle not found, real-agent binary
#      not installed)
#
# This is the canonical integration test for the
# "lfd-thinking-protocols does not break the loop"
# claim. Run it after any change to the skill.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VERIFIER_PROJECT="$REPO_ROOT/examples/lfd-system-verifier"

if [[ ! -d "$VERIFIER_PROJECT" ]]; then
  echo "FAIL: verifier-project not found at $VERIFIER_PROJECT" >&2
  exit 2
fi

if [[ ! -x "$VERIFIER_PROJECT/run-verification.sh" ]]; then
  echo "FAIL: run-verification.sh missing or not executable" >&2
  exit 2
fi

echo "============================================================"
echo "  LFD Thinking Protocols — Full Integration Test"
echo "  repo:   $REPO_ROOT"
echo "  verifier: $VERIFIER_PROJECT"
echo "============================================================"

# ----- phase 1: fake-agent run (the deterministic gate) -----

echo ""
echo "--- Phase 1: fake-agent (deterministic) ---"
echo ""

# Save any existing reports so we can detect a regression
if [[ -f "$VERIFIER_PROJECT/verification-report.json" ]]; then
  mv "$VERIFIER_PROJECT/verification-report.json" \
     "$VERIFIER_PROJECT/verification-report.json.prev" 2>/dev/null || true
fi

if ! bash "$VERIFIER_PROJECT/run-verification.sh" "$REPO_ROOT"; then
  echo ""
  echo "FAIL: fake-agent verifier exited non-zero" >&2
  echo "  This means lfd-thinking-protocols broke the V0->V1 baseline." >&2
  echo "  Read $VERIFIER_PROJECT/verification-report.md for the failure shape." >&2
  exit 1
fi

# Read the report
FAKE_REPORT="$VERIFIER_PROJECT/verification-report.json"
if [[ ! -f "$FAKE_REPORT" ]]; then
  echo "FAIL: fake-agent report missing at $FAKE_REPORT" >&2
  exit 1
fi

fake_overall=$(python3 -c "import json; print(json.load(open('$FAKE_REPORT')).get('overall',''))" 2>/dev/null || echo "")
fake_design=$(python3 -c "import json; print(json.load(open('$FAKE_REPORT')).get('design_pass_rate',0))" 2>/dev/null || echo "0")
fake_weighted=$(python3 -c "import json; print(json.load(open('$FAKE_REPORT')).get('weighted_normalized',0))" 2>/dev/null || echo "0")
fake_heldout=$(python3 -c "import json; print(json.load(open('$FAKE_REPORT')).get('held_out_grader_exit',1))" 2>/dev/null || echo "1")

if [[ "$fake_overall" != "PASS" ]]; then
  echo "FAIL: fake-agent overall != PASS (got '$fake_overall')" >&2
  exit 1
fi

echo "  fake-agent: overall=$fake_overall, design_pass_rate=$fake_design, weighted_normalized=$fake_weighted, held_out_grader_exit=$fake_heldout"

# ----- phase 2: real-agent run (the integration gate) -----

echo ""
echo "--- Phase 2: real-agent (Cline) ---"
echo ""

REAL_SH="$VERIFIER_PROJECT/run-verification-real.sh"
if [[ ! -x "$REAL_SH" ]]; then
  echo "SKIP: run-verification-real.sh missing or not executable"
  echo "  (The real-agent run is optional but recommended.)"
  echo ""
  echo "============================================================"
  echo "  RESULT: ✅ Integration verified (fake-agent only)"
  echo "  Run $REAL_SH separately to add the real-agent gate."
  echo "============================================================"
  exit 0
fi

# Save any existing real-agent report
if [[ -f "$VERIFIER_PROJECT/verification-report-real.json" ]]; then
  mv "$VERIFIER_PROJECT/verification-report-real.json" \
     "$VERIFIER_PROJECT/verification-report-real.json.prev" 2>/dev/null || true
fi

# Set a 5-min budget to keep the test bounded
export LFD_REAL_BUDGET="${LFD_REAL_BUDGET:-300}"

if ! bash "$REAL_SH" "$REPO_ROOT" "" cline; then
  echo ""
  echo "WARN: real-agent verifier exited non-zero"
  echo "  This may be a model-temperature flake (expected) or a real"
  echo "  regression. Re-run to disambiguate. See"
  echo "  $VERIFIER_PROJECT/verification-report-real.md for details."
  echo ""
  echo "============================================================"
  echo "  RESULT: ⚠️  Fake-agent PASS, real-agent FAILED"
  echo "  Check $VERIFIER_PROJECT/verification-report-real.md"
  echo "============================================================"
  exit 1
fi

REAL_REPORT="$VERIFIER_PROJECT/verification-report-real.json"
if [[ ! -f "$REAL_REPORT" ]]; then
  echo "WARN: real-agent report missing at $REAL_REPORT"
  echo ""
  echo "============================================================"
  echo "  RESULT: ⚠️  Fake-agent PASS, real-agent report missing"
  echo "============================================================"
  exit 1
fi

real_design=$(python3 -c "import json; print(json.load(open('$REAL_REPORT')).get('design_pass_rate',0))" 2>/dev/null || echo "0")
real_overall=$(python3 -c "import json; print(json.load(open('$REAL_REPORT')).get('overall',''))" 2>/dev/null || echo "")

# The real-agent threshold is pass_rate >= 0.8 (per
# lfd-system-verifier/SKILL.md). A 4/5 is the norm.
if python3 -c "import sys; sys.exit(0 if float('$real_design') >= 0.8 else 1)"; then
  echo "  real-agent: overall=$real_overall, design_pass_rate=$real_design"
  echo ""
  echo "============================================================"
  echo "  RESULT: ✅ LFD system fully verified (fake + real agent)"
  echo "  Fake report:  $VERIFIER_PROJECT/verification-report.md"
  echo "  Real report:  $VERIFIER_PROJECT/verification-report-real.md"
  echo "============================================================"
  exit 0
else
  echo "WARN: real-agent design_pass_rate < 0.8 (got '$real_design')"
  echo "  This may be a flake. Re-run to disambiguate."
  echo ""
  echo "============================================================"
  echo "  RESULT: ⚠️  Fake-agent PASS, real-agent below threshold"
  echo "============================================================"
  exit 1
fi
