#!/usr/bin/env bash
# d1-parse-cline-output grader
# Verifies that the parser correctly extracts the shared shape
# from a Cline NDJSON transcript.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
TASK_DIR="${TASK_DIR:-$(dirname "$0")/../..}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
PARSER="$REPO_ROOT/skills/cline-orchestration/scripts/parse_cline_output.py"
SAMPLE="$PROJECT_DIR/test-tasks/design/d1-parse-cline-output/sample.ndjson"
WRAPPER_OUT="$TASK_DIR/cycle-summary.json"

score=0.0

# Sanity: parser and sample must exist
if [[ ! -f "$PARSER" ]]; then
  echo "FAIL: parser not found at $PARSER" >&2
  echo "score=$score"
  exit 1
fi
if [[ ! -f "$SAMPLE" ]]; then
  echo "FAIL: sample NDJSON not found at $SAMPLE" >&2
  echo "score=$score"
  exit 1
fi

# Run the parser on the sample
PARSER_OUT="$TASK_DIR/parser-out.json"
if ! python3 "$PARSER" "$SAMPLE" > "$PARSER_OUT" 2>"$TASK_DIR/parser.err"; then
  echo "FAIL: parser exited non-zero" >&2
  cat "$TASK_DIR/parser.err" >&2
  echo "score=$score"
  exit 1
fi

# Verify the output is valid JSON with all 8 required keys
python3 - "$PARSER_OUT" <<'PYEOF'
import json, sys
out_path = sys.argv[1]
with open(out_path) as f: out = json.load(f)
required = {"tokens", "duration_ms", "candidate_text", "model",
            "provider", "finish_reason", "iterations", "tool_calls"}
missing = required - set(out.keys())
if missing:
    print(f"FAIL: missing keys: {missing}", file=sys.stderr)
    sys.exit(1)
if not isinstance(out["tokens"], int):
    print(f"FAIL: tokens is not int: {out['tokens']!r}", file=sys.stderr)
    sys.exit(1)
if not isinstance(out["duration_ms"], int):
    print(f"FAIL: duration_ms is not int: {out['duration_ms']!r}", file=sys.stderr)
    sys.exit(1)
if not isinstance(out["candidate_text"], str) or not out["candidate_text"]:
    print(f"FAIL: candidate_text empty: {out['candidate_text']!r}", file=sys.stderr)
    sys.exit(1)
if not isinstance(out["tool_calls"], list):
    print(f"FAIL: tool_calls not list: {out['tool_calls']!r}", file=sys.stderr)
    sys.exit(1)
# The sample has aggregateUsage with inputTokens=1500,
# outputTokens=2400, cacheReadTokens=0, so tokens=3900.
if out["tokens"] != 3900:
    print(f"FAIL: expected tokens=3900, got {out['tokens']}", file=sys.stderr)
    sys.exit(1)
if out["duration_ms"] != 12345:
    print(f"FAIL: expected duration_ms=12345, got {out['duration_ms']}", file=sys.stderr)
    sys.exit(1)
if out["model"] != "test-model":
    print(f"FAIL: expected model='test-model', got {out['model']!r}", file=sys.stderr)
    sys.exit(1)
# d1 negative check: parser source must NOT contain eval/exec of untrusted input.
# (The agent might try to "fix" the parser by replacing it with an
# eval-based stub. The grader catches that.)
PYEOF
RC=$?

# Negative check: parser source must not have been replaced with an
# eval-based shim. (Anti-cheat: the agent might "fix" the parser by
# writing a stub that always returns the expected JSON.)
NEG_FAIL=""
if grep -qE 'eval.*input|exec.*input|subprocess\.call.*shell=True' "$PARSER" 2>/dev/null; then
  NEG_FAIL="parser source contains eval/exec/shell=True"
fi
if [[ -n "$NEG_FAIL" ]]; then
  echo "FAIL: $NEG_FAIL" >&2
  exit 1
fi

if [[ $RC -eq 0 ]]; then
  score=1.0
fi

echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
