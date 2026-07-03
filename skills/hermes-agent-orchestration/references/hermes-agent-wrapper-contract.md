# Hermes Agent wrapper contract

This is the contract the `hermes-agent-wrapper.sh` script
must satisfy. `harness-scaffold` writes a stub from this
contract when the user passes `--runtime hermes-agent`.
The loop-driver skill assumes these invariants and does
not handle deviations gracefully.

## Invocation shape

```bash
verifiers/hermes-agent-wrapper.sh "<task-prompt>" --cwd PATH \
    --timeout 600 --cycle cycle-1 > cycle-summary.json
```

Arguments:

- `<task-prompt>` — **positional**. The wrapper prepends
  `--query` for `hermes chat`.
- `--cwd PATH` — the iteration directory. The wrapper
  seeds it with the project source (per-cycle isolation)
  and runs Hermes with `--cwd "$ITER_DIR"`.
- `--timeout N` — wall-clock cap in seconds. Wrapper wraps
  Hermes in `timeout` and SIGKILLs on overrun.
- `--cycle NAME` — used to name the per-iteration output
  files. Default: `cycle-0`.
- `--max-turns N` — passed through to Hermes. Default to
  30 in the wrapper; user can override.
- `--toolsets LIST` — comma-separated. Default
  `terminal,file` (the loop minimum).
- `--profile NAME` — Hermes profile to use. Default to
  the active profile (`$HERMES_PROFILE` env or
  `~/.hermes/profiles/default`).
- `--yolo` — skip approval prompts. **Required for
  non-interactive loops** unless the profile has
  `approvals.mode: off` set.

Exit codes:

- `0` — task completed (any finish_reason, including
  non-success ones — the loop-driver's sub-losses handle
  the gradient)
- `1` — Hermes ran but emitted malformed JSON
- `2` — usage error (missing args)
- `3` — Hermes binary not found

## What the wrapper does

1. Resolve `hermes` via `$HERMES_BIN` → `command -v hermes`
   → bail.
2. Validate args (task non-empty, cwd exists, cycle set).
3. Seed `ITER_DIR="${CWD}/.iterations/${CYCLE}"` from
   `$CWD` (per-cycle isolation, same shape as the Cline
   wrapper).
4. Run:
   ```bash
   timeout "$TIMEOUT" \
     "$HERMES_BIN" chat \
       --query "$TASK" \
       --output-format json \
       --cwd "$ITER_DIR" \
       --max-turns "$MAX_TURNS" \
       --toolsets "$TOOLSETS" \
       --profile "$HERMES_PROFILE" \
       --yolo \
       --no-session-persistence \
       --source lfd-loop \
       > "$RAW_OUT" 2>"$STDERR_FILE"
   ```
5. Parse `$RAW_OUT` with `parse_hermes_output.py` and
   write the shared-shape JSON to stdout.

## What the wrapper does NOT do

- It does **not** set `--model` or `--provider`. The
  user picks via `hermes model` and the active profile.
  The loop-driver's `drift` sub-loss catches unwanted
  drift.
- It does **not** persist the inner session. The
  `--no-session-persistence` flag keeps the session DB
  clean.
- It does **not** set `--yolo` only sometimes. Either
  the wrapper always passes `--yolo`, or the profile
  has `approvals.mode: off`. The inner session
  prompting for approval will hang the loop.

## Example output

A successful cycle:

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 12,
  "hermes_duration_ms": 10276,
  "tokens": 25579,
  "model": "anthropic/claude-sonnet-4",
  "provider": "openrouter",
  "candidate_text": "Created hello.txt with content 'hello world'.",
  "tool_calls": [],
  "finish_reason": "completed",
  "iterations": 3,
  "raw_output_path": "<CWD>/.iterations/cycle-1/hermes.json"
}
```

A failure cycle (max-turns hit):

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 600,
  "hermes_duration_ms": 599870,
  "tokens": 180000,
  "model": "anthropic/claude-sonnet-4",
  "provider": "openrouter",
  "candidate_text": "I wasn't able to finish the task in 30 turns…",
  "tool_calls": [],
  "finish_reason": "max_turns",
  "iterations": 30,
  "raw_output_path": "<CWD>/.iterations/cycle-1/hermes.json"
}
```

The wrapper exits 0 even on agent failure — the loop's
sub-losses grade it. The wrapper exits non-zero only on
wrapper-level problems (missing binary, bad args, parse
error).
