# Hermes Agent invocation reference

`hermes chat --query ...` is the only entry point the
loss-function loop should use. This reference collects
the verified flag combinations and the gotchas hit while
building the reference loop. Re-verify when Hermes ships
a new major version.

> **Verified against:** Hermes Agent v2.x. The
> `--output-format json` flag is a v2.x addition; v1.x
> emitted NDJSON transcripts only.

## Verified chat-mode invocation

```bash
"$HERMES_BIN" chat \
  --query "$TASK" \
  --output-format json \
  --cwd "$ITER_DIR" \
  --max-turns 30 \
  --toolsets "terminal,file" \
  --profile "$HERMES_PROFILE" \
  --yolo \
  --no-session-persistence \
  --source lfd-loop \
  > "$RAW_OUT" 2>"$STDERR_FILE"
```

Why each flag:

- `chat` — subcommand. One-shot non-interactive. Without
  it Hermes starts the interactive REPL.
- `--query` — the cycle prompt. Note: this is `--query`,
  not a positional arg.
- `--output-format json` — machine-readable single
  object on stdout. Without it the output is human
  prose.
- `--cwd` — working directory. Per-cycle isolation; the
  loop-driver's verifier scripts also read from this
  dir.
- `--max-turns 30` — cap the agentic loop.
- `--toolsets` — whitelist. Comma-separated. Default to
  `terminal,file` for the loop minimum.
- `--profile` — named profile to use. Defaults to the
  active profile.
- `--yolo` — skip approval prompts. Required for
  non-interactive loops.
- `--no-session-persistence` — skip writing the session
  to disk. Recommended for loops.
- `--source lfd-loop` — tag the session source for
  filtering in `session_search` (skip LFD cycles in
  manual searches).

## Flag reference (chat mode, verified)

| Flag | Type | Effect |
|------|------|--------|
| `--query` / `-q` | str | The task prompt. Required for one-shot chat. |
| `--output-format` | enum | `text` (default, prose), `json` (single object). |
| `--cwd` | path | Working directory. Per-cycle isolation. |
| `--max-turns` | int | Agentic loop cap. |
| `--toolsets` | list | Comma-separated whitelist. Default: full set. |
| `--profile` | name | Named profile to use. |
| `--yolo` | bool | Skip approval prompts. **Required for loops.** |
| `--no-session-persistence` | bool | Don't save the session. Recommended for loops. |
| `--source` | tag | Tag the session source (e.g. `lfd-loop`). |
| `--worktree` | bool | Run in an isolated git worktree. Carries auth. |
| `--model` | model | Force a model. **Don't set in the wrapper** — user picks. |
| `--provider` | provider | Force a provider. **Don't set in the wrapper.** |
| `--skills` | list | Preload skills. Loop-driver doesn't set this — the loop's candidate is installed at `~/.hermes/profiles/<active>/skills/`. |
| `--reasoning` | enum | `none` / `minimal` / `low` / `medium` / `high` / `xhigh`. Reasoning effort. |
| `--verbose` / `-v` | bool | Verbose output. |
| `--checkpoints` | bool | Enable filesystem checkpoints (`/rollback`). |
| `--pass-session-id` | bool | Include session ID in the system prompt. |

## Auth gotcha

Hermes manages its own credential pool (`hermes auth`).
The wrapper does NOT pass `--api-key` or otherwise touch
auth. If the inner session fails with an auth error, the
user needs to run `hermes auth status` and re-add the
failing provider.

**Per-cycle workdirs do NOT need re-auth.** The wrapper
uses `--cwd $ITER_DIR`, not `--worktree`. The workdir
inherits the active profile's auth.

## When the outer loop IS Hermes

If the outer driver is also Hermes (e.g. you're
orchestrating from a Hermes session), you have two
options:

1. **In-process:** `delegate_task(goal=...)` — the
   subagent gets a fresh conversation, terminal session,
   and toolset. Result re-enters the parent conversation
   when done. This is the recommended path for sub-minute
   subtasks.

2. **Out-of-process:** `terminal(command="hermes chat -q
   '...'", background=True, notify_on_complete=True)` —
   the subagent is a real subprocess. Use for long-running
   cycles. The wrapper script is not needed; the
   loop-driver can call `hermes chat` directly.

In both cases, the loop's candidate skill is installed at
`~/.hermes/profiles/<active>/skills/<artifact>/` and
loaded by the inner session automatically. No
`hermes-agent-skills-dir.sh` script is needed — the
active profile's `skills/` directory is the convention.

