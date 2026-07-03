# Verifier script gotchas — bugs that bit while building the loss loop

This file captures the class-level Python/JSON pitfalls hit
while building the sub-loss verifier scripts (`compute_sub_losses.py`,
`run-design-set.sh`, etc.). They will hit again. They are
not Cline-specific — they apply to any verifier that reads
JSON-from-shell-script output.

## 1. The `or 1` default-value trap (THE most expensive bug here)

```python
exit_code = int(raw.get("exit_code", 1) or 1)
#          ^^^^^^                       ^^^
# This turns 0 (a legitimate value) into 1.
```

`raw.get("exit_code", 1)` returns 0 when the field exists and
is 0. The `or 1` then sees 0 as falsy and substitutes 1. **The
legitimate zero is silently corrupted to a failure code.**

The fix:

```python
exit_code = raw.get("exit_code")
if exit_code is None:
    exit_code = 1
```

**Always default with `is None`, not with `or default_value`.**
This applies to any field where 0 / "" / [] / False is a legal
value: token counts, latencies, exit codes, file sizes, error
counts.

Cost of getting this wrong: sub-loss readout reported
`gates_passed: false` on every cycle. Took 2 tool calls to
diagnose with debug prints.

## 2. `json.loads()` on NDJSON blows up

Cline writes NDJSON (one JSON object per line). `json.loads()`
on the whole file fails with `Extra data: line 2 column 1`.

The fix is in the parser:

```python
text = p.read_text()
try:
    raw = json.loads(text)  # one-object form (the wrapper's summary)
except json.JSONDecodeError:
    # NDJSON form (Cline's raw output) — find run_result
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "run_result":
            raw = {...}  # extract
            break
```

**Any verifier that reads `cycle-N.json` may be pointed at
either the wrapper's summary OR the raw Cline output.** Support
both, or the verifier will fail silently with one of the
two paths.

## 3. Python 3.9 compat — `X | None` doesn't work without `from __future__ import annotations`

If the runtime is 3.9 and you write `def f(x: Path | None)`,
Python parses the type at module load (PEP 563 not yet on by
default), and crashes with `TypeError: unsupported operand
type(s) for |: 'type' and 'NoneType'`.

Fix: add the future import at the top of every verifier script.

```python
from __future__ import annotations
```

Cost: 1 tool call to diagnose.

## 4. Heredoc + `set -euo pipefail` + Python = pain

Inlining Python via `python3 - <<'PY' ... PY` inside a
`set -euo pipefail` shell script is fragile. The `<<'PY'`
form has issues with:

- `set -u` and unset variables in the heredoc.
- Mixed indentation (Python sees the `print` outside the `try`
  because the heredoc content's leading whitespace confuses
  the indentation check).
- `$VAR` interpolation that the script intends to be literal
  Python.

**Better pattern: write the Python to a file in
`scripts/`, call it from bash.**

```bash
PARSED=$(python3 "$SCRIPT_DIR/parse_cline_output.py" "$RAW_OUT")
```

The shell stays trivial (arg parsing, file paths, exit codes).
The Python stays in Python. Each side is independently testable.

## 5. `set -e` + a Python `subprocess.run` that returns 0 but the verifier wants non-zero

If the wrapper's process exits 0 but the JSON it emitted has
`finish_reason: "error"`, the driver should not treat the cycle
as a success. The wrapper records `exit_code` separately from
its own process exit. The driver inspects JSON, not the
wrapper's exit code.

**Rule: the wrapper's process exit is for the shell pipeline.
The JSON's `exit_code` and `finish_reason` are the source of
truth for the loop.**

## 6. NDJSON `agent_event.tool_call` is harder to extract than it looks

Cline's `agent_event` events have shape
`{"type": "agent_event", "event": {"type": "tool_call", "name":
"...", "args": {...}}}`. The nested event under `event` is the
thing. Easy to mis-flatten. The canonical parser is at
`scripts/parse_cline_output.py` — let it do the work.

## 7. Cline's `run_result.text` may be a refusal string

When Cline fails (provider rejects, model errors, etc.),
`run_result.text` often contains the refusal message itself
(e.g. `"Invalid request Error"` or `"I'm unable to create the
file directly..."`). Don't treat a non-empty `text` as
success. The combination of `finish_reason == "error"` OR
a refusal-pattern `text` is the failure signal.

## 8. The instrument scripts need `PROJECT_DIR` env var, not CWD

Instruments like `time-remaining.sh` and `tokens-remaining.sh`
read state files at `${PROJECT_DIR}/logs/`. The driver must
export `PROJECT_DIR` before calling them, not just `cd` into
the project dir. CWD is unreliable for instruments that may
run from anywhere.

```bash
PROJECT_DIR="$PROJECT_DIR" ./verifiers/instruments/time-remaining.sh
```

## 9. Grader scope: the ITER_DIR argument is the candidate root, not a search base

When a per-task grader is given an iter dir (e.g.
`test-tasks/design/02-foo/grade.sh .iterations/cycle-3/`), it
must look ONLY at that exact directory for the candidate file.
It must not `find` the entire parent tree, because:

- The iter dir contains a copy (via the wrapper's seed step) of
  the buggy input.
- A prior cycle's iter dir under the same parent will also
  contain a *fixed* version of the same file (from a previous
  successful run).
- `find … | head -1` will return whichever sorts first in
  traversal order, which depends on the OS and is not what the
  grader wants.

The fix: the grader uses `$ITER_DIR/<expected filename>` as an
exact path. It also refuses to run if `$ITER_DIR` itself
contains a `.iterations/` subdirectory (i.e. looks like a
parent, not an iter dir).

```bash
CANDIDATE="$ITER_DIR/calculator.py"
[[ ! -f "$CANDIDATE" ]] && { echo "FAIL: no $CANDIDATE"; exit 1; }
```

**Cost of getting this wrong:** the first run of the off-by-one
grader reported PASS on the *parent's* buggy file because
`find` discovered a previous cycle's fixed copy first. Took
one tool call to diagnose. The verifier silently lied about
correctness for one cycle before the bug was caught.
