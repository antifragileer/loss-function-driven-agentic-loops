# Iteration Log Format

The `logs/iteration-log.md` file is the audit trail of the
loop. One line per cycle, plus optional stop and override
events. The driver appends, never overwrites.

## Cycle entry

```
cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>, pass_rate=<float>, weighted_sum=<float>, gates=<true|false>, FORCED_ENTROPY=<true|false>
```

The fields:

| Field | Type | Source |
|---|---|---|
| `N` | int | The cycle number (0 = baseline, 1+ = cycles) |
| `hypothesis` | string | What the driver/agent thought this cycle would do |
| `expected_failure` | string | What the agent predicted would go wrong |
| `generalizing_or_memorizing` | char | `g` or `m`, set by the agent |
| `pass_rate` | float | The design set pass rate for this cycle |
| `weighted_sum` | float | The weighted normalized sum of sub-losses |
| `gates` | bool | Whether all gate sub-losses passed |
| `FORCED_ENTROPY` | bool | Whether this cycle was a forced-entropy cycle |

The `FORCED_ENTROPY` field is missing on organic cycles
(driver's default) and present on forced-entropy cycles.
The user can grep `FORCED_ENTROPY=true` to count forced
cycles.

## Cycle 0 (baseline) entry

```
cycle 0: hypothesis="baseline (no candidate installed)", expected_failure="<the agent's prediction for what the baseline will look like>", generalizing_or_memorizing=g, pass_rate=0.0, weighted_sum=0.0, gates=false
```

Cycle 0 is run with no candidate installed. The
`pass_rate=0.0` is the floor; every cycle must beat it.

## Stop event

```
STOP: <reason>. Best cycle: <N>. weighted_sum=<float>. pass_rate=<float>. sub-losses: <json>
```

Reasons:

- `success` — pass_rate=1.0 for 2 consecutive cycles, both
  generalizing.
- `wall-clock` — wall-clock budget exhausted.
- `tokens` — token budget exhausted.
- `stall` — `max-stall` consecutive stalls with forced
  entropy applied.
- `user-abort` — user sent SIGINT/SIGTERM.

## Override event

```
OVERRIDE: <timestamp> — <description>
```

The user can append an override event to the log to
indicate a manual intervention. The driver reads the log
on resume and respects overrides (e.g., "raise the
Cost gate to 0.5" would change the scoring for future
cycles).

## Worked example: a successful descent

```
cycle 0: hypothesis="baseline (no candidate installed)", expected_failure="all tasks fail (no skill)", generalizing_or_memorizing=g, pass_rate=0.0, weighted_sum=0.0, gates=false
cycle 1: hypothesis="write a generic Go Slack client skill", expected_failure="won't handle thread replies correctly", generalizing_or_memorizing=g, pass_rate=0.4, weighted_sum=0.42, gates=false
cycle 2: hypothesis="add a reference on Slack's threading semantics", expected_failure="reference might be too dense", generalizing_or_memorizing=g, pass_rate=0.6, weighted_sum=0.61, gates=true
cycle 3: hypothesis="add a checklist of common bugs from cycle 1-2 failures", expected_failure="might overfit to design set", generalizing_or_memorizing=m, pass_rate=0.8, weighted_sum=0.78, gates=true
cycle 4: hypothesis="refine the checklist (more items)", expected_failure="?", generalizing_or_memorizing=m, pass_rate=0.8, weighted_sum=0.79, gates=true
cycle 5: FORCED_ENTROPY=true — opposite of cycle 4. hypothesis="remove the checklist, add a constraint that the skill must be ≤ 50 lines", expected_failure="might regress on pass_rate", generalizing_or_memorizing=g, pass_rate=0.8, weighted_sum=0.83, gates=true
cycle 6: hypothesis="add a worked example of a thread reply", expected_failure="?", generalizing_or_memorizing=g, pass_rate=1.0, weighted_sum=0.92, gates=true
cycle 7: hypothesis="add a second worked example", expected_failure="?", generalizing_or_memorizing=g, pass_rate=1.0, weighted_sum=0.95, gates=true
STOP: success. Best cycle: 7. weighted_sum=0.95. pass_rate=1.0.
```

The user can read this log and see: 7 cycles, one forced
entropy, two generalizing-g cycles at the end, success.

## Worked example: a stall

```
cycle 0: hypothesis="baseline", expected_failure="all fail", generalizing_or_memorizing=g, pass_rate=0.0, weighted_sum=0.0, gates=false
cycle 1: hypothesis="generic skill", expected_failure="?", generalizing_or_memorizing=g, pass_rate=0.4, weighted_sum=0.42, gates=false
cycle 2: hypothesis="add error-handling reference", expected_failure="?", generalizing_or_memorizing=g, pass_rate=0.6, weighted_sum=0.61, gates=true
cycle 3: hypothesis="add API cheat-sheet", expected_failure="?", generalizing_or_memorizing=m, pass_rate=0.6, weighted_sum=0.62, gates=true
cycle 4: hypothesis="expand cheat-sheet", expected_failure="?", generalizing_or_memorizing=m, pass_rate=0.6, weighted_sum=0.62, gates=true
cycle 5: FORCED_ENTROPY=true — opposite of cycle 4. hypothesis="remove cheat-sheet, add a constraint on skill length", expected_failure="?", generalizing_or_memorizing=g, pass_rate=0.6, weighted_sum=0.63, gates=true
cycle 6: hypothesis="refine length constraint", expected_failure="?", generalizing_or_memorizing=m, pass_rate=0.6, weighted_sum=0.63, gates=true
cycle 7: FORCED_ENTROPY=true — opposite. hypothesis="remove length constraint, add checklist", expected_failure="?", generalizing_or_memorizing=m, pass_rate=0.6, weighted_sum=0.63, gates=true
cycle 8: hypothesis="add documentation cross-refs", expected_failure="?", generalizing_or_memorizing=m, pass_rate=0.6, weighted_sum=0.63, gates=true
STOP: stall. Best cycle: 5. weighted_sum=0.63. pass_rate=0.6.
```

The user reads this and sees: 3 consecutive stalls with
forced entropy applied. The plateau is real. The best
cycle is 5 (the first forced-entropy escape), and the
loop should be stopped or the goal prompt revised.

## Reading the log programmatically

```bash
# Get the pass_rate of every cycle
sed -n 's/.*pass_rate=\([0-9.]\{1,\}\).*/\1/p' "$PROJECT_DIR/logs/iteration-log.md"

# Get the best cycle
sed -n 's/.*Best cycle: \([0-9]\{1,\}\).*/\1/p' "$PROJECT_DIR/logs/iteration-log.md" | tail -1

# Count forced-entropy cycles
grep -c 'FORCED_ENTROPY=true' "$PROJECT_DIR/logs/iteration-log.md"

# Last 5 cycles
tail -5 "$PROJECT_DIR/logs/iteration-log.md"
```

The driver uses the same patterns. The log is a stable
contract between the driver and the user.

## What the log is NOT

- Not a substitute for the per-cycle JSON. The log is a
  summary; the per-cycle dir has the full data.
- Not a comment thread. The user shouldn't add free-form
  notes. Use `OVERRIDE:` events.
- Not a per-iteration transcript. The driver does not log
  every tool call the agent made. That's in
  `logs/cycle-<N>/response.txt` (truncated to 2 KB) and
  the agent's per-cycle JSON sidecar.
