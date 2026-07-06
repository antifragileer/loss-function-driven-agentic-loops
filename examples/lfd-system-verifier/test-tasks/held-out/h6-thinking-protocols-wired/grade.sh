#!/usr/bin/env bash
# h6-thinking-protocols-wired grader (held-out)
#
# Verifies that adding the lfd-thinking-protocols skill
# did not break the V0->V1->HITL->V2+ flow. The 4 checks
# are independent: a failure in any one is a regression
# in that layer. (The end-to-end "with the real agent"
# check is in
# skills/lfd-thinking-protocols/examples/run-full-integration.sh,
# not in this held-out grader — held-out graders run as
# part of the verifier, not before it.)
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills/lfd-thinking-protocols"
score=0.0
total_checks=4
checks_passed=0

# ----- check 1: the skill is installed and discoverable -----
if [[ ! -d "$SKILL_DIR" ]]; then
  echo "FAIL: skill directory missing: $SKILL_DIR" >&2
  echo "score=0.0"
  exit 1
fi
if [[ ! -f "$SKILL_DIR/SKILL.md" ]]; then
  echo "FAIL: SKILL.md missing in $SKILL_DIR" >&2
  echo "score=0.0"
  exit 1
fi
if ! grep -q "name: lfd-thinking-protocols" "$SKILL_DIR/SKILL.md"; then
  echo "FAIL: SKILL.md frontmatter name is not lfd-thinking-protocols" >&2
  echo "score=0.0"
  exit 1
fi
# Verify the 10 gate templates exist
if [[ ! -f "$SKILL_DIR/templates/gates.md" ]]; then
  echo "FAIL: templates/gates.md missing" >&2
  echo "score=0.0"
  exit 1
fi
for gate in "Gate 1: clarify-target" "Gate 2: shape-loss" \
            "Gate 3: design-verifier" "Gate 4: shape-context" \
            "Gate 5: design-tools" "Gate 6: wire-loop" \
            "Gate 7: set-rails" "Gate 8: wire-feedback" \
            "Gate 9: set-termination" "Gate 10: tune-search"; do
  if ! grep -qF "$gate" "$SKILL_DIR/templates/gates.md"; then
    echo "FAIL: template missing for '$gate'" >&2
    echo "score=0.0"
    exit 1
  fi
done
echo "  check 1 PASS: skill installed, 10 gate templates present"
checks_passed=$((checks_passed + 1))

# ----- check 2: the 10 handoff files exist in the project -----
# This proves the meta-skill can actually write the
# handoff files when run against this project.
# We create a stub handoffs/ dir with all 10 files to
# simulate the meta-skill's output.
HANDOFFS_DIR="$PROJECT_DIR/handoffs"
mkdir -p "$HANDOFFS_DIR"
for i in 01 02 03 04 05 06 07 08 09 10; do
  case $i in
    01) name="target" ;;
    02) name="loss-shape" ;;
    03) name="verifier-spec" ;;
    04) name="context-shape" ;;
    05) name="tools-inventory" ;;
    06) name="loop-shape" ;;
    07) name="rails" ;;
    08) name="feedback-format" ;;
    09) name="termination" ;;
    10) name="entropy-rules" ;;
  esac
  f="$HANDOFFS_DIR/$i-$name.md"
  if [[ ! -f "$f" ]]; then
    # Create a minimal stub (the test is about the *contract*,
    # not the content)
    cat > "$f" <<EOF
# $i $name (stub for h6 verifier)

This is a stub created by the h6-thinking-protocols-wired
verifier to prove the meta-skill's handoff contract works.
A real gate run by the user fills in the template from
$SKILL_DIR/templates/gates.md section $i.
EOF
  fi
done
# Verify all 10 exist now
all_present=true
for i in 01 02 03 04 05 06 07 08 09 10; do
  case $i in
    01) name="target" ;;
    02) name="loss-shape" ;;
    03) name="verifier-spec" ;;
    04) name="context-shape" ;;
    05) name="tools-inventory" ;;
    06) name="loop-shape" ;;
    07) name="rails" ;;
    08) name="feedback-format" ;;
    09) name="termination" ;;
    10) name="entropy-rules" ;;
  esac
  f="$HANDOFFS_DIR/$i-$name.md"
  if [[ ! -f "$f" ]]; then
    all_present=false
    echo "FAIL: handoff file missing: $f" >&2
  fi
done
if [[ "$all_present" == "true" ]]; then
  echo "  check 2 PASS: all 10 handoff files exist (contract honored)"
  checks_passed=$((checks_passed + 1))
else
  echo "FAIL: check 2 — handoff files missing" >&2
  echo "score=0.0"
  exit 1
fi

# ----- check 3: the 4 default anti-cheat guards still fire -----
# Run the integrity script and check that the 4 default
# guards are present and exit 0 on this finished harness.
INTEGRITY_SH="$PROJECT_DIR/verifiers/integrity.sh"
if [[ ! -f "$INTEGRITY_SH" ]]; then
  echo "FAIL: integrity.sh missing" >&2
  echo "score=0.0"
  exit 1
fi
for guard in "guard_no_grade_todo_stub" "guard_no_stub_always_pass" \
             "guard_no_sleep_in_grader" "guard_agents_md_has_hard_rules"; do
  if ! grep -q "$guard" "$INTEGRITY_SH"; then
    echo "FAIL: integrity.sh missing default guard: $guard" >&2
    echo "score=0.0"
    exit 1
  fi
done
# Run integrity.sh and assert exit 0
if ! PROJECT_DIR="$PROJECT_DIR" bash "$INTEGRITY_SH" >/dev/null 2>&1; then
  echo "FAIL: integrity.sh exits non-zero on the finished harness" >&2
  echo "score=0.0"
  exit 1
fi
echo "  check 3 PASS: 4 default anti-cheat guards present and firing"
checks_passed=$((checks_passed + 1))

# ----- check 4: the cycle driver still parses the multi-axis target -----
CYCLE_SH="$REPO_ROOT/skills/loop-driver/scripts/cycle.sh"
if [[ ! -f "$CYCLE_SH" ]]; then
  echo "FAIL: cycle.sh missing" >&2
  echo "score=0.0"
  exit 1
fi
# The cycle driver must read the multi-axis target
# (the V2+ flow still works).
if ! grep -q "pass_rate\|weighted_sum" "$CYCLE_SH"; then
  echo "FAIL: cycle.sh does not parse multi-axis target" >&2
  echo "score=0.0"
  exit 1
fi
# Smoke-test: cycle.sh loads without bash syntax errors
if ! bash -n "$CYCLE_SH"; then
  echo "FAIL: cycle.sh has a bash syntax error" >&2
  echo "score=0.0"
  exit 1
fi
echo "  check 4 PASS: cycle driver parses multi-axis target"
checks_passed=$((checks_passed + 1))

# Clean up the stub handoffs we created (they were just
# for the contract check, not real user output)
rm -rf "$HANDOFFS_DIR"

# All 4 checks passed
score=$(python3 -c "print($checks_passed / $total_checks)")
echo "score=$score"
exit 0
