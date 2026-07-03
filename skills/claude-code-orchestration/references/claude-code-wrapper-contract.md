# Claude Code wrapper contract

This is the contract the `claude-code-wrapper.sh` script must
satisfy. `harness-scaffold` writes a stub from this contract
when the user passes `--runtime claude-code`. The loop-driver
skill assumes these invariants and does not handle deviations
gracefully.

## Invocation shape

```bash
verifiers/claude-code-wrapper.sh "<task-prompt>" --cwd PATH \
    --timeout 600 --cycle cycle-1 > cycle-summary.json
```

Arguments:

- `<task-prompt>` — **positional**, not `-q`. The Claude
  Code `-q` flag does not exist on the CLI; the task is
  always a positional argument.
- `--cwd PATH` — the iteration directory. Wrapper seeds it
  with the project source (per-cycle isolation).
- `--timeout N` — wall-clock cap in seconds. Wrapper wraps
  Claude Code in `timeout` and SIGKILLs on overrun.
- `--cycle NAME` — used to name the per-iteration output
  files. Default: `cycle-0`.
- `--max-turns N` — passed through to Claude Code. Default
  to 30 in the wrapper; user can override.
- `--allowedTools LIST` — comma-separated. Default
  `Read,Edit,Write,Bash` (the loop minimum).

Exit codes:

- `0` — task completed (any subtype, including non-success
  ones — the loop-driver's sub-losses handle the gradient)
- `1` — Claude Code ran but emitted malformed JSON
- `2` — usage error (missing args)
- `3` — Claude Code binary not found

## What the wrapper does

1. Resolve `claude` via `$CLAUDE_BIN` → `command -v claude`
   → bail.
2. Validate args (task non-empty, cwd exists, cycle set).
3. Seed `ITER_DIR="${CWD}/.iterations/${CYCLE}"` from
   `$CWD` (per-cycle isolation, same shape as the Cline
   wrapper).
4. Run:
   ```bash
   timeout "$TIMEOUT" \
     "$CLAUDE_BIN" "$TASK" \
       --print \
       --output-format json \
       --cwd "$ITER_DIR" \
       --max-turns "$MAX_TURNS" \
       --allowedTools "$ALLOWED_TOOLS" \
       > "$RAW_OUT" 2>"$STDERR_FILE"
   ```
5. Parse `$RAW_OUT` with `parse_claude_output.py` and write
   the shared-shape JSON to stdout (the loop-driver's
   expected input).

## What the wrapper does NOT do

- It does **not** set `--model`. The user picks the model
  via `claude auth status` and Claude Code's own model
  picker. The loop-driver's `drift` sub-loss catches
  unwanted drift.
- It does **not** load `~/.claude/CLAUDE.md` or any
  project `CLAUDE.md`. Drop `--bare` if you want them
  loaded.
- It does **not** watch for permission dialogs. Print mode
  (`-p`) skips them all. The safety sub-loss in
  `loss-function-design` still greps the transcript for
  dangerous shell patterns.

## Example output

A successful cycle:

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 12,
  "claude_duration_ms": 10276,
  "tokens": 25579,
  "cost_usd": 0.0787,
  "model": "claude-sonnet-4-6",
  "provider": "anthropic",
  "candidate_text": "Created hello.txt with content 'hello world'.",
  "tool_calls": [],
  "finish_reason": "success",
  "iterations": 3,
  "raw_output_path": "<CWD>/.iterations/cycle-1/claude.json"
}
```

A failure cycle (max-turns hit):

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 600,
  "claude_duration_ms": 599870,
  "tokens": 180000,
  "cost_usd": 1.24,
  "model": "claude-sonnet-4-6",
  "provider": "anthropic",
  "candidate_text": "I wasn't able to finish the task in 30 turns…",
  "tool_calls": [],
  "finish_reason": "error_max_turns",
  "iterations": 30,
  "raw_output_path": "<CWD>/.iterations/cycle-1/claude.json"
}
```

The wrapper exits 0 even on agent failure — the loop's
sub-losses grade it. The wrapper exits non-zero only on
wrapper-level problems (missing binary, bad args, parse
error).
