# OpenCode CLI invocation reference

`opencode run` is the only entry point the loss-function
loop should use. This reference collects the verified
flag combinations and the gotchas hit while building the
reference loop. Re-verify when OpenCode ships a new
major version.

> **Verified against:** OpenCode v1.x. Earlier betas
> had different event names; the reference parser at
> `scripts/parse_opencode_output.py` handles the v1.x
> `--format json` single-object output.

## Verified run-mode invocation

```bash
"$OPENCODE_BIN" run \
  --format json \
  --model "$OPENCODE_MODEL" \
  "$TASK" \
  > "$RAW_OUT" 2>"$STDERR_FILE"
```

Why each flag:

- `run` — subcommand. One-shot non-interactive. Without
  it OpenCode starts the interactive TUI.
- `--format json` — machine-readable single object on
  stdout. Without it the output is human prose.
- `--model` — `provider/model` string. **The user
  configures this via `$OPENCODE_MODEL`; the wrapper
  never hardcodes it.**
- `$TASK` — positional, after the flags. **No `-q`.**

The wrapper `cd`s into `ITER_DIR` before invoking
OpenCode, so the agent's tools operate on the per-cycle
copy of the project.

## Flag reference (run mode, verified)

| Flag | Type | Effect |
|------|------|--------|
| `run` | subcommand | One-shot non-interactive. **Required for loops.** |
| `--format` | enum | `json` (single object), `stream-json` (NDJSON), or default (prose). |
| `--model` | model | `provider/model` string. **Set from `$OPENCODE_MODEL`.** |
| `--thinking` | bool | Show model thinking blocks. Optional. |
| `--variant` | enum | Reasoning effort: `high`, `max`, `minimal`. |
| `--file` / `-f` | path | Attach a file to the message. Repeatable. |
| `--agent` | name | OpenCode agent (build or plan). Default `build`. |
| `--title` | name | Name the session. |
| `--workdir` | path | Agent's working directory. The wrapper uses `cd` instead for shell-script consistency. |
| `--attach` | url | Connect to a running OpenCode server. |
| `--continue` / `-c` | bool | Continue the most recent session. |
| `--session` / `-s` | id | Continue a specific session. |

## Interactive TUI (don't use in loops)

OpenCode's TUI is for human-driven exploration. It
requires `pty=true` and supports commands like
`/compact`, `/model`, etc. The loop should use
`opencode run` instead. If you accidentally invoke the
TUI in non-pty mode, it hangs.

To exit the TUI, use **Ctrl+C** (`\x03`). There is no
`/exit` command — `/exit` opens an agent selector
dialog.

## Per-cycle isolation

The wrapper creates a fresh
`ITER_DIR="${CWD}/.iterations/${CYCLE}"`, seeds it from
the project root (excluding `.iterations/` and `.git/`),
then `cd`s into `ITER_DIR` before invoking OpenCode. The
agent's file edits land in `ITER_DIR`, the verifier
scripts read from `ITER_DIR`, and the cycle summary is
written there too.

This gives per-cycle isolation without worktrees. (OpenCode
supports `--workdir` but the wrapper uses `cd` for
shell-script consistency with the other adapters.)

## What we tried and what broke

| Flag                              | Result                                                                  |
|-----------------------------------|-------------------------------------------------------------------------|
| `opencode -p "..."`               | `-p` is not an OpenCode flag. The one-shot entry point is `opencode run`. |
| `opencode` (interactive TUI)      | Requires `pty=true`. The loop should use `opencode run` instead. |
| `opencode run "..."` (no `--format json`) | Human-readable transcript, not parseable. The wrapper needs `--format json`. |
| `opencode run --format json ...`  | Works. The wrapper's reference invocation. |
| `opencode run --model openrouter/anthropic/claude-sonnet-4 ...` | `provider/model` format. **Don't hardcode in the wrapper** — read `$OPENCODE_MODEL`. |
| `opencode --exit` (no such flag)  | OpenCode has no `--exit` flag. The TUI exits on Ctrl+C. |
| `opencode run --workdir /tmp/foo ...` | `--workdir` sets the agent's working directory. The wrapper uses `cd` for consistency. |
| `opencode -s ses_abc123` (resume) | Resumes a previous session. The loop-driver doesn't use this; each cycle is a fresh session. |

## Output schema (verified)

`opencode run --format json` emits a single JSON object
to stdout:

```json
{
  "result": "<final assistant text>",
  "session_id": "ses_abc123",
  "duration_ms": 10276,
  "usage": {
    "input_tokens": 5,
    "output_tokens": 603,
    "cache_read_tokens": 0
  },
  "model": "openrouter/anthropic/claude-sonnet-4",
  "finish_reason": "completed"
}
```

Key fields:

- `result` — the final assistant text. The loop's
  `candidate_text`.
- `session_id` — OpenCode session ID. Useful for
  debugging (`opencode session list`).
- `duration_ms` — wall-clock duration.
- `usage` — token accounting.
- `model` — `provider/model` string. The parser splits
  this into `provider` and `model` for the shared shape.
- `finish_reason` — `"completed" | "max_iterations" | "error"`.

The reference parser at
`scripts/parse_opencode_output.py` extracts this shape.

## Token accounting caveat

`usage.input_tokens + output_tokens + cache_read_tokens`
is the *total tokens OpenCode sent/received in the API*,
including cache hits. Cost is not part of the standard
output — the loop's `cost` sub-loss is graded 0.0
unless the user provides a custom cost function.

## Provider matrix (verified-where-marked)

The cells marked "✅ works" / "❌ fails" are from real
runs. Cells marked "untested" are reasonable assumptions
— re-verify before relying on them.

| Provider / model                  | `run --format json` | `--model <string>` |
|-----------------------------------|---------------------|---------------------|
| OpenRouter (any model)            | ✅ works            | ✅ works            |
| Anthropic (direct)                | ✅ works            | ✅ works            |
| OpenAI (direct)                   | ✅ works            | ✅ works            |
| Google Gemini                     | (untested)          | (assumed works)     |
| Local models (llama.cpp, etc.)    | (untested)          | (assumed works)     |
| Any OpenAI-compatible endpoint    | (assumed works)     | (assumed works)     |

**OpenCode is provider-agnostic** — the matrix above
documents the *OpenCode plumbing*, not the underlying
provider. The "provider" field in the JSON output is
the prefix of the `provider/model` model string.
