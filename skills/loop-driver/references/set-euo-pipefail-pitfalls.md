# `set -euo pipefail` Pitfalls — Reference

The loop-driver's `cycle.sh` runs under `set -euo pipefail`.
This is the right safety setting — it surfaces bugs early —
but it has three failure modes that look like "the script
silently exits with no output" if you don't know to look.

If you are debugging "my script just exits" with no error
message, it's almost always one of these three.

## Pitfall 1: `set -u` + unbound variable

**Symptom:** script exits 1 with `name: unbound variable`
on stderr, no other output.

**Cause:** referencing a variable that was never set, with
`set -u` enabled. Bash's `set -u` errors out on any unset
variable reference.

**Common cases in this script:**
- `LOOP_START_TS="$LOOP_START_TS"` at the top of a function.
  If the env var is unset, the reference itself errors.
- Reading from a `$(...)` substitution that errored out and
  left the variable empty.

**Fix:** always use `${VAR:-default}` for variables that
might be unset:

```bash
# BAD — errors if LOOP_START_TS is unset
LOOP_START_TS="$LOOP_START_TS"

# GOOD
LOOP_START_TS="${LOOP_START_TS:-}"
[[ -z "$LOOP_START_TS" ]] && LOOP_START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

## Pitfall 2: subshell exit code + `set -e`

**Symptom:** script exits 1 mid-pipeline, no clear error.

**Cause:** `VAR=$(cmd1 | cmd2 | cmd3)`. If any of cmd1,
cmd2, or cmd3 fails, the subshell returns that exit code.
`set -e` then kills the script.

**Common cases in this script:**
- `RUNTIME=$(grep ... | sed ...)` — if `grep` finds no
  match, it exits 1. The subshell inherits 1. The script
  dies.
- `LAST_5=$(tail -5 "$LOG_FILE" 2>/dev/null || true)` —
  the `|| true` is *inside* the subshell, so the subshell
  always returns 0. But the surrounding `while read` block
  inherits `set -e` differently.

**Fix:** append `|| true` (or `|| VAR="default"`) to the
subshell command so the subshell always exits 0:

```bash
# BAD — dies if grep finds nothing
RUNTIME=$(grep -oE 'inner loop is the `\w+` CLI' GOAL.md | head -1 | sed ...)

# GOOD
RUNTIME=$(grep -oE 'inner loop is the `\w+` CLI' GOAL.md 2>/dev/null | head -1 | sed ... || true)
```

For assignments where you want a default on failure, chain
the fallback outside the subshell:

```bash
SUCCESS_COUNT=$(... pipeline ...) || SUCCESS_COUNT=0
```

## Pitfall 3: `wc -l` + assignment to a numeric variable

**Symptom:** later `[[ "$VAR" -ge 2 ]]` errors with
`syntax error in expression (error token is "VAR")` or
silent exit.

**Cause:** `wc -l` on a stream with no matches outputs
`0` followed by a *trailing newline*. When you capture it
with `$(...)`, command substitution strips *trailing*
newlines but the value still contains a newline if
multiple lines were produced. Then arithmetic
comparisons fail because the value isn't a clean integer.

**The tell:** the variable contains `"0\n0"` or `"0\n"`
visibly in the trace.

**Fix:** always pass `tr -d ' \n'` after `wc -l`, and
defensively default:

```bash
# BAD — SUCCESS_COUNT may be "0\n0"
SUCCESS_COUNT=$(tail -10 "$LOG_FILE" | grep -E 'pattern' | wc -l)

# GOOD
SUCCESS_COUNT=$(tail -10 "$LOG_FILE" 2>/dev/null \
                | grep -E 'pattern' \
                | wc -l \
                | tr -d ' \n' 2>/dev/null) || SUCCESS_COUNT=0
SUCCESS_COUNT="${SUCCESS_COUNT:-0}"
```

The `tr -d ' \n'` strips both spaces and newlines. The
`|| SUCCESS_COUNT=0` covers the case where the entire
pipeline fails. The `${SUCCESS_COUNT:-0}` is belt-and-
suspenders against `set -u` later.

## Diagnostic recipe

When `cycle.sh` "exits silently" (no stdout, no obvious
stderr, exit 1), run it under `bash -x`:

```bash
bash -x /path/to/cycle.sh --project-root /tmp/foo --cycle 1 \
  > /tmp/out 2> /tmp/err
echo "exit: $?"
tail -30 /tmp/err
```

`bash -x` prints every command to stderr before executing
it. The last command in the trace is where the script
stopped. Match the last line to one of the three pitfalls
above.

If the trace ends at an assignment (`+ VAR=...`) and the
script's exit is non-zero, the assignment itself failed —
that's Pitfall 1 or 2.

If the trace ends at an `[[` test, the value being
compared is malformed — that's Pitfall 3.

## Why `set -euo pipefail` is still the right default

`set -e` and `set -u` surface bugs early. A script without
them will silently produce wrong output when a command
fails, which is much harder to debug than the three
pitfalls above. The discipline is: defensively default
every variable, append `|| true` to every subshell, and
use `tr -d` to clean `wc -l` output. After that, the
script is robust.

## What `cycle.sh` does to defend against these

- All user-facing variables are `${VAR:-default}`-guarded.
- All subshells that might legitimately fail (greps with
  no match, tails on absent files) end with `|| true`.
- All `wc -l` outputs are passed through `tr -d ' \n'`.
- The `PRIOR_PSR` / `PRIOR_WSUM` / `PRIOR_GATES` reads
  use `2>/dev/null || echo` fallbacks.

If you copy a pattern from `cycle.sh` into another script
in this skill, copy the defensive defaults with it.

## Other places this pattern bites

- `verifiers/instruments/*.sh` (generated by
  `harness-scaffold`) all use `set -euo pipefail`. The
  scaffold's `run-design-set.sh` and `cline-wrapper.sh`
  follow the same pattern. If you modify those, apply
  the same defensive defaults.
- Any `python3 -c "..."` invocation from bash inherits
  the exit code of the python process. If python crashes
  on a malformed `$(...)` substitution, the script dies.
  Use `python3 -c "..." 2>/dev/null || echo "default"`
  when the python call might fail on bad input.
