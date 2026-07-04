# Cline wrapper script — the contract

The wrapper script is the ONLY way the loss-function loop is
allowed to invoke Cline. Cline must never be called directly
from the driver. This file documents the contract the wrapper
must satisfy, plus the canonical worked example.

## Contract

The wrapper must:

1. **Accept a positional prompt, `--cwd PATH`, `--timeout
   SECONDS`, `--cycle ID` (or `--cycle cycle-N`).** Parse args
   with `getopts` or a manual `while [[ $# -gt 0 ]]; do case
   ...`. Don't reinvent — copy the pattern from the worked
   example.

2. **Resolve the Cline binary.** Default to the `$CLINE_BIN`
   environment variable. Fall back to `command -v cline`.
   Bail with a structured error if neither is found.

3. **Create a per-cycle `ITER_DIR` at
   `${CWD}/.iterations/${CYCLE}`.** Create the parent if
   needed. Do NOT `git init` the iter dir (we're not using
   `--worktree`).

4. **Invoke Cline with the verified flag set.** As of
   v3.0.34+: positional prompt, `--cwd "$ITER_DIR"`,
   `--auto-approve true`, `--thinking none`, `--json`. **No
   `--provider`. No `--model`.** Let `cline auth` decide.

5. **Capture NDJSON output to `${ITER_DIR}/cline.json` and
   stderr to `${ITER_DIR}/cline.stderr`.** Both are evidence
   the verifier and the agent can read.

6. **Time the run.** Two clocks matter: (a) wrapper
   wall-clock (the user's view) via `date +%s` before/after,
   (b) Cline's own `run_result.durationMs` (Cline's view,
   excludes Python parsing overhead). Log BOTH. The driver
   uses wall-clock for the loop budget; the verifier uses
   Cline's duration for the per-task performance sub-loss.

7. **Parse the NDJSON via `scripts/parse_cline_output.py`.**
   Do NOT hand-roll a JSON parser inline. The schema has
   changed across Cline versions and will change again. The
   parser centralizes the version-pinned extraction.

8. **Emit ONE JSON object on stdout.** Schema:

   ```json
   {
     "cycle": "cycle-1",
     "exit_code": 0,
     "elapsed_seconds": 10,
     "cline_duration_ms": 8329,
     "tokens": 25579,
     "model": "<active-model>",
     "provider": "<active-provider>",
     "candidate_text": "...",
     "tool_calls": [...],
     "finish_reason": "completed",
     "iterations": 3,
     "raw_output_path": "/path/to/.iterations/cycle-1/cline.json"
   }
   ```

9. **Bail with a non-zero exit code only on wrapper-level
   failures** (bad args, no cline binary). Cline's own
   `run_result.finishReason == "error"` is recorded in the
   JSON but the wrapper's process exit code is 0 — the
   driver checks `finish_reason`, not the wrapper's exit
   code.

## Worked example (annotated)

