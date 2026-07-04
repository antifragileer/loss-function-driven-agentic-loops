# Stop Conditions — Reference

The driver stops when ANY of these conditions is true.

## Condition 1: success

**Trigger:** `pass_rate == 1.0` for **N** consecutive cycles
AND the last **N** overfit-reflections say "generalizing".
**N** defaults to **2** and is configurable via the
`--success-after N` flag (passed to `cycle.sh`). Pass
`--success-after 0` to disable the early-success stop
entirely (used by the verifier's method test, which
needs a fixed number of cycles to demonstrate the
forced-entropy rule).

**What the driver does:** emits a `STOP: success` event
to `logs/iteration-log.md` and returns the best cycle's
score.

**Why "N consecutive + generalizing":** the agent might
hit pass_rate=1.0 once by overfitting the design set. The
held-out grader will catch that. Requiring N consecutive
cycles with `generalizing_or_memorizing=g` filters out the
lucky overfit. The held-out grader is the real test; this
condition is just the design-set-side filter.

**A worked example** (N=2, the default):

- Cycle 12: pass_rate=1.0, generalizing=g.
- Cycle 13: pass_rate=1.0, generalizing=g. **STOP: success.**
- The driver reports: best cycle = 13, pass_rate=1.0.

vs.

- Cycle 12: pass_rate=1.0, generalizing=m.
- Cycle 13: pass_rate=1.0, generalizing=g. **Continue.**
- The driver requires 2 consecutive with g. Cycle 12 was
  memorizing; cycle 13 was generalizing. The driver waits
  for cycle 14 to confirm.

**When to raise N:** if your agent's pass_rate=1.0 is
overfitting the design set (held-out fails), raise
`--success-after` to 3 or 4. The driver will require
more consecutive generalizing cycles before stopping,
giving the agent more time to escape the overfit.

**When to set N=0:** when the loop is being driven by
a test (e.g. the verifier's method test), not by a
real agent. The test wants a fixed number of cycles
regardless of success, to exercise the loop's
improvement-tracking machinery.

## Condition 2: wall-clock exhausted

**Trigger:** `verifiers/instruments/time-remaining.sh`
returns ≤ 0 seconds.

**What the driver does:** emits `STOP: wall-clock` and
returns the best cycle's score.

**The wall-clock starts when the loop starts.** The
driver records `LOOP_START_TS` on cycle 0 and
`time-remaining.sh` computes `now - LOOP_START_TS` against
the budget in the goal prompt.

**A worked example:**

- Goal prompt says "8h wall-clock".
- LOOP_START_TS = T0.
- Cycle N: time-remaining.sh returns -10s.
- Driver emits `STOP: wall-clock` and exits.

The user can adjust the budget by editing the goal prompt
and re-running from cycle 0.

## Condition 3: token budget exhausted

**Trigger:** `verifiers/instruments/tokens-remaining.sh`
returns ≤ 0 tokens.

**What the driver does:** emits `STOP: tokens` and returns
the best cycle's score.

**The token budget starts at the goal prompt's value** (e.g.,
1,000,000). The wrapper writes the per-cycle token usage
to a JSON sidecar; `tokens-remaining.sh` subtracts the sum
from the budget.

**Note:** the token budget is **across all cycles**, not
per-cycle. The driver does not enforce a per-cycle cap;
the user can add one with `--max-tokens-per-cycle N`.

## Condition 4: stall with forced entropy applied

**Trigger:** `consecutive_no_improvement >= max-stall` AND
`forced_entropy_applied >= 1` in the last `max-stall`
cycles.

**What the driver does:** emits `STOP: stall` and returns
the best cycle's score.

**`max-stall`** defaults to 3. The user can override with
`--max-stall N`.

**A worked example:**

- Cycle 5: pass_rate=0.55, weighted_sum=0.55. (Best)
- Cycle 6: pass_rate=0.55, weighted_sum=0.55. **Stall.**
- Cycle 7: forced_entropy, pass_rate=0.57, weighted_sum=0.57. **Improvement.**
- Cycle 8: pass_rate=0.57, weighted_sum=0.57. **Stall.**
- Cycle 9: forced_entropy, pass_rate=0.58, weighted_sum=0.58. **Improvement.**
- Cycle 10: pass_rate=0.58, weighted_sum=0.58. **Stall.**
- Cycle 11: forced_entropy, pass_rate=0.58, weighted_sum=0.58. **No improvement after forced entropy.**
- Driver: `consecutive_no_improvement=3 (cycles 10, 11, 12 will be next), forced_entropy_applied=1`. **STOP: stall.**

The driver doesn't stop on the first stall. It waits for
3 consecutive stalls WITH at least one forced entropy
applied in that window. This gives the agent 3 chances to
escape the plateau.

## Stop precedence

If multiple conditions trigger on the same cycle, the
precedence is:

1. `success` (highest — we got what we wanted)
2. `wall-clock` (hard cap, no negotiating)
3. `tokens` (hard cap, no negotiating)
4. `stall` (soft cap, the loop is stuck)

The driver checks them in order and stops on the first
true.

## What "the best cycle" means

The driver maintains `logs/best-cycle.json` — a copy of the
sub-losses JSON from the cycle with the highest
`weighted_normalized` so far. The "best cycle" is the
cycle that maximized the weighted sum of sub-losses, not
necessarily the cycle with the highest pass_rate.

In practice, these are usually the same cycle (a high
pass_rate implies a high weighted sum). But if the agent
trades a sub-loss (e.g., Legibility) for pass_rate, the
best cycle might be a different one.

## Resuming after a stop

The driver is not auto-resumable. After a stop, the user
must:

1. Read `logs/iteration-log.md` to see the descent trace.
2. Decide: stop (accept the best cycle), reset (delete
   the log and start over), or resume (edit the goal
   prompt to add a new constraint and re-run from cycle 0).

The driver does not have a `--resume` flag. The state is
in the log; the user can read it and decide.

## The "submit best" semantic

When the driver stops on any non-success condition, it
emits a final entry to `logs/iteration-log.md`:

```
STOP: <reason>. Best cycle: <N>. weighted_sum=<float>. pass_rate=<float>. sub-losses: <json>
```

And it copies the best cycle's sub-losses to
`logs/best-cycle.json`. The user can then `cat` that file
to see what the loop produced.

The "submit best" semantic is intentional: a stopped loop
is not a failure. The driver stops because the budget is
gone, or the plateau is real, or the goal is met. The
artifact is whatever the best cycle produced.

## Anti-patterns

- **Stopping on every stall.** If the user sets
  `--max-stall 1`, the driver will stop on the first stall.
  This is too aggressive. The forced-entropy rule exists
  exactly to escape stalls. Use `--max-stall 3` (default).
- **Running forever.** The driver has a `--max-cycles`
  flag (default 100). If the loop is still improving at
  cycle 100, the user should increase it. The default
  prevents infinite loops.
- **Ignoring the iteration log.** The log is the audit
  trail. If the user ignores it, they can't tell if the
  loop is descending or thrashing.
