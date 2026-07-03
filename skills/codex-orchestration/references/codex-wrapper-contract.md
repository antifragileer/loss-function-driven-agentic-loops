# Codex wrapper contract

This is the contract the `codex-wrapper.sh` script must
satisfy. `harness-scaffold` writes a stub from this contract
when the user passes `--runtime codex`. The loop-driver
skill assumes these invariants and does not handle
deviations gracefully.

## Invocation shape

```bash
verifiers/codex-wrapper.sh "<task-prompt>" --cwd PATH \
    --timeout 600 --cycle cycle-1 > cycle-summary.json
```

Arguments:

- `<task-prompt>` — **positional**, NOT `-q`. Codex has no
  `-q`; the task is always a positional argument after
  the flags.
- `--cwd PATH` — the iteration directory. Wrapper seeds it
  with the project source AND `git init`s it (Codex
  refuses to run outside a git repo).
- `--timeout N` — wall-clock cap in seconds. Wrapper wraps
  Codex in `timeout` and SIGKILLs on overrun.
- `--cycle NAME` — used to name the per-iteration output
  files. Default: `cycle-0`.
- `--sandbox MODE` — `workspace-write` (default),
  `danger-full-access`. Pass `danger-full-access` if the
  loop is running in a container / service context.
- `--full-auto` — auto-approve in the sandbox. Default
  true. Use `--no-full-auto` to require per-tool approval
  (rare for loops).

Exit codes:

- `0` — task completed (any finish_reason, including
  non-success ones — the loop-driver's sub-losses handle
  the gradient)
- `1` — Codex ran but emitted malformed JSON
- `2` — usage error (missing args)
- `3` — Codex binary not found

## What the wrapper does

1. Resolve `codex` via `$CODEX_BIN` → `command -v codex` →
   bail.
2. Validate args (task non-empty, cwd exists, cycle set).
3. Seed `ITER_DIR="${CWD}/.iterations/${CYCLE}"` from
   `$CWD` (per-cycle isolation, same shape as the Cline
   wrapper). **`git init` the dir if it isn't already a
   repo.**
4. Run:
   ```bash
   timeout "$TIMEOUT" \
     "$CODEX_BIN" exec \
       --json \
       --full-auto \
       --sandbox "$SANDBOX" \
       --cd "$ITER_DIR" \
       "$TASK" \
       > "$RAW_OUT" 2>"$STDERR_FILE"
   ```
5. Parse `$RAW_OUT` with `parse_codex_output.py` and write
   the shared-shape JSON to stdout.

## What the wrapper does NOT do

- It does **not** set `--model`. The user picks the model
  via Codex auth / `~/.codex/config.toml`. The
  loop-driver's `drift` sub-loss catches unwanted drift.
- It does **not** watch for permission dialogs. `--full-auto`
  in the workspace-write sandbox approves in-sandbox tool
  calls automatically. The safety sub-loss in
  `loss-function-design` still greps the transcript for
  dangerous shell patterns.

## Example output

A successful cycle:

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 14,
  "codex_duration_ms": 12340,
  "tokens": 18900,
  "model": "gpt-5",
  "provider": "openai",
  "candidate_text": "Created hello.txt with content 'hello world'.",
  "tool_calls": [
    {
      "name": "command_execution",
      "args": {"command": "printf 'hello world' > hello.txt"}
    }
  ],
  "finish_reason": "stop",
  "iterations": 2,
  "raw_output_path": "<CWD>/.iterations/cycle-1/codex.json"
}
```

A failure cycle (sandbox refusal):

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 8,
  "codex_duration_ms": 7821,
  "tokens": 0,
  "model": "gpt-5",
  "provider": "openai",
  "candidate_text": "I can't run that command under the workspace-write sandbox.",
  "tool_calls": [],
  "finish_reason": "error",
  "iterations": 0,
  "raw_output_path": "<CWD>/.iterations/cycle-1/codex.json"
}
```

The wrapper exits 0 even on agent failure — the loop's
sub-losses grade it. The wrapper exits non-zero only on
wrapper-level problems (missing binary, bad args, parse
error, `git init` failure).

## Git initialization

If `ITER_DIR` is not a git repo, the wrapper runs:

```bash
cd "$ITER_DIR" && git init -q && git config user.email "loop@local" && \
  git config user.name "loop" && \
  (git add -A && git commit -q -m "seed" || true)
```

Codex uses the git history for safety. Without an initial
commit, some Codex versions refuse to operate on a fresh
uncommitted tree.
