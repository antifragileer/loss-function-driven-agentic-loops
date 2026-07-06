# fake-agent wrapper contract

This is the contract the `fake-agent-wrapper.sh` script
must satisfy. The loop-driver and the scaffold assume
these invariants and do not handle deviations
gracefully.

## Invocation shape

```bash
verifiers/fake-agent-wrapper.sh "<task-prompt>" --cwd PATH \
    --timeout 60 --cycle cycle-1 > cycle-summary.json
```

Arguments:

- `<task-prompt>` — **positional**. The wrapper echoes
  this into the `candidate_text` field of the result.
- `--cwd PATH` — the iteration directory. The wrapper
  writes a deterministic `candidate.md` here. **Must
  exist or be creatable.**
- `--timeout N` — wall-clock cap. The fake wrapper is
  instant; the timeout is honored for shape-compatibility
  with the other adapters. Default: 60.
- `--cycle NAME` — used to name the output files.
  Default: `cycle-0`.

Exit codes:

- `0` — always (the fake agent cannot fail)
- `2` — usage error (missing positional TASK, missing
  `--cwd`)
- `3` — wrapper internal error (e.g. cannot write
  `candidate.md` because cwd is read-only)

## What the wrapper does

1. Validate args (`$TASK` non-empty, `$CWD` exists).
2. Compute deterministic output JSON:
   - `tokens`: 0
   - `duration_ms`: 0
   - `candidate_text`: the echoed task prompt
   - `model`: "fake"
   - `provider`: "stub"
   - `finish_reason`: "completed"
   - `iterations`: 1
   - `tool_calls`: `[{name: "write_candidate", args: {path: "candidate.md"}}]`
3. Write `candidate.md` to `$CWD/candidate.md` with a
   fixed 10-line stub.
4. Print the JSON to stdout.
5. Exit 0.

## Determinism guarantees

The wrapper is **bit-exact deterministic**:

- Same input → same output, every run
- No `date`, no `$$`, no `$RANDOM`, no environment
  reads except `cwd` and the task prompt
- The output JSON differs only in `cycle` (taken from
  `--cycle`) and `raw_output_path` (which contains the
  cycle name and cwd)

A test that hashes the output with `sha256sum` and
compares to a golden hash will be exact.

## What the wrapper does NOT do

- It does **not** invoke any model.
- It does **not** call the network.
- It does **not** read the LFD bundle.
- It does **not** vary its output across runs.

## Example output

```json
{
  "cycle": "cycle-1",
  "exit_code": 0,
  "elapsed_seconds": 0,
  "claude_duration_ms": 0,
  "tokens": 0,
  "model": "fake",
  "provider": "stub",
  "candidate_text": "Read GOAL.md and produce a candidate skill.",
  "tool_calls": [
    {"name": "write_candidate", "args": {"path": "candidate.md"}}
  ],
  "finish_reason": "completed",
  "iterations": 1,
  "raw_output_path": "/tmp/foo/.iterations/cycle-1/fake.json"
}
```

## Implementation reference

A working implementation lives in the LFD repo
(`examples/lfd-system-verifier/verifiers/fake-agent-wrapper.sh`).
It's the reference for what the scaffold should
generate when `--runtime fake` is passed. If you have
the LFD repo checked out, look there; otherwise the
wrapper contract above is self-contained.