```bash
#!/usr/bin/env bash
# verifiers/cline-wrapper.sh — the ONLY way to invoke cline.
set -euo pipefail

TASK=""; CWD=""; TIMEOUT=600; CYCLE="cycle-0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --cycle)
      if [[ "${2:-}" =~ ^[0-9]+$ ]]; then CYCLE="cycle-$2"; shift 2
      else CYCLE="${2:-cycle-0}"; shift 2; fi ;;
    --cycle=*) CYCLE="${1#--cycle=}"; shift ;;
    *) TASK="$1"; shift ;;
  esac
done
[[ -z "$TASK" || -z "$CWD" ]] && { echo '{"error":"missing arg"}'; exit 2; }

# Resolve cline binary: $CLINE_BIN env, then PATH, then bail.
CLINE_BIN="${CLINE_BIN:-$(command -v cline 2>/dev/null || true)}"
[[ -z "$CLINE_BIN" || ! -x "$CLINE_BIN" ]] && {
  echo '{"error":"cline not found; set $CLINE_BIN or add cline to PATH"}'
  exit 3
}

ITER_DIR="${CWD}/.iterations/${CYCLE}"
mkdir -p "$ITER_DIR"

# Cline's binary runs a detached auto-updater on every
# invocation that fetches the latest version from npm, spawns
# a detached `npm install`, and RESTARTS the background hub
# that tracks sessions. With back-to-back Cline invocations
# (the loss-function loop runs many in a row), the hub
# restart races with the next invocation's session lookup
# and produces "session not found: <id>" errors. Cline reads
# `CLINE_NO_AUTO_UPDATE=1` in its own source to skip the
# auto-updater. Set it before every Cline invocation to
# disable. This is internal (no user-facing setting changes).
# See references/cline-v3-invocation.md for the full story.
export CLINE_NO_AUTO_UPDATE=1

START_TS=$(date +%s)
RAW_OUT="${ITER_DIR}/cline.json"
EXIT_CODE=0

# Cline invocation — see "verified flag set" above. NO
# --worktree, NO --provider, NO --model. Cline's own auth
# decides.
"$CLINE_BIN" "$TASK" \
  --cwd "$ITER_DIR" \
  --auto-approve true \
  --thinking none \
  --json \
  > "$RAW_OUT" 2>"${ITER_DIR}/cline.stderr" || EXIT_CODE=$?

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

# Parse via the central parser. Don't inline python here.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARSED=$(python3 "$SCRIPT_DIR/parse_cline_output.py" "$RAW_OUT")

# Merge parsed + wrapper-level fields, emit ONE JSON on stdout.
python3 -c '
import json, sys
out = json.loads(sys.argv[1])
out.update({
    "cycle": sys.argv[2],
    "exit_code": int(sys.argv[3]),
    "elapsed_seconds": int(sys.argv[4]),
    "raw_output_path": sys.argv[5],
})
print(json.dumps(out, indent=2))
' "$PARSED" "$CYCLE" "$EXIT_CODE" "$ELAPSED" "$RAW_OUT"
```

## Pitfalls hit while building this (lessons that survive the next Cline version)

- **Don't inline `python3 -c` blocks with embedded JSON parsing
  logic.** Heredoc indentation bites, `set -euo pipefail` plus
  `python3 <<PY` is a footgun. Centralize parsing in a
  `scripts/` file.
- **The parser must handle BOTH formats.** The wrapper's
  `cycle-summary.json` (one object) and Cline's raw
  `cline.json` (NDJSON) should both parse. Sub-loss tools that
  read `cycle-N.json` may be pointed at either; the parser
  handles both via try/except on `JSONDecodeError`.
- **The parser path is `${SCRIPT_DIR}/../parse_cline_output.py`
  or similar.** Don't rely on CWD. Resolve via
  `$(cd "$(dirname "$0")" && pwd)`.
- **Never exit 0 from the wrapper when the Cline run failed.**
  The wrapper records `finish_reason` and `exit_code` in JSON
  but its own process exit is reserved for wrapper-level
  errors. The driver inspects JSON, not exit codes. (Both
  records: the JSON is the source of truth, the exit code is
  for shell pipelines that need a quick gate.)
- **Don't `--worktree`.** Auth failures. Use a fresh
  `${CWD}/.iterations/${CYCLE}` per call.
- **Don't pass `--provider` or `--model`.** `cline auth` chose
  the model. The wrapper is reusable; provider settings are
  per-user.
- **Don't hard-code the Cline binary path.** Resolve at call
  time via `$CLINE_BIN` then `command -v cline`. The wrapper
  must work on any machine, not just the one where it was
  written.
- **Don't skip `export CLINE_NO_AUTO_UPDATE=1`.** Cline's
  binary runs a detached auto-updater on every invocation
  that fetches the latest version from npm, spawns a
  detached `npm install`, and RESTARTS the background hub
  that tracks sessions. With back-to-back Cline invocations
  (the loss-function loop runs many in a row), the hub
  restart races with the next invocation's session lookup
  and produces `"session not found: <id>"` errors with
  286-byte cline.json (only `agent_start` and
  `iteration_start` events, then the error). Cline reads
  `CLINE_NO_AUTO_UPDATE=1` in its own source and skips the
  auto-updater when set. This is internal (no user-facing
  Cline setting changes) but it is the difference between
  5/5 design tasks passing and 3/5 with a 1.6M-token task
  on d1 followed by 4 fail-on-start. See
  `references/cline-v3-invocation.md` for the full story,
  including how to clean up the lingering `cline
  --cline-hub-daemon` processes that accumulate.
