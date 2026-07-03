# Codex CLI invocation reference

`codex exec` is the only entry point the loss-function
loop should use. This reference collects the verified flag
combinations and the gotchas hit while building the
reference loop. Re-verify when Codex ships a new major
version.

> **Verified against:** Codex CLI v1.x. Earlier
> alphas/RCs may have different event names. The reference
> parser at `scripts/parse_codex_output.py` handles the v1.x
> event shape (`thread.started`, `turn.started`,
> `item.started`, `item.completed`, `turn.completed`,
> `error`).

## Verified exec-mode invocation

```bash
"$CODEX_BIN" exec \
  --json \
  --full-auto \
  --sandbox workspace-write \
  --cd "$ITER_DIR" \
  "$TASK" \
  > "$RAW_OUT" 2>"$STDERR_FILE"
```

Why each flag:

- `exec` — subcommand. One-shot non-interactive. Without
  it Codex starts the interactive TUI.
- `--json` — NDJSON events to stdout. Without it the
  output is human prose.
- `--full-auto` — auto-approve tool calls within the
  sandbox. Use `--yolo` to drop the sandbox entirely
  (only with separate safety layer).
- `--sandbox workspace-write` — the default sandbox. The
  agent can write to `ITER_DIR` but not outside it.
  Switch to `danger-full-access` in container contexts
  (see "Sandbox gotcha" below).
- `--cd` — working directory. Per-cycle isolation; the
  loop-driver's verifier scripts also read from this dir.
- `$TASK` — positional, after the flags. **No `-q`.**

## Flag reference (exec mode, verified)

| Flag | Type | Effect |
|------|------|--------|
| `--json` | bool | Emit NDJSON events to stdout. **Required for loops.** |
| `--full-auto` | bool | Auto-approve within the sandbox. Loop-friendly default. |
| `--yolo` | bool | Drop the sandbox entirely. Most dangerous; use only with separate safety. |
| `--sandbox` | enum | `workspace-write` (default) or `danger-full-access`. |
| `--cd` | path | Working directory. Per-cycle isolation. |
| `--model` | model | `gpt-5`, `gpt-4o`, etc. **Don't set in the wrapper** — the user picks via `~/.codex/config.toml`. |
| `--profile` | name | Load a named profile from `~/.codex/config.toml`. |
| `--config` | key=val | Override a single config value. Repeatable. |
| `--add-dir` | list | Grant access to additional directories. |
| `--skip-git-repo-check` | bool | Run even outside a git repo. **Not recommended** — many Codex features depend on git. |

## Sandbox gotcha

In container / service contexts (typical when Codex is
invoked from inside another agent or a CI runner), the
default workspace-write sandbox may fail with errors like:

```
setting up uid map: Permission denied
loopback: Failed RTM_NEWADDR: Operation not permitted
```

These are bubblewrap / user-namespace errors. The fix is
`--sandbox danger-full-access`:

```bash
codex exec --json --sandbox danger-full-access \
  --cd "$ITER_DIR" "$TASK"
```

This disables Codex's sandbox. Compensate with process
boundaries: explicit `--cd`, clean git status before
launch, narrow task prompts, `git diff` review between
cycles, targeted tests, and human / agent confirmation
before committing broad changes.

If the loop is running in a user shell (the user's own
terminal, not a service), the default workspace-write
sandbox works.

## Git repo requirement

Codex **refuses to run outside a git repository.** The
wrapper ensures `ITER_DIR` is a git repo. The seeding
logic:

```bash
cd "$ITER_DIR" && \
  [ -d .git ] || (git init -q && \
                  git config user.email "loop@local" && \
                  git config user.name "loop" && \
                  git add -A && \
                  git commit -q -m "seed" || true)
```

This is the single most-skipped step when porting a
Cline or Claude Code wrapper to Codex. Without it the
loop fails with "Not inside a Git repository".

## Per-cycle isolation

The wrapper creates a fresh
`ITER_DIR="${CWD}/.iterations/${CYCLE}"`, seeds it from the
project root (excluding `.iterations/` and `.git/`), and
runs Codex with `--cd "$ITER_DIR"`. The agent's file
edits land in `ITER_DIR`, the verifier scripts read from
`ITER_DIR`, and the cycle summary is written there too.

