# Forced Entropy Rules — Reference

The forced-entropy section of the 4-piece loss spec. The
driver enforces these rules; this file documents the
algorithm.

## Why forced entropy matters

Each cycle continues from the previous run's *entire*
context. The model is reading its own last hundred decisions
and the gradient that worked so far. **Hitting local maxima
is the default state.**

If we don't force entropy, the loop will:
1. Find a local maximum (a candidate that scores 0.6 on the
   design set).
2. Refine around it (tweak the prompt, add a reference,
   rephrase).
3. Plateau at 0.6 forever.
4. The user gives up.

The forced-entropy rules are the fences that prevent this.

## Rule 1: overfit reflection every cycle

**When:** before every cycle.
**What:** the driver appends a one-line entry to
`logs/iteration-log.md`:

```
cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>, pass_rate=<float>
```

**Why:** forces the inner agent to articulate (a) what they
think is going to happen, (b) what they think will fail, and
(c) whether they're generalizing or memorizing.

**The generalizing/memorizing flag is critical.** If the
agent is memorizing, the next change must REMOVE an
eval-shaped artifact, not add one. The driver reads the
flag and constrains the next cycle's prompt:

- `g` (generalizing): the next change can be anything.
- `m` (memorizing): the next change must REMOVE something.
  The driver appends to the inner agent's prompt:
  "Your last change was eval-shaped. The next change must
  REMOVE a feature, cap a list, blind an artifact, or
  otherwise generalize."

## Rule 2: stall entropy

**When:** the last cycle's weighted sum did not improve by
≥ `delta` (default 0.05) over the prior cycle.
**What:** the driver reads the last 5 entries of
`logs/iteration-log.md` and prompts the inner agent:
"Pick the OPPOSITE of your last change. Apply it. Log it."

**Why:** when the loop is stuck, the next cycle can't be
"same idea, harder." The opposite of the last change is
guaranteed to be different. It might not be better — but
it's not the same.

**The opposite is determined by the agent, not the
driver.** The driver prompts: "What is the OPPOSITE of your
last change?" The agent's response is the next cycle's
candidate. The driver does not pre-compute the opposite;
that's a value judgment the driver can't make.

**A worked example:**

- Cycle 5: added a "checklist of common bugs" to the
  candidate skill. weighted_sum 0.55 → 0.58.
- Cycle 6: refined the checklist, added 3 more items.
  weighted_sum 0.58 → 0.59. **Stall.** delta=0.01 < 0.05.
- Cycle 7: forced entropy. Driver: "Pick the OPPOSITE of
  cycle 6's change." Agent: "Remove the checklist entirely;
  add a constraint that the skill must be ≤ 50 lines."
  weighted_sum 0.59 → 0.62. **Improved.**

The opposite was harder to find than the same-direction
refinement, but it worked.

## Rule 3: iteration log is required

**When:** always.
**What:** the driver never advances the cycle without an
entry in `logs/iteration-log.md`. If the inner agent's
overfit-reflection is empty, the driver rejects the cycle
and re-prompts.

**Why:** the log is what survives compactions and what
makes the descent auditable. Without the log, "I just
happened to find a great artifact" is indistinguishable
from "I ran 100 cycles of methodical descent." The user
wants the second one.

**A bad cycle is logged, not hidden.** If a cycle's
weighted sum drops, the log entry includes
`expected_failure=<the failure mode that actually happened>`.
The agent is rewarded for honest prediction, not for hiding
failures.

## When forced entropy is WRONG

Forced entropy is not always right. The driver applies
forced entropy on stalls; the user can override.

- **Override 1: the stall is on a "ceiling" sub-loss.** If
  the sub-loss that's stalling is, e.g., Cost, and the
  user has hard-budgeted Cost, the loop will never break
  that ceiling. Forced entropy will keep generating cycles
  that reduce Cost at the expense of Correctness. The
  user should remove the Cost gate or raise the threshold.
- **Override 2: the user has a deadline.** If the user
  says "stop at 6h regardless of pass_rate", forced
  entropy doesn't help — the user is imposing a hard cap.
- **Override 3: the agent is clearly at a real local
  maximum.** If the agent says "I've explored this space;
  further changes within the current architecture won't
  help. Need a different architecture", forced entropy is
  wasted cycles. The user should accept the plateau and
  move on.

The driver does not have visibility into overrides. The
user can pause the loop, adjust the goal prompt, and
resume. The driver picks up from the last cycle.

## Forced entropy in the log

The log entry for a forced-entropy cycle looks like:

```
cycle 7: hypothesis="<agent's hypothesis>", expected_failure="<agent's prediction>", generalizing_or_memorizing=g, pass_rate=0.62, FORCED_ENTROPY=true
```

The `FORCED_ENTROPY=true` marker is what the user grep's
for to see which cycles were forced vs. organic.

## How the driver counts stalls

The driver maintains a counter `consecutive_no_improvement`.
It increments on a stall (delta < threshold), resets to 0 on
an improvement. The stop condition is
`consecutive_no_improvement >= 3 AND forced_entropy_applied
>= 1` — i.e., 3 stalls in a row with at least one forced
entropy applied. The user can tune `max-stall` (default 3)
via the script flag.

The driver does NOT count "no improvement" as
"consecutive_no_improvement += 1" if the cycle is
forced-entropy. Forced-entropy cycles don't count as
failures because their purpose is to escape, not to
improve. The user can override this with
`--count-forced-as-stall` if desired.

## Summary

| Rule | When | What | Who decides |
|---|---|---|---|
| Overfit reflection | Every cycle | Append hypothesis + g/m to log | Inner agent |
| Stall entropy | weighted_sum < prior + delta | Prompt: "pick the opposite" | Inner agent |
| Iteration log required | Always | Reject cycle if log entry empty | Driver |

Forced entropy is a set of fences, not a hammer. The goal
is to escape local maxima without thrashing.
