#!/usr/bin/env bash
# cline-wrapper.sh — the ONLY way the LFD system verifier
# (real-agent mode) invokes Cline. Never call `cline` directly
# from a driver; always go through this script.
#
# Implements the contract documented in
# skills/cline-orchestration/references/cline-wrapper-contract.md
#
# Usage:
#   cline-wrapper.sh "<task-prompt>" --cwd PATH \
#       --timeout 600 --cycle cycle-N > cycle-summary.json
#
# What this wrapper does:
#   1. Parses the args (positional TASK + --cwd/--timeout/--cycle)
#   2. Resolves the cline binary (CLINE_BIN env → PATH → bail)
#   3. Creates a per-cycle ITER_DIR at ${CWD}/.iterations/${CYCLE}
#   4. Invokes Cline with the verified flag set
#      (positional prompt, --cwd, --auto-approve true,
#       --thinking none, --json). NO --worktree, NO
#      --provider, NO --model. Cline's own auth decides.
#   5. Captures NDJSON → ${ITER_DIR}/cline.json,
#      stderr → ${ITER_DIR}/cline.stderr
#   6. Parses the NDJSON via the central parser
#      (skills/cline-orchestration/scripts/parse_cline_output.py,
#      resolved at call time so the wrapper is portable)
#   7. Emits ONE JSON object on stdout with the 8 shared
#      keys (cycle, exit_code, elapsed_seconds,
#      cline_duration_ms, tokens, model, provider,
#      candidate_text, plus tool_calls/finish_reason/
#      iterations/raw_output_path)
#
# Exit codes:
#   0: wrapper-level success (Cline's own status is in
#      finish_reason; check the JSON, not the exit code)
#   2: usage error (missing args, bad flags)
#   3: cline binary not found

set -euo pipefail

# ----- argument parsing -----

TASK=""
CWD=""
TIMEOUT=600
CYCLE="cycle-0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --cycle)
      if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        CYCLE="cycle-$2"
        shift 2
      else
        CYCLE="${2:-cycle-0}"
        shift 2
      fi
      ;;
    --cycle=*) CYCLE="${1#--cycle=}"; shift ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) TASK="$1"; shift ;;
  esac
done

if [[ -z "$TASK" ]]; then
  echo '{"error":"missing positional TASK arg"}' >&2
  exit 2
fi
if [[ -z "$CWD" ]]; then
  echo '{"error":"missing --cwd"}' >&2
  exit 2
fi
if [[ ! -d "$CWD" ]]; then
  echo "{\"error\":\"cwd does not exist: $CWD\"}" >&2
  exit 2
fi

# ----- resolve cline binary -----

CLINE_BIN="${CLINE_BIN:-$(command -v cline 2>/dev/null || true)}"
if [[ -z "$CLINE_BIN" || ! -x "$CLINE_BIN" ]]; then
  echo '{"error":"cline binary not found; set $CLINE_BIN or add cline to PATH"}' >&2
  exit 3
fi

# ----- resolve the central parser -----

# The parser lives at
# skills/cline-orchestration/scripts/parse_cline_output.py
# relative to the LFD bundle repo. We resolve it via the
# REPO_ROOT env var (set by run-verification-real.sh), or
# fall back to walking up from the wrapper's own location.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The verifier-project lives at <repo>/examples/lfd-system-verifier
# so the parser is at
# <repo>/skills/cline-orchestration/scripts/parse_cline_output.py
# Walking up three levels from the wrapper gets us to the repo root
# (wrapper is at examples/lfd-system-verifier/verifiers/, the repo
# is two directories up from there).
if [[ -z "${REPO_ROOT:-}" ]]; then
  # The wrapper is at examples/lfd-system-verifier/verifiers/cline-wrapper.sh
  # The repo root is three levels up from the wrapper script's directory.
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi
PARSER="$REPO_ROOT/skills/cline-orchestration/scripts/parse_cline_output.py"
if [[ ! -f "$PARSER" ]]; then
  echo "{\"error\":\"parser not found at $PARSER; set REPO_ROOT or check the bundle layout\"}" >&2
  exit 2
fi

# ----- per-cycle ITER_DIR -----

ITER_DIR="${CWD}/.iterations/${CYCLE}"
mkdir -p "$ITER_DIR"

# ----- invoke Cline with the verified flag set -----

RAW_OUT="${ITER_DIR}/cline.json"
STDERR_OUT="${ITER_DIR}/cline.stderr"

# We DO NOT pass --worktree (auth failures with some providers)
# We DO NOT pass --provider or --model (cline auth decided them)
# We DO pass --auto-approve true (needed for non-interactive
# file writes; safety is enforced by a transcript grep, not
# by per-tool approval, per the cline-orchestration skill).
# We DO pass --thinking none (the only level guaranteed to
# work with every provider, especially OpenAI-compat).

START_TS=$(date +%s)
WRAPPER_EXIT=0

"$CLINE_BIN" "$TASK" \
  --cwd "$ITER_DIR" \
  --auto-approve true \
  --thinking none \
  --json \
  > "$RAW_OUT" 2>"$STDERR_OUT" || WRAPPER_EXIT=$?

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

# ----- parse the NDJSON via the central parser -----

PARSED="$(python3 "$PARSER" "$RAW_OUT" 2>/dev/null || echo '{}')"

# ----- emit ONE JSON on stdout with the contract shape -----

python3 - "$PARSED" "$CYCLE" "$WRAPPER_EXIT" "$ELAPSED" "$RAW_OUT" <<'PYEOF'
import json, sys
parsed_raw, cycle, exit_code, elapsed, raw_path = sys.argv[1:6]
try:
    p = json.loads(parsed_raw)
except Exception:
    p = {}
# Contract: every cycle summary must have the 8 shared keys,
# even if the parse failed.
out = {
    "cycle": cycle,
    "exit_code": int(exit_code),
    "elapsed_seconds": int(elapsed),
    "cline_duration_ms": int(p.get("duration_ms", 0) or 0),
    "tokens": int(p.get("tokens", 0) or 0),
    "model": p.get("model", "") or "",
    "provider": p.get("provider", "") or "",
    "candidate_text": p.get("candidate_text", "") or "",
    "tool_calls": p.get("tool_calls", []) or [],
    "finish_reason": p.get("finish_reason", "unknown") or "unknown",
    "iterations": int(p.get("iterations", 0) or 0),
    "raw_output_path": raw_path,
}
print(json.dumps(out, indent=2))
PYEOF

# The wrapper exits 0 on a clean run. Cline's own status
# (finish_reason == "error", empty candidate, refusal in
# candidate_text) is recorded in the JSON; the driver
# inspects JSON, not the wrapper's exit code. The driver
# only sees non-zero from this wrapper on usage errors
# (exit 2) or missing-binary errors (exit 3).
exit 0