This gives per-cycle isolation without worktrees. Codex
doesn't ship with worktree support, so `--cd $ITER_DIR` is
the only isolation primitive.

## What we tried and what broke

| Flag                              | Result                                                                  |
|-----------------------------------|-------------------------------------------------------------------------|
| `codex -p "..."`                  | `-p` is not a Codex flag. The one-shot entry point is `codex exec` (subcommand). |
| `codex exec "..."` (no `--json`)  | Human-readable transcript, not parseable. The wrapper needs `--json`. |
| `codex exec --full-auto` outside git | Codex refuses: "Not inside a Git repository". The wrapper must `git init` `ITER_DIR`. |
| `codex exec --yolo`               | No sandbox, no approvals — fastest but most dangerous. Use only with separate safety. |
| `codex exec --sandbox workspace-write` (in service context) | May fail with `uid map: Permission denied` or `RTM_NEWADDR: Operation not permitted`. Use `--sandbox danger-full-access`. |
| `codex --worktree`                | No such flag. Per-cycle `--cd` is the right isolation. |
| `codex --model gpt-5`             | Don't set in the wrapper. The user picks the model. |
| `codex review`                    | PR review subcommand — fine for one-off reviews, NOT for loop iterations. |

## Output schema (NDJSON, verified)

`codex exec --json` emits NDJSON events:

```jsonl
{"type": "thread.started", "thread_id": "..."}
{"type": "turn.started"}
{"type": "item.started", "item": {"type": "agent_message", "id": "..."}}
{"type": "item.completed", "item": {"type": "agent_message", "text": "I'll start by..."}}
{"type": "item.started", "item": {"type": "command_execution", "id": "..."}}
{"type": "item.completed", "item": {"type": "command_execution", "command": "ls -la", "exit_code": 0}}
{"type": "turn.completed", "usage": {"input_tokens": 100, "output_tokens": 50, "cached_input_tokens": 80}, "model": "gpt-5", "stop_reason": "stop"}
```

Key event types:

- `thread.started` — emits a `thread_id`.
- `turn.started` — a new turn begins.
- `item.started` / `item.completed` — per-item lifecycle.
  Items include:
    - `agent_message` — the model's text.
    - `reasoning` — reasoning text (for o-series).
    - `command_execution` — shell command + exit code.
    - `file_change` — file write/edit.
- `turn.completed` — turn summary with `usage` and
  `stop_reason`.
- `error` — non-recoverable failure.

The reference parser at
`scripts/parse_codex_output.py` extracts the final
agent message, the cumulative token usage, and a
tool-call summary. The schema has been stable across
v1.x — re-verify the parser if you upgrade to v2.x.

## Token accounting caveat

`usage.input_tokens + output_tokens` is the *total tokens
Codex sent/received in the API*. Codex's pricing is
different for o-series vs gpt-5 vs gpt-4 — use
`modelUsage` (when present in `turn.completed`) to break
out per-model cost. The reference parser captures
`usage.cached_input_tokens` separately; high values mean
the prompt cache is working.

## Provider matrix (verified-where-marked)

The cells marked "✅ works" / "❌ fails" are from real
runs. Cells marked "untested" are reasonable assumptions
— re-verify before relying on them.

| Provider / model                  | `exec --json` | `--full-auto` | `--sandbox workspace-write` |
|-----------------------------------|---------------|---------------|------------------------------|
| GPT-5 (OpenAI)                    | ✅ works      | ✅ works      | ✅ works                     |
| GPT-4o (OpenAI)                   | (untested)    | (assumed works) | (assumed works)            |
| o3 / o4-mini (OpenAI)             | (untested)    | (assumed works) | (assumed works)            |
| Non-OpenAI (Claude, etc.)         | ❌ Codex is OpenAI-only — use claude-code-orchestration for Anthropic models |

**Re-verify when changing models.** Codex is
OpenAI-only; the "provider" question is which OpenAI
variant you're using, not which vendor.