## Per-cycle isolation

The wrapper creates a fresh
`ITER_DIR="${CWD}/.iterations/${CYCLE}"`, seeds it from
the project root (excluding `.iterations/` and `.git/`),
and runs Hermes with `--cwd "$ITER_DIR"`. The agent's
file edits land in `ITER_DIR`, the verifier scripts
read from `ITER_DIR`, and the cycle summary is written
there too.

This gives per-cycle isolation without `--worktree`. The
`--worktree` flag is available for stronger isolation
(use it when cycles might step on each other — but the
loop-driver is single-threaded so this is rare).

## What we tried and what broke

| Flag                              | Result                                                                  |
|-----------------------------------|-------------------------------------------------------------------------|
| `hermes -p "..."`                 | `-p` is not a Hermes flag. The one-shot entry point is `hermes chat --query ...`. |
| `hermes chat "..."` (positional)  | Hermes CLI expects `--query` for chat mode. The positional form is for the interactive REPL. |
| `hermes chat --query "..."` (no `--output-format json`) | Transcript is human prose. The wrapper's parser needs `--output-format json`. |
| `hermes chat --query "..." --worktree` | Creates an isolated worktree — **fine, and the worktree carries auth**. Use for stronger isolation than `--cwd`. |
| `hermes chat --query "..." --yolo` | Skip approval prompts. Required for non-interactive loops. |
| `hermes chat --query "..." --model gpt-5` | Don't set `--model` in the wrapper. The user picks. |
| `hermes chat --query "..." --provider openai` | Don't set `--provider` in the wrapper. The user picks. |
| `hermes --bare`                   | No `--bare` flag. Use `--toolsets ""` to disable built-in tools. |
| `hermes chat --query "..."` (no `--yolo`, default profile) | Inner session prompts for approval on shell commands and hangs the loop. **Always pass `--yolo`** unless the profile has `approvals.mode: off`. |

## Output schema (verified)

`hermes chat --output-format json` emits a single JSON
object to stdout:

```json
{
  "result": "<final assistant text>",
  "session_id": "20260225_143052_a1b2c3",
  "turns": 3,
  "duration_ms": 10276,
  "usage": {
    "input_tokens": 5,
    "output_tokens": 603,
    "cache_read_tokens": 0,
    "cost_usd": 0.0787
  },
  "model": "anthropic/claude-sonnet-4",
  "provider": "openrouter",
  "finish_reason": "completed"
}
```

Key fields:

- `result` — the final assistant text. The loop's
  `candidate_text`.
- `session_id` — Hermes session ID. Useful for
  debugging failed cycles (`hermes sessions show`).
- `turns` — agentic loop count. Maps to Cline's
  `iterations`.
- `duration_ms` — wall-clock duration.
- `usage` — token + cost accounting.
- `model` / `provider` — what's actually being used.
- `finish_reason` — `"completed" | "max_turns" | "user_cancelled" | "error"`.

The reference parser at
`scripts/parse_hermes_output.py` extracts this shape.

## Token accounting caveat

`usage.input_tokens + output_tokens + cache_read_tokens`
is the *total tokens Hermes sent/received in the API*,
including cache hits. The cost is in `usage.cost_usd`
when the provider supports cost reporting; otherwise the
loop's `cost` sub-loss is graded 0.0 (no cost data
available).

## Provider matrix (verified-where-marked)

The cells marked "✅ works" / "❌ fails" are from real
runs. Cells marked "untested" are reasonable assumptions
— re-verify before relying on them.

| Provider / model                  | `chat --output-format json` | `--yolo` | `--no-session-persistence` |
|-----------------------------------|------------------------------|----------|------------------------------|
| Anthropic (via OpenRouter)        | ✅ works                     | ✅ works | ✅ works                     |
| Anthropic (direct)                | ✅ works                     | ✅ works | ✅ works                     |
| OpenAI (via OpenRouter)           | ✅ works                     | ✅ works | ✅ works                     |
| OpenAI (direct)                   | ✅ works                     | ✅ works | ✅ works                     |
| Google Gemini                     | (untested)                   | (assumed works) | (assumed works)        |
| Local models (llama.cpp, etc.)    | (untested)                   | (assumed works) | (assumed works)        |

**Hermes is provider-agnostic** — the matrix above
documents the *Hermes plumbing*, not the underlying
provider. The "provider" field in the JSON output is
whatever Hermes is configured to use.
