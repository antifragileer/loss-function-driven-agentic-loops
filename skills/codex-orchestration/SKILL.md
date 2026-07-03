---
name: codex-orchestration
description: |
  How to drive the OpenAI Codex CLI as the coding agent
  inside a loss-function-driven loop. The driver (Hermes
  or any orchestrator) owns the loop, the loss function,
  and the verifier runs. Codex owns the model call, the
  per-iteration context, the file edits, and the test
  runs. Load this skill whenever launching, monitoring,
  or interrupting a Codex session from inside a
  loss-function-driven loop, and when building a Codex
  wrapper script — the verified exec-mode flags, the
  JSON event schema, the parser, and the contract the
  wrapper must satisfy all live here.
version: 1.0.0
author: open source
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [codex, openai, agent-client-protocol, agent-orchestration, coding-agents]
    related_skills: [cline-orchestration, claude-code-orchestration, hermes-agent-orchestration, opencode-orchestration, harness-engineering, loss-function-design]
---

# Codex Orchestration

This skill describes how to drive **OpenAI Codex CLI** as the
coding agent inside a loss-function-driven loop. The
pattern is **agent-agnostic at the driver level** — Hermes
is the driver in the reference build, but any orchestrator
(a shell script, CI runner, another agent) that can spawn a
subprocess and read JSON can use the same wrapper contract.

The split:

- **The driver owns:** the loop, the loss function, the
  verifier runs, the human-facing surface, the stop
  criterion, the budget.
- **Codex owns:** the model call, the tool surface, the
  per-iteration context, the file edits, the test runs
  inside its sandbox.

## Why Codex

- Native tool surface (file edit, command run, browser,
  MCP).
- **OpenAI-locked**: GPT-5, GPT-4.x, o-series. The driver
  never sets the model — Codex's own auth does.
- `codex exec` for one-shot non-interactive runs. **This
  is the mode the loop should use.**
- `--json` flag emits NDJSON events (item.completed,
  item.started, etc.) for headless integration.
- `--full-auto` for sandboxed auto-approval (the
  loop-friendly mode).
- `--sandbox danger-full-access` when running inside a
  service / container context where the default sandbox
  fails (see "Sandbox gotcha" below).

## Codex requires a git repo

