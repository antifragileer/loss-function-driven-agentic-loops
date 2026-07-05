#!/usr/bin/env bash
# d5-loop-driver-smoke grader
# Verifies the cycle driver produces well-formed output. This
# is a "shape" check, not a behavior check — d5 runs INSIDE
# the cycle, so it inspects what cycle.sh has just written
# to logs/cycle-1/ and reports on the schema.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"

score=0.0
CYCLE_DIR="$PROJECT_DIR/logs/cycle-1"

# The cycle.sh has just invoked us as part of the design set
# (via run-design-set.sh). It has also just invoked
# sub-loss-readout.sh, so sub-losses.json should exist.
# We verify all the expected files and their schemas.

FAILS=()

# 1. cycle-summary.json: the wrapper's output (8 required keys)
if [[ ! -f "$CYCLE_DIR/cycle-summary.json" ]]; then
  FAILS+=("cycle-summary.json missing")
else
  if ! python3 - "$CYCLE_DIR/cycle-summary.json" <<'PYEOF' 2>/dev/null; then
    FAILS+=("cycle-summary.json shape invalid")
  fi
import json, sys
out = json.load(open(sys.argv[1]))
required = {"tokens", "duration_ms", "candidate_text", "model",
            "provider", "finish_reason", "iterations", "tool_calls"}
missing = required - set(out.keys())
if missing:
    print(f"missing: {missing}", file=sys.stderr); sys.exit(1)
PYEOF
  :; fi
fi

# 2. design-set-score.json: per-task scores
if [[ ! -f "$CYCLE_DIR/design-set-score.json" ]]; then
  FAILS+=("design-set-score.json missing")
else
  if ! python3 - "$CYCLE_DIR/design-set-score.json" <<'PYEOF' 2>/dev/null; then
    FAILS+=("design-set-score.json shape invalid")
  fi
import json, sys
out = json.load(open(sys.argv[1]))
if "pass_rate" not in out:
    print("no pass_rate", file=sys.stderr); sys.exit(1)
PYEOF
  :; fi
fi

# 3. iteration-log.md (at the project root, not cycle dir) — the
# sub-losses.json check was removed because d5 runs as PART of
# the design set, before the cycle's score step writes sub-losses.json.
# The score step's output is exercised by other checks (best-cycle.json,
# cycle-summary.json, the "new best" line in cycle.sh's output).
if [[ ! -f "$PROJECT_DIR/logs/iteration-log.md" ]]; then
  FAILS+=("iteration-log.md missing")
fi

# 4. best-cycle.json (at the project root, not cycle dir)
if [[ ! -f "$PROJECT_DIR/logs/best-cycle.json" ]]; then
  FAILS+=("best-cycle.json missing")
fi

# 5. (removed) — iteration-log.md has a "cycle 1" entry was
# previously checked here, but d5 runs as PART of the design set,
# BEFORE cycle.sh's score step appends the cycle's LOG_LINE
# to iteration-log.md. The cycle's logging is exercised by
# the orchestrator's report (which reads the final iteration-log.md)
# and by the held-out grader h4-force-entropy-trigger (which
# explicitly runs cycle.sh 2x and checks cycle 1 + cycle 2 entries).

# 6. At least one design task sub-dir exists (proves the
# design set actually ran)
n_task_dirs=$(find "$CYCLE_DIR" -mindepth 1 -maxdepth 1 -type d \
              -name 'd[0-9]-*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$n_task_dirs" -lt 1 ]]; then
  FAILS+=("no per-task sub-dirs under $CYCLE_DIR")
fi

# d5 negative check: cycle.sh must NOT be a no-op that always
# returns "pass". The harness-completeness-checklist requires
# per-grader negative checks; d5's negative check is that
# cycle.sh is the real driver (not a 1-line stub).
NEG_FAIL=""
CYCLE_SH="$REPO_ROOT/skills/loop-driver/scripts/cycle.sh"
if [[ ! -s "$CYCLE_SH" ]]; then
  NEG_FAIL="cycle.sh is empty or missing"
elif [[ $(wc -l < "$CYCLE_SH") -lt 50 ]]; then
  NEG_FAIL="cycle.sh has only $(wc -l < "$CYCLE_SH") lines — likely a stub"
fi
if [[ -n "$NEG_FAIL" ]]; then
  FAILS+=("$NEG_FAIL")
fi

# All checks passed
if [[ ${#FAILS[@]} -eq 0 ]]; then
  score=1.0
fi

# d5 does NOT clean logs/cycle-1/ — that's the orchestrator's job.
# d5 only reads.

echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
