# OpenCode wrapper contract

This is the contract the `opencode-wrapper.sh` script
must satisfy. `harness-scaffold` writes a stub from this
contract when the user passes `--runtime opencode`. The
loop-driver skill assumes these invariants and does not
handle deviations gracefully.

## Invocation shape

```bash
verifiers/opencode-wrapper.sh "<task-prompt>" --cwd PATH \
    --timeout 600 --cycle cycle-1 > cycle-summary.json
```

Arguments:

- `<task-prompt>` — **positional**, NOT `-q`. OpenCode
  has no `-q`; the task is always a positional argument
  after the flags.
- `--cwd PATH` — the iteration directory. Wrapper seeds it
  with the project source (per-cycle isolation).
- `--timeout N` — wall-clock cap in seconds. Wrapper wraps
  OpenCode in `timeout` and SIGKILLs on overrun.
- `--cycle NAME` — used to name the per-iteration output
  files. Default: `cycle-0`.
- `--model MODEL` — `provider/model` string. Default to
  `$OPENCODE_MODEL` env var if set, else fail with a
  clear error (the user must configure their model).

Exit codes:

- `0` — task completed (any finish_reason, including
  non-success ones — the loop-driver's sub-losses handle
  the gradient)
- `1` — OpenCode ran but emitted malformed JSON
- `2` — usage error (missing args, missing model)
- `3` — OpenCode binary not found

## What the wrapper does

1. Resolve `opencode` via `$OPENCODE_BIN` →
   `command -v opencode` → bail.
2. Resolve model via `--model` flag → `$OPENCODE_MODEL`
   env var → bail with a clear "no model configured" error.
3. Validate args (task non-empty, cwd exists, cycle set).
4. Seed `ITER_DIR="${CWD}/.iterations/${CYCLE}"` from
   `$CWD` (per-cycle isolation, same shape as the Cline
   wrapper).
5. Run:
   ```bash
   timeout "$TIMEOUT" \
     "$OPENCODE_BIN" run \
       --format json \
       --model "$OPENCODE_MODEL" \
       "$TASK" \
       > "$RAW_OUT" 2>"$STDERR_FILE"
   ```
   from inside `ITER_DIR` (`cd "$ITER_DIR"` first).
6. Parse `$RAW_OUT` with `parse_opencode_output.py` and
   write the shared-shape JSON to stdout.

## What the wrapper does NOT do

- It does **not** hardcode a model. The model comes
  from `--model` or `$OPENCODE_MODEL`. The loop-driver's
  `drift` sub-loss catches unwanted drift.
- It does **not** set a provider. The provider is part
  of the `provider/model` string in `$OPENCODE_MODEL`.

## Example output

A successful cycle:

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 12,
  "opencode_duration_ms": 10276,
  "tokens": 25579,
  "model": "openrouter/anthropic/claude-sonnet-4",
  "provider": "openrouter",
  "candidate_text": "Created hello.txt with content 'hello world'.",
  "tool_calls": [],
  "finish_reason": "completed",
  "iterations": 3,
  "raw_output_path": "<CWD>/.iterations/cycle-1/opencode.json"
}
```

A failure cycle (max-iterations hit):

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 600,
  "opencode_duration_ms": 599870,
  "tokens": 180000,
  "model": "openrouter/anthropic/claude-sonnet-4",
  "provider": "openrouter",
  "candidate_text": "I wasn't able to finish the task in 30 iterations…",
  "tool_calls": [],
  "finish_reason": "max_iterations",
  "iterations": 30,
  "raw_output_path": "<CWD>/.iterations/cycle-1/opencode.json"
}
```

The wrapper exits 0 even on agent failure — the loop's
sub-losses grade it. The wrapper exits non-zero only on
wrapper-level problems (missing binary, bad args, missing
model, parse error).