Codex **refuses to run outside a git repository.** The
wrapper ensures `ITER_DIR` is a git repo (or the cycle
prompts the agent to git-init if it's a fresh one). The
per-cycle iteration directory is seeded by the wrapper,
which also `git init`s it.

## Locating the `codex` binary

The wrapper resolves the binary at call time. The resolution
order is:

1. The `$CODEX_BIN` environment variable, if set.
2. `$(command -v codex)` — whatever's on `PATH`.
3. Bail with exit code 3 and a clear error.

Same pattern as the Cline and Claude Code wrappers. **Do
not hardcode an absolute path** in the wrapper.

## Working invocation (exec mode, JSON output)

```bash
"$CODEX_BIN" exec \
  --json \
  --full-auto \
  --cd "$ITER_DIR" \
  "$TASK" \
  > "$RAW_OUT" 2>"$STDERR_FILE"
```

Where:

- `TASK` is the cycle prompt (positional, after the flags).
- `ITER_DIR` is a fresh per-cycle directory that the
  wrapper has `git init`ed.
- `--json` emits NDJSON events to stdout (one event per
  line).
- `--full-auto` is the loop-friendly sandboxed
  auto-approval. The alternative is `--yolo` (no
  sandbox, no approvals) but that's too dangerous for
  most loops.

## What we tried and what broke

| Flag                              | Result                                                                  |
|-----------------------------------|-------------------------------------------------------------------------|
| `codex -p "..."`                  | `-p` is not a Codex flag. The one-shot entry point is `codex exec` (subcommand), not `-p`. |
| `codex exec "..."` (no `--json`)  | Human-readable transcript, not parseable. The wrapper needs `--json` to get NDJSON events. |
| `codex exec --full-auto` outside git | Codex refuses to run. **The wrapper must `git init` `ITER_DIR` first.** |
| `codex exec --yolo`               | No sandbox, no approvals — fastest but most dangerous. Use only when you fully trust the candidate. |
| `codex exec --sandbox workspace-write` (in a service context) | The default sandbox may fail in container / service contexts (bubblewrap / user-namespace errors). Use `--sandbox danger-full-access` and rely on process boundaries. |
| `codex exec --json --full-auto "..."` | Works. The wrapper's reference invocation. |
| `codex review`                    | PR review subcommand — fine for one-off reviews, NOT for loop iterations. |
| `--model gpt-5` in the wrapper    | Don't set `--model` in the wrapper. The user picks the model via Codex auth / `~/.codex/config.toml`. |
| `codex --worktree`                | No such flag. Codex doesn't ship with worktree support; per-cycle `--cd` is the right isolation. |

## The right pattern

- **`codex exec` is mandatory** for non-interactive work.
  The interactive TUI is for human-driven exploration.
- **`--json` is mandatory** for the wrapper to parse
  events. Without it the output is prose.
- **`--full-auto` is the right auto-approval mode** for
  most loops. `--yolo` removes the sandbox entirely —
  only use it when you have a separate safety layer
  (e.g. a docker container that resets between cycles).
- **`--sandbox danger-full-access` is needed in service /
  container contexts** where the default workspace-write
  sandbox fails. See "Sandbox gotcha" below.
- **Provider config is sacred.** Codex picks the model
  from its own auth (`codex auth status` or
  `~/.codex/config.toml`). The wrapper must NEVER pass
  `--model` unless you are specifically testing model
  drift.
- **Per-cycle isolation** comes from `--cd $ITER_DIR`
  where `ITER_DIR` is a fresh per-cycle git-initialized
  directory, not from any worktree flag.
- **The wrapper `git init`s `ITER_DIR` if it isn't
  already a repo.** This is the single most-skipped
  step when porting a Cline or Claude Code wrapper to
  Codex.

## Output schema (NDJSON, verified)

`codex exec --json` emits NDJSON events. Each line is a
JSON object. The reference parser at
`scripts/parse_codex_output.py` extracts the final
`item.completed` agent message and the
`turn.completed` usage summary.

Key event types:

- `thread.started` — emits a `thread_id` at the start.
- `turn.started` — a new turn begins.
- `item.started` / `item.completed` — per-item lifecycle.
  Items include `agent_message` (the model's text), 
  `command_execution`, `file_change`, `reasoning`, etc.
- `turn.completed` — turn summary with `usage` (token
  counts) and stop reason.
- `error` — non-recoverable failure.

The schema is version-pinned in the parser. If Codex
changes event names, edit the parser, not the wrapper.

## Sandbox gotcha

When Codex runs inside a **container / service context**
(typical for `terminal(command=..., background=true)`
from inside another agent), the default workspace-write
sandbox may fail with errors like:

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

This disables Codex's sandbox entirely. Compensate with
process boundaries: explicit `--cd`, clean git status
before launch, narrow task prompts, `git diff` review
between cycles, targeted tests, and human / agent
confirmation before committing broad changes.

If the loop is running in a user shell (the user's own
terminal, not a service), the default sandbox works.

## Smoke test

The minimal smoke test:

```bash
mkdir -p /tmp/codex-smoke && cd /tmp/codex-smoke && \
  git init && \
  codex exec --json --full-auto \
  "Respond with exactly: CODEX_SMOKE_OK"
```

Expected: NDJSON on stdout ending with an event whose
`item.agent_message` field contains `CODEX_SMOKE_OK`. Exit
code 0.

If the JSON does not parse, Codex likely isn't
authenticated — check `OPENAI_API_KEY` or `codex auth
status`.

## Drop-in substitution

This skill is a sibling of `cline-orchestration` and
`claude-code-orchestration`. The harness-scaffold and
loop-driver skills are **runtime-agnostic**. They invoke
whatever wrapper is at `verifiers/<runtime>-wrapper.sh`.
The user passes `--runtime {cline,claude-code,codex,…}` to
`harness-scaffold` to generate the correct wrapper.

The 4 invariants from `compatibility.md` hold here:

1. `parse_codex_output.py` emits JSON in the same shape as
   `parse_cline_output.py`.
2. The wrapper accepts a positional `TASK` plus
   `--cwd PATH`, `--timeout N`, `--cycle NAME` and writes
   the parsed JSON to stdout.
3. The `codex-skills-dir.sh` instrument prints the agent's
   skills directory to stdout.
4. The wrapper exits non-zero on missing binary / bad
   args, exits 0 on successful agent run, never blocks
   longer than `--timeout`.

## Common pitfalls

1. **Forgetting `git init`.** Codex refuses to run outside
   a git repo. The wrapper must ensure `ITER_DIR` is a
   repo.
2. **Forgetting `--json`.** Without it the output is
   human prose, unparseable.
3. **Using `--yolo` in production.** `--yolo` removes the
   sandbox. Use `--full-auto` for normal loops.
4. **Sandbox failure in containers.** Switch to
   `--sandbox danger-full-access` and rely on process
   boundaries for safety.
5. **Setting `--model` in the wrapper.** Don't. The user
   picks the model via Codex auth. The loop's drift
   sub-loss catches unwanted drift.
6. **Passing the task via `-q`.** There is no `-q`. The
   task is a positional argument after the flags.
7. **Running the TUI in non-pty mode.** The TUI requires
   `pty=true`; `codex exec` does NOT need pty.

## Verification checklist

- [ ] Wrapper resolves `codex` via `$CODEX_BIN` →
      `command -v codex` → bail.
- [ ] Wrapper `git init`s `ITER_DIR` if it isn't already
      a repo.
- [ ] Wrapper uses `codex exec --json --full-auto`.
- [ ] Wrapper writes parsed JSON to stdout, not the
      transcript.
- [ ] Wrapper exits non-zero on missing binary, zero on
      successful agent run.
- [ ] Wrapper is wrapped in `timeout` and kills Codex if
      it overruns.
- [ ] `codex-skills-dir.sh` prints the user's
      `~/.codex/skills/` (or the configured skills dir).
- [ ] No absolute paths, no per-user config baked in.
