# Cline v3.0.34 → v3.0.35 invocation quirks

These are the gotchas hit while building the first end-to-end loss-function wrapper. They are session-specific detail that will rot — re-verify when Cline ships a new version or when switching providers.

> **Verified against:** Cline v3.0.34 / v3.0.35, OpenAI-compatible
> provider (e.g. Kimi Code via `openai-compatible`, Anthropic
> Claude, OpenAI). Earlier Cline versions or different providers
> may emit a different event schema. Re-verify the
> `scripts/parse_cline_output.py` and `cycle.sh` invocation when
> you change either.

> **Schema gotcha (v3.0.34 → v3.0.35):** the v3.0.34 schema table
> listed `event.type == "tool_call"` as a first-class event.
> v3.0.35 dropped that. Tool calls emit as `agent_event` with
> `event.contentType == "input"` and `event.toolName` /
> `event.toolCallId` set. The reference parser
> `scripts/parse_cline_output.py` still checks for `tool_call`
> and silently returns an empty `tool_calls` list. **Until the
> parser is patched, the safety sub-loss's grep-over-tool-args
> (`compute_sub_losses.py:safety_score`) is a no-op** — it sees
> only `run_result.text`, not the actual file-write / shell
> invocations. See "Tool-call events — the gotcha" below for the
> verified shape and the drop-in parser fix.

## Working invocation

```bash
"$CLINE_BIN" "$TASK" \
  --cwd "$ITER_DIR" \
  --auto-approve true \
  --thinking none \
  --json
```

Where `ITER_DIR` is a fresh directory per cycle (the wrapper creates it at `${CWD}/.iterations/${CYCLE}/`).

## What we tried and what broke

| Flag                              | Result                                                                  |
|-----------------------------------|-------------------------------------------------------------------------|
| `cline -q "..."`                  | `error: unknown option '-q'` — no such flag in v3.0.34. Prompt is a **positional arg**. |
| `--auto-approve false`            | Many providers (e.g. the default OpenAI-compatible endpoint) emit `"I'm unable to create the file directly because this session is running non-interactively and file-write tool approval is disabled"`. `--auto-approve true` is required to actually write files non-interactively. |
| `--thinking low / medium / high / xhigh` | Many OpenAI-compatible endpoints reject the reasoning-token request shape. `run_result` shows `finishReason: "error"`, `text: "Invalid request Error"`, 0 tokens. `--thinking none` is the only level that works reliably across providers. |
| `--worktree`                      | The worktree dir doesn't carry `cline auth`, so re-authentication is required inside the worktree. Per-cycle directory already gives isolation; drop `--worktree`. |
| `cline -q -q "..."`               | n/a, the first `-q` already failed. |

## The right pattern

- **Provider config is sacred.** Whatever `cline auth` selected (provider + model) is the source of truth. The wrapper must NEVER pass `--provider` or `--model`. Override only at the model layer (re-run `cline auth`), never in the wrapper.
- **`--auto-approve true` is mandatory** for non-interactive file work. Safety is NOT enforced by per-tool approval — it's enforced by a separate grep over the cline transcript (`cline.json`) looking for `rm -rf`, `chmod 777`, secret-leak patterns, etc. The safety sub-loss in `loss-function-design` owns this.

## The detached auto-updater (and the hub-restart race)

Cline runs a **detached auto-updater on every invocation**. It
fetches the latest version from npm, spawns a detached
`npm install`, and **restarts the background hub** that
tracks sessions. This is internal to the Cline binary; there
is no user-facing setting that disables it, but Cline reads
the `CLINE_NO_AUTO_UPDATE=1` env var in its own source and
returns early when set.

**The race:** when the loop driver invokes Cline
back-to-back (the LFD system verifier's design set runs 5
Cline invocations in a row), the auto-updater on invocation
N can restart the hub while invocation N+1 is looking up
its session id in the hub. The new session id is
timestamp-based (`<unix_ms>_<random>`), so the next
invocation's id is a brand-new value the hub has never seen.
The result is:

