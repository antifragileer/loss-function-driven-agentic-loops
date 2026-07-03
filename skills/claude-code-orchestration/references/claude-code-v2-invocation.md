# Claude Code v2.x invocation reference

Print mode is the only mode the loss-function loop should
use. This reference collects the verified flag combinations
and the gotchas hit while building the reference loop.
Re-verify when Claude Code ships a new major version.

> **Verified against:** Claude Code v2.x. Earlier v1.x
> versions have a different output schema and a separate
> `--output-format` enum — re-verify the parser and the
> wrapper if you target both.

## Verified print-mode invocation

```bash
"$CLAUDE_BIN" "$TASK" \
  --print \
  --output-format json \
  --bare \
  --cwd "$ITER_DIR" \
  --max-turns 30 \
  --allowedTools "Read,Edit,Write,Bash" \
  --append-system-prompt-file "$SYSTEM_PROMPT_FILE" \
  > "$RAW_OUT" 2>"$STDERR_FILE"
```

Why each flag:

- `--print` / `-p` — non-interactive one-shot. Without it
  Claude Code starts the REPL.
- `--output-format json` — machine-readable single object
  on stdout. Without it, the output is human prose.
- `--bare` — skip hooks / plugins / CLAUDE.md discovery
  for deterministic runs.
- `--cwd` — working directory inside Claude Code's
  sandbox. Per-cycle isolation; the loop-driver's
  verifier scripts also read from this dir.
- `--max-turns 30` — cap the agentic loop. Required
  in print mode to prevent runaway cost.
- `--allowedTools` — whitelist. Pick the smallest set
  the cycle needs; the safety sub-loss still greps the
  transcript for `rm -rf`, `chmod 777`, secrets.
- `--append-system-prompt-file` — adds the loop's
  system prompt without replacing Claude Code's default.
  The default prompt has built-in capabilities you do
  **not** want to replace.

## Flag reference (print mode, verified)

| Flag | Type | Effect |
|------|------|--------|
| `--print` / `-p` | bool | One-shot non-interactive. **Required for loops.** |
| `--output-format` | enum | `text` (default, prose), `json` (single object), `stream-json` (NDJSON, for live streaming). |
| `--input-format` | enum | `text` (default) or `stream-json` (bidirectional streaming). |
| `--bare` | bool | Skip hooks, plugins, MCP discovery, CLAUDE.md loading. **Requires `ANTHROPIC_API_KEY` in some configs** — see "Auth gotcha" below. |
| `--cwd` | path | Working directory. Per-cycle isolation. |
| `--max-turns` | int | Agentic loop cap. Print mode only. Minimum 1. |
| `--max-budget-usd` | float | Spend cap in dollars. Print mode only. Minimum ~$0.05. |
| `--fallback-model` | model | Auto-fallback when the default is overloaded. Print mode only. |
| `--model` | enum | `sonnet` / `opus` / `haiku` / full name. **Don't set in the wrapper** — the user picks. |
| `--effort` | enum | `low` / `medium` / `high` / `max` / `auto`. Reasoning depth. Default `auto`. |
| `--allowedTools` | list | Whitelist. Comma or space separated. |
| `--disallowedTools` | list | Blacklist. |
| `--tools` | list | Override the built-in tool set. `""` = none, `"default"` = all, or names. |
| `--append-system-prompt` | text | Add to the default system prompt (preserves built-ins). |
| `--append-system-prompt-file` | path | Add a file's contents to the default system prompt. |
| `--system-prompt` | text | **Replace** the entire system prompt. Usually wrong — prefer `--append-system-prompt`. |
| `--system-prompt-file` | path | **Replace** the system prompt with a file's contents. |
| `--setting-sources` | list | Comma-separated sources to load: `user`, `project`, `local`. Default all three. |
| `--mcp-config` | path | Load MCP servers from a JSON file. Repeatable. |
| `--strict-mcp-config` | bool | Only use MCP servers from `--mcp-config`, ignoring all others. |
| `--add-dir` | list | Grant access to additional working directories. |
| `--no-session-persistence` | bool | Don't save the session to disk. Print mode only. |
| `--resume` | str | Resume a specific session by ID or name. |
| `--continue` / `-c` | bool | Resume the most recent session in this directory. |
| `--fork-session` | bool | When resuming, create a new session ID. |
| `--debug` | str | Enable debug logging with optional filter. |

## Auth gotcha

`--bare` skips OAuth in some configurations. If your loop
relies on `--bare` for determinism, set `ANTHROPIC_API_KEY`
in the environment. Without it, the loop fails with a
confusing auth error (the OAuth flow is not even attempted
in bare mode).

