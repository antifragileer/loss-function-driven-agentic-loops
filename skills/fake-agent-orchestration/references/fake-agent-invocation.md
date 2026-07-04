# fake-agent CLI invocation reference

The fake agent has no real CLI. The wrapper IS the
agent. This reference documents the wrapper's
deterministic behavior so verifier-projects know exactly
what to expect.

## Verified invocation

```bash
verifiers/fake-agent-wrapper.sh "<task-prompt>" --cwd PATH \
    --timeout 60 --cycle cycle-1 > cycle-summary.json
```

Why each argument:

- `<task-prompt>` — **positional**, NOT a flag. The
  wrapper echoes this into `candidate_text`. The loop
  uses this to test the candidate's legibility (the
  fake candidate is always legible because the task
  prompt is always ≥10 chars).
- `--cwd PATH` — the iteration directory. The wrapper
  writes `candidate.md` here. This is the same cwd
  pattern the real adapters use.
- `--timeout N` — wall-clock cap. Honored via `timeout`
  in the wrapper. Default 60. Should never fire for the
  fake agent.
- `--cycle NAME` — the cycle name. Goes into
  `cycle-summary.json`'s `cycle` field and the
  `raw_output_path`.

## Argument reference

| Arg | Required | Type | Effect |
|---|---|---|---|
| `<task-prompt>` | yes | string (positional) | Echoed into `candidate_text` |
| `--cwd PATH` | yes | path | Iteration directory; wrapper writes `candidate.md` here |
| `--timeout N` | no | int | Wall-clock cap in seconds (default 60) |
| `--cycle NAME` | no | string | Cycle name (default `cycle-0`) |

## What the wrapper does NOT do

- No `--model`, no `--provider`, no `--allowedTools`,
  no `--thinking`. The fake agent has no model.
- No `--bare`, no `--print`, no `--format`. There's no
  real CLI to invoke.
- No environment reads except `cwd` and the task
  prompt. No `~/.claude/`, no `~/.cline/`, no
  `~/.opencode/`. The fake agent doesn't load any
  agent config.

## Why the API surface is so small

The wrapper's job is to **drop into the loop's wrapper
contract** without changing the loop-driver. The
contract requires only:

1. A positional `TASK` arg
2. `--cwd`, `--timeout`, `--cycle` flags
3. JSON output on stdout with the 8 required keys
4. Exit 0 on success, non-zero on wrapper-level failure

Anything beyond that is decoration. The fake wrapper
intentionally exposes no knobs.