```
{"ts":"...","type":"error","message":"session not found: 1783127859213_ni0ah"}
```

with a 286-byte cline.json (only `agent_start` and
`iteration_start` events, then the error). This is **not a
Cline bug** — it's the documented behavior of Cline's
`SessionNotFoundError` when the hub's state is wiped
mid-invocation. Reproduced in our verifier with 3-5
back-to-back invocations; mitigated by `CLINE_NO_AUTO_UPDATE=1`.

**The fix (also applied in the LFD system's reference wrapper):**

```bash
export CLINE_NO_AUTO_UPDATE=1
"$CLINE_BIN" "$TASK" --cwd "$ITER_DIR" --auto-approve true \
  --thinking none --json
```

If you are writing your own Cline wrapper for a different
loop driver and you do multiple Cline invocations in the
same process, set this env var. Without it, the second and
later invocations will see `SessionNotFoundError` roughly
half the time. The user explicitly requested we not change
any user-facing Cline settings; this is an internal env-var
hook that Cline checks before running the auto-updater, so
it is the right level of intervention.

The auto-updater also leaves **lingering hub-daemon
processes** (`cline --cline-hub-daemon --cwd ...`) after
each invocation, because the hub is started in detached
mode and isn't reaped when the parent exits. After many
runs these accumulate. A `pkill -9 -f cline-hub-daemon`
cleans them up. The hub state is preserved on disk in
`~/.cline/data/` (per `--data-dir`); a fresh hub can read
the existing state when next needed.
- **Per-cycle isolation** comes from `--cwd $ITER_DIR` where `ITER_DIR` is fresh per cycle, not from `--worktree`. The harness's verifier scripts must also read from `$ITER_DIR`, not from any global cache.
- **Capture duration from Cline, not from `date`.** Cline's `run_result.durationMs` is the time Cline spent reasoning. Wrapper wall-clock includes Python parsing and is higher. For budget enforcement, use `durationMs` (Cline's view) AND wall-clock (the user's view) — log both.

## Output schema (v3.0.34 / v3.0.35, verified)

NDJSON, one event per line. The v3.0.34 table listed `event.type`
as one of `iteration_start`, `iteration_end`, `content_start`,
`content_end`, `usage`, `done`, `tool_call`. **The `tool_call` row
is wrong for v3.0.35.** The verified shape:

- `hook_event` — lifecycle (`agent_start`, `agent_end`).
- `agent_event` — per-iteration events. The `event` sub-object
  is one of:
  - `iteration_start` / `iteration_end` (`event.iteration`,
    `event.toolCallCount`, `event.hadToolCalls` on `iteration_end`).
  - `content_start` / `content_end` with `event.contentType` ∈
    `reasoning` (free-form reasoning chunks) | `text` (final
    assistant text) | **`input` (tool-call request — see
    "Tool-call events" below)** | **`output` (tool result — see
    "Tool-call events" below)**.
  - `usage` (per-iteration token counters).
  - `done` (lifecycle).
- `run_result` — the final summary. Fields:
  - `finishReason`: `"completed"` | `"error"` | `"tool_calls"` | `"max_iterations"` | `"user_cancelled"`.
  - `iterations`: int.
  - `usage.{inputTokens,outputTokens,cacheReadTokens,cacheWriteTokens,totalCost}`.
  - `aggregateUsage`: same fields, identical to `usage` in v3.0.34 but named for the loop context.
  - `durationMs`: int.
  - `text`: the final assistant text (often the refusal message when `finishReason == "error"`).
  - `model.{id,provider}`.

### Tool-call events — the gotcha (v3.0.35)

**There is no `event.type == "tool_call"` event in v3.0.35.** Tool
calls emit as `agent_event` with `event.contentType == "input"`,
`event.toolName` (e.g. `read_file`, `write_to_file`,
`replace_in_file`, `execute_command`), and `event.toolCallId`.
The full tool payload is on `event.input` (sometimes a JSON string,
sometimes a dict — coerce defensively). Tool results emit as
`agent_event` with `event.contentType == "output"` and the same
`event.toolCallId`. Per-iteration tool-call counts are also exposed
on `iteration_end` as `event.toolCallCount` (int) and
`event.hadToolCalls` (bool).

**The reference `scripts/parse_cline_output.py` checks for
`event.type == "tool_call"`, which never matches in v3.0.35.** The
parsed `tool_calls` list is therefore always empty, and any safety
sub-loss that greps tool args (`compute_sub_losses.py`'s
`safety_score`) sees zero tool-call content. Until the parser is
patched, treat the safety sub-loss as **text-only on
`run_result.text`**, not on tool args.

Verify the gap with:

```bash
python3 -c "
import json
n_tool_input = n_tool_output = n_iter_end = 0
for line in open('cline.json'):
    e = json.loads(line)
    if e.get('type') != 'agent_event': continue
    ev = e.get('event', {})
    if ev.get('contentType') == 'input' and ev.get('toolName'):
        n_tool_input += 1
    if ev.get('contentType') == 'output' and ev.get('toolName'):
        n_tool_output += 1
    if ev.get('type') == 'iteration_end':
        n_iter_end += 1
print(f'tool_inputs={n_tool_input} tool_outputs={n_tool_output} iter_ends={n_iter_end}')
"
```

If `tool_inputs == 0` but the candidate `text` describes file
edits, **Cline hallucinated the edits** — `finishReason ==
"completed"` and `exit_code == 0` are not evidence of work. This
was the actual failure mode on cycle 1 of the cline-driver-loop
project (2026-07-03): Cline reported "I changed line 11 to
`return total / len(numbers)`" but the file was untouched. **Always
diff the candidate file against the seed** (the file before Cline
ran) before trusting a pass.

### Drop-in parser fix (when the parser file is owned by this project)

Replace the `if isinstance(ev, dict) and ev.get("type") == "tool_call"`
branch in `parse_cline_output.py` with:

```python
if ev.get("contentType") == "input" and ev.get("toolName"):
    inp = ev.get("input")
    if isinstance(inp, str):
        try: inp = json.loads(inp)
        except Exception: inp = {"_raw": inp}
    tool_calls.append({
        "name": ev.get("toolName", ""),
        "args": inp or {},
        "tool_call_id": ev.get("toolCallId", ""),
    })
```

The schema has changed across Cline versions and will change again.
Centralize the parser, not the wrappers.

The parser is at `scripts/parse_cline_output.py`. It pulls the authoritative tokens from `run_result.aggregateUsage` and the candidate text from `run_result.text`. If you change providers and the schema shifts, edit the parser, not every wrapper.

## Token accounting caveat

`aggregateUsage.inputTokens + outputTokens + cacheReadTokens` is the *total tokens Cline saw in the API*, including cache reads. The actual *cost* in tokens you'd pay for depends on the provider's cache pricing. The wrapper reports this sum as `tokens_this_iter` because that's the simplest "did the model see this much" signal. For cost-aware loss functions, replace with the provider's cost formula.

## Provider matrix (verified-where-marked)

The cells below marked "✅ works" / "❌ fails" are from real runs.
Cells marked "untested" are reasonable assumptions — re-verify
before relying on them, since the loop is silently broken when a
provider rejects the request shape (`run_result.text` will say
`"Invalid request Error"` and you'd have to read the full
transcript to notice).

| Provider / model                      | `--thinking none` | `--thinking high` | `--worktree` |
|---------------------------------------|-------------------|-------------------|--------------|
| OpenAI-compatible (e.g. Kimi Code)    | ✅ works          | ❌ Invalid request Error | ❌ re-auth needed |
| Anthropic Claude via Cline            | (untested)        | (assumed works)   | (assumed works) |
| OpenAI GPT via Cline                  | (untested)        | (assumed works)   | (assumed works) |

**Re-verify when changing providers.** The OpenAI-compat quirks
are real: many endpoints reject the reasoning-token request shape
that `--thinking low/medium/high/xhigh` produces. Default to
`--thinking none` unless you have a verified reason to use
otherwise.
