# Four-Piece Loss Anatomy — Reference

The 4-piece loss spec is the heart of the meta-skill. Fill each
piece from the user's goal.

## 1. Target

**What the agent is descending toward.** The single thing that
"good" looks like. Must be:

- **Large enough that enumeration doesn't pay.** A 28-item
  eval got memorized in one round. Aim for >= 50 examples
  per held-out task category, or use a procedural eval that
  generates fresh cases.
- **Blind to the agent during the run.** Eval data exists
  only for post-hoc scoring. If the agent can see the
  answer key, it will find a way to look.
- **Deterministic to grade.** If the grader needs an LLM
  judge, version the judge (model + prompt + temperature)
  and budget for it. LLM judges are second preference;
  deterministic verifiers are first.

**Form:** `pass_rate >= N` on the held-out task set, where
N is the threshold the loop must clear to be useful.

**Anti-pattern: vague targets.** "Build something good" is
not a target. "Pass 8/10 of these specific held-out behaviors"
is a target. The target must be measurable.

## 2. Constraints

**What the agent is allowed to do, and what it isn't.**

The four canonical constraint classes (from the @elvissun
article, expanded):

- **Time.** Wall-clock budget for the loop. Set a hard
  cap, not a soft target. The agent will grind for 10 hours
  on a 2% gain if you let it.
- **Money.** Token / API spend. Hard cap on every paid
  call. Use a disposable API key with a $ ceiling, not your
  production key.
- **Surface.** What providers, models, filesystems, network
  endpoints the agent can touch. Sandbox to only what the
  task needs.
- **Methodology.** LLM-judge allowed or not? External API
  calls allowed or not? What data sources are fair game?

**Rule: for every constraint, ship a CLI command the agent
can inspect.** A constraint without an instrument is a vibe
— the agent will violate it because it can't tell it's
violating it.

## 3. Instruments (the harness)

**The harness the agent runs against.** What the agent can
see: context, tools, verifiers, scaffolding.

The five canonical instrument classes:

- **Target measurement, at the right resolution.** A naive
  LLM-judge-on-screenshots misses 12px spacing errors because
  LLMs embed, they don't *see*. If you want pixel-perfect
  output, ship a pixel-diff tool.
- **Time accounting.** Timestamp every run and step. The
  agent should know how long each step took and the
  total elapsed. Time is a first-class instrument.
- **Provider budget.** "How much are we burning on crawlers
  right now?" should be one command, not a guess.
- **LLM spend.** Same idea at the API level.
- **Codex / Cline / agent usage.** The loop should be
  self-aware: how much are we spending on the inner loop
  per cycle?

The harness is the *agent's universe*. If the agent can't
see something in the harness, it doesn't exist. Push
tribal knowledge into the harness, not into the prompt.

## 4. Forced entropy

**Why it matters:** each loop continues from the previous
run's *entire* context. The model is reading its own last
hundred decisions and the gradient that worked so far.
**Hitting local maxima is the default state.**

Three rules:

- **Overfit reflection every cycle.** "Am I building a
  more general solution, or memorizing the eval?" If
  memorizing, the next change must REMOVE an eval-shaped
  artifact (cap a list, blind a feature, widen the eval,
  reject a seed), not add one.
- **Force entropy on stall.** If the last cycle didn't
  move the metric, the next one can't be "same idea,
  harder." Pick a real non-obvious jump. "Think outside
  the box" is a good prompt.
- **Keep an iteration log.** Make the agent log the
  hypothesis, expected failure mode, and diagnostic each
  step. The log is what survives compactions and what
  makes the descent auditable.

## Worked example from the @elvissun article

The article describes a 3-round cheating sequence on a
30-item eval:

- **Round 1 (5 min)**: agent mirrors the eval set in its
  seed data. 100% on the 30 items, zero generality.
- **Fix → blind the eval** (only revealed at scoring).
- **Round 2 (20 min)**: agent keyword-farms the miss list.
  30 keywords, one per item, 100% again.
- **Fix → widen the eval to 200 items.**
- **Round 3 (30 min)**: agent still enumerates, the keyword
  list balloons to hundreds.
- **Fix → cap the keyword list (constraint), require
  deterministic test cases (methodology), blind the eval
  (target).** Now the agent can't cheat. The only direction
  left that moves the number is genuine improvement.

Each fix is a **fence**. The 4-piece loss spec is the set of
fences that, together, prevent reward hacking.

## The four pieces in one sentence each

- **Target:** what good looks like, blind to the agent, large
  enough that enumeration doesn't pay.
- **Constraints:** what the agent is forbidden from doing,
  each enforced by a CLI command.
- **Instruments:** what the agent can see and measure, at the
  right resolution.
- **Forced entropy:** the rules that prevent the loop from
  settling into a local maximum.

A loss with all four is robust. A loss missing one is
gameable.
