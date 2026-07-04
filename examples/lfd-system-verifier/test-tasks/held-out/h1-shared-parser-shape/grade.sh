#!/usr/bin/env bash
# h1-shared-parser-shape grader (held-out)
# Verifies all 5 adapter parsers produce the same 8-key
# shared shape on identical empty input.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
TASK_DIR="${TASK_DIR:-$(mktemp -d)}"
TMP_INPUT="$(mktemp)"
trap 'rm -rf "$TASK_DIR" "$TMP_INPUT"' EXIT

# Empty file as input
: > "$TMP_INPUT"

# Find the parsers
PARSERS=(
  "$REPO_ROOT/skills/cline-orchestration/scripts/parse_cline_output.py"
  "$REPO_ROOT/skills/claude-code-orchestration/scripts/parse_claude_output.py"
  "$REPO_ROOT/skills/codex-orchestration/scripts/parse_codex_output.py"
  "$REPO_ROOT/skills/hermes-agent-orchestration/scripts/parse_hermes_output.py"
  "$REPO_ROOT/skills/opencode-orchestration/scripts/parse_opencode_output.py"
)

score=0.0
n_pass=0
n_total=${#PARSERS[@]}

for p in "${PARSERS[@]}"; do
  if [[ ! -f "$p" ]]; then
    echo "FAIL: parser not found: $p" >&2
    continue
  fi
  out=$(python3 "$p" "$TMP_INPUT" 2>/dev/null)
  if ! python3 -c "
import json, sys
out = json.loads('''$out''')
required = {'tokens', 'duration_ms', 'candidate_text', 'model',
            'provider', 'finish_reason', 'iterations', 'tool_calls'}
missing = required - set(out.keys())
if missing:
    sys.exit(1)
if not isinstance(out['tokens'], int): sys.exit(1)
if not isinstance(out['duration_ms'], int): sys.exit(1)
if not isinstance(out['candidate_text'], str): sys.exit(1)
if not isinstance(out['tool_calls'], list): sys.exit(1)
"; then
    echo "FAIL: $p does not produce the shared shape" >&2
    echo "  output: $out" >&2
    continue
  fi
  n_pass=$((n_pass + 1))
done

if [[ $n_pass -eq $n_total ]]; then
  score=1.0
else
  score=$(python3 -c "print($n_pass / $n_total)")
fi

echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
