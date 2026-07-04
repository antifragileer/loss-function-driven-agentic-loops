#!/usr/bin/env bash
# d4-compute-sub-losses grader
# Verifies the sub-loss scorer returns all 7 sub-losses
# and reports gates correctly.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
SCORER="$REPO_ROOT/examples/lfd-system-verifier/verifiers/compute_sub_losses.py"

if [[ ! -f "$SCORER" ]]; then
  echo "FAIL: sub-loss scorer not found at $SCORER" >&2
  echo "score=0.0"
  exit 1
fi

# Build a sample input that's a successful cycle
SAMPLE=$(mktemp)
cat > "$SAMPLE" <<'JSON'
{
  "tokens": 1000,
  "duration_ms": 5000,
  "candidate_text": "The candidate is non-empty and well-formed.",
  "model": "test",
  "provider": "test",
  "finish_reason": "completed",
  "iterations": 1,
  "tool_calls": [],
  "exit_code": 0,
  "pass_rate": 1.0,
  "n_pass": 5,
  "n_total": 5
}
JSON

OUT=$(mktemp)
if ! python3 "$SCORER" "$SAMPLE" > "$OUT" 2>/dev/null; then
  echo "FAIL: scorer exited non-zero" >&2
  echo "score=0.0"
  rm -f "$SAMPLE" "$OUT"
  exit 1
fi

python3 - "$OUT" <<'PYEOF'
import json, sys
out = json.load(open(sys.argv[1]))
# Must have the 7 sub-losses
expected_losses = {"correctness", "performance", "safety", "legibility",
                   "invariants", "drift", "cost"}
if "sub_losses" not in out:
    print("FAIL: no sub_losses field", file=sys.stderr); sys.exit(1)
actual = set(out["sub_losses"].keys())
if actual != expected_losses:
    print(f"FAIL: sub-losses {actual} != {expected_losses}", file=sys.stderr)
    sys.exit(1)
# Must have weights
if "weights" not in out:
    print("FAIL: no weights field", file=sys.stderr); sys.exit(1)
# Must have gates
if "gates" not in out:
    print("FAIL: no gates field", file=sys.stderr); sys.exit(1)
expected_gates = {"correctness", "safety", "invariants"}
if set(out["gates"]) != expected_gates:
    print(f"FAIL: gates {set(out['gates'])} != {expected_gates}", file=sys.stderr)
    sys.exit(1)
# Gates passed (input is clean)
if not out.get("gates_passed", False):
    print(f"FAIL: gates_passed is False on clean input: {out.get('gates_passed')!r}",
          file=sys.stderr)
    sys.exit(1)
PYEOF
RC=$?

rm -f "$SAMPLE" "$OUT"

if [[ $RC -eq 0 ]]; then score=1.0; fi
echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