Verification:

```bash
claude --bare --print --output-format json \
  --max-turns 1 "Respond with exactly: AUTH_OK"
```

If you get a JSON result with `"result": "AUTH_OK"`, auth
works. If you get an auth error, set
`export ANTHROPIC_API_KEY=...` (or remove `--bare` and
rely on OAuth).

## Streaming JSON (optional, advanced)

If the loop-driver needs real-time progress (e.g. for a
long-running cycle), use `--output-format stream-json`
with `--verbose` and `--include-partial-messages`. The
output is NDJSON, with `stream_event` entries containing
text deltas. The reference parser at
`scripts/parse_claude_output.py` does **not** yet handle
this format — write a separate stream parser if you need
it.

The loop-driver doesn't currently use streaming — the
batch-parsed single-object output is enough for
loss-function scoring. Add streaming only if a specific
sub-loss needs real-time text.

## Per-cycle isolation

The wrapper creates a fresh `ITER_DIR="${CWD}/.iterations/${CYCLE}"`,
seeds it from the project root (excluding `.iterations/`
and `.git/`), and runs Claude Code with `--cwd "$ITER_DIR"`.
The agent's file edits land in `ITER_DIR`, the verifier
scripts read from `ITER_DIR`, and the cycle summary is
written there too.

This gives per-cycle isolation without `--worktree`. The
`--worktree` flag creates `.claude/worktrees/<name>` which
**does not carry auth**, so a loop using worktrees has to
re-authenticate inside each one.

## What we tried and what broke

| Flag                              | Result                                                                  |
|-----------------------------------|-------------------------------------------------------------------------|
| `claude -q "..."`                 | `-q` is a chat-mode flag, not a print-mode flag. Use `-p` / `--print`. The task is a **positional arg**. |
| `-p` (without `--bare`)           | Loads user's `~/.claude/CLAUDE.md` and any project `CLAUDE.md`. **Predictable cycles need `--bare`** unless you want user-level context. |
| `--output-format text` (default)  | The transcript is human-readable prose, not JSON. The wrapper's parser needs `--output-format json` or `--output-format stream-json`. |
| `--max-turns 0`                   | Rejected; `--max-turns` is at least 1. Pass a real number. |
| `--max-budget-usd 0.01`           | Rejected; the system-prompt cache creation alone costs ~$0.05. Minimum is ~$0.05. |
| `--dangerously-skip-permissions`  | The non-interactive `-p` mode already skips ALL permission dialogs. Adding this flag is a no-op. |
| `claude --worktree feature-x`     | Creates `.claude/worktrees/feature-x` — fine, but the worktree dir doesn't carry the auth. Drop the worktree. |
| `claude --bare` (without `ANTHROPIC_API_KEY`) | Bare mode skips OAuth; loop fails with auth error. Either set the env var or drop `--bare`. |
| `--system-prompt "..."`           | **Replaces** the entire system prompt, losing Claude Code's built-in tool-calling instructions. Use `--append-system-prompt` instead. |
| `claude --help | grep json`       | `--output-format json` is a v2.x flag. v1.x had `--json` (single-dash) and no stream-json. Re-verify the wrapper if you target both. |

## Token accounting caveat

`usage.input_tokens + output_tokens` is the *total tokens
Claude Code sent/received in the API*, including cached
reads. The actual cost is in `total_cost_usd` — use that
for budget-aware loss functions.
`usage.cache_read_input_tokens` is the prompt cache hit
count; high values are a good sign (the prompt is being
reused across cycles, so `--append-system-prompt` is
doing its job).

## Provider matrix (verified-where-marked)

The cells marked "✅ works" / "❌ fails" are from real
runs. Cells marked "untested" are reasonable assumptions
— re-verify before relying on them.

| Provider / model                  | `--print` | `--output-format json` | `--bare` |
|-----------------------------------|-----------|------------------------|----------|
| Claude Sonnet 4 (Anthropic)       | ✅ works  | ✅ works               | ✅ works (with `ANTHROPIC_API_KEY`) |
| Claude Opus 4 (Anthropic)         | (untested) | (assumed works)       | (assumed works) |
| Claude Haiku (Anthropic)          | (untested) | (assumed works)       | (assumed works) |
| Non-Anthropic (Codex, etc.)       | ❌ Claude Code is Anthropic-only — use codex-orchestration for non-Anthropic models |

**Re-verify when changing models.** Claude Code itself is
Anthropic-only; the "provider" question is which Claude
variant you're using, not which vendor.
