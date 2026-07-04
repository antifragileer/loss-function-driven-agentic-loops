#!/usr/bin/env bash
# h3-drift-opt-in grader (held-out)
# Verifies the drift sub-loss correctly handles the
# expected_model="" opt-in.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
SCORER_SRC="$REPO_ROOT/skills/cline-orchestration/references/compute-sub-losses.py"

# Use the scorer from the cline-orchestration skill (the
# verifier-project copies it to verifiers/compute_sub_losses.py
# at runtime; here we use the canonical one).
SCORER="$SCORER_SRC"
if [[ ! -f "$SCORER" ]]; then
  echo "FAIL: compute-sub-losses.py not found at $SCORER" >&2
  echo "score=0.0"
  exit 1
fi

# Sample input with expected_model unset (the verifier
# asserts that drift_score() returns 1.0 in this case)
TMP_INPUT="$(mktemp)"
cat > "$TMP_INPUT" <<'JSON'
{
  "tokens": 1000,
  "duration_ms": 5000,
  "candidate_text": "non-empty",
  "model": "test",
  "provider": "test",
  "finish_reason": "completed",
  "iterations": 1,
  "tool_calls": []
}
JSON

OUT=$(mktemp)
if ! python3 "$SCORER" "$TMP_INPUT" > "$OUT" 2>/dev/null; then
  echo "FAIL: scorer exited non-zero" >&2
  rm -f "$TMP_INPUT" "$OUT"
  echo "score=0.0"
  exit 1
fi

# Check that drift sub-loss is 1.0 (no expected_model set)
python3 - "$OUT" <<'PYEOF' && score=1.0 || score=0.0
import json, sys
out = json.load(open(sys.argv[1]))
drift = out.get("sub_losses", {}).get("drift", {})
if isinstance(drift, dict):
    score = drift.get("score", 0.0)
elif isinstance(drift, (int, float)):
    score = drift
if score < 1.0:
    print(f"FAIL: drift score {score} < 1.0 when expected_model is unset",
          file=sys.stderr)
    sys.exit(1)
PYEOF
rm -f "$TMP_INPUT" "$OUT"

echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
