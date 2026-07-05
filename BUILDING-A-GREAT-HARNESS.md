# Building a Great Harness

The LFD pattern works like this: a meta-skill turns your
goal into a `/goal` prompt, a harness is scaffolded, and an
outer loop runs the inner agent against the harness until
it converges. The pattern works at *any* harness quality —
but the *quality of the result* is a near-direct function
of the *quality of the harness*. A great harness turns a
plain coding agent into something that converges on a
strong solution. A thin harness turns it into something
that plateaus at "OK."

This document is the manual for the human in the loop
(HITL) at the two points that matter most:

1. **V0 → V1**: the AI's first attempt at the harness is
   almost always too thin. This document gives you a
   checklist for expanding it *before* you paste the
   `/goal` prompt into the loop session.
2. **V1 → V2+**: as the loop runs, you'll see the harness
   itself start to drift, get bypassed, or show up as the
   bottleneck. This document gives you the playbook for
   iterating on the harness *while the loop is running* —
   which is the only way to keep the descent going.

If you have never used LFD before, read the **Plain `/goal`
vs LFD** section first to understand why a harness is
worth the effort. If you've used a plain `/goal` prompt
before and it "kind of worked," the **V0 → V1: Expand the
first attempt** section is where the leverage is.

## Plain `/goal` vs LFD — what the harness actually buys you

A plain `/goal` (or `claude code`, or any coding agent
prompted directly) takes a goal and tries once or twice.
You get back a candidate. The candidate might be good. The
candidate might be bad. You have no instrument to tell
the difference; you read the code and form a judgment.

LFD replaces the judgment with a measurable signal. The
harness *defines* what "good" means for your specific
project: which behaviors the artifact must exhibit, which
edge cases the design set exercises, which constraints
the loop enforces. With the harness in place, the loop
runs dozens or hundreds of candidates, scores each one
against the same rubric, and the score trajectory tells
you *and* the agent whether the work is converging.

The harness is the *loss function* that makes the loop
descent-shaped instead of random-walk-shaped. A bad
harness = a random walk. A great harness = a steep,
auditable descent.

**Three concrete differences you'll see:**

1. **You can stop the loop at any cycle and tell whether
   the candidate is real progress.** The iteration log
   shows hypothesis → expected failure → pass rate per
   cycle. A plain `/goal` gives you one shot.
2. **The agent can't quietly cheat the spec.** A good
   harness has held-out tasks the agent has never seen.
   If the design set is gamed, the held-out grader
   catches it. A plain `/goal` has no held-out.
3. **You can hand the harness to someone else and they
   can re-run the loop.** A plain `/goal` is one
   conversation; an LFD harness is a reusable artifact.

If you've never used LFD before, the V0→V1 section below
will turn a plain `/goal`-shaped prompt into a real
harness with the same effort, just spread across two
sessions instead of one.

## V0 → V1: Expand the first attempt

The AI's first draft of a harness, in response to a goal
like "build a Slack clone in Go," will look like this:

- 5 design tasks, all on the same shape (one function
  per task, all "write a function that does X and
  returns Y")
- A held-out set of 5-10 tasks lifted from the public
  docs, often at exactly the same surface as the design
  set
- Instruments that just `echo` placeholder values
- A `grade.sh` per task that asserts "the file exists and
  has the function name" rather than testing behavior

This V0 harness is functional. The loop will run. The
score will move. But the score will plateau quickly
because the harness is measuring the wrong things. Your
job in V0 → V1 is to expand the harness so it measures
the *right* things.

### The V0 expansion checklist

Walk through this with the AI in the meta-session,
before you paste the `/goal` prompt into the loop
session. Each item is a *specific* expansion; don't
skip any.

**1. Triple the design set, not double it.** A 5-task
design set has too few axes. Aim for 15-25 tasks across
deliberately different shapes:
- 5-6 happy-path tasks ("the basic case works")
- 5-7 error/edge cases ("what happens when X is empty,
  null, oversized, or malformed")
- 3-5 cross-cutting tasks (a task that exercises 2-3
  components at once — the kind of task that breaks
  naive implementations)
- 2-4 negative tasks (a task where the right answer is
  *not* to do something — "the function should NOT
  crash, NOT block, NOT retry forever")

The negative tasks are the ones the AI will skip by
default. Insist on them. They catch the largest class
of agent failures (over-eager implementations).

**2. Make the held-out set *categorically different*
from the design set.** A common V0 mistake: the AI
reads the public docs, sees 30 examples, and uses 5 for
design + 5 for held-out. The agent memorizes the
category. The right structure:

- Design set: standard public-API examples
- Held-out set: things the public docs mention but don't
  fully specify (rate limits, retry semantics,
  authorization edge cases, format quirks in error
  responses)

The held-out should make the agent *reason* about
behavior, not match patterns.

**3. Replace every placeholder `grade.sh`.** The V0
harness often has graders that check "the file
exists" or "the function compiles" — those are
smoke tests, not graders. A real `grade.sh`:
- Exits 0 on real success
- Exits non-zero on real failure
- Has a deterministic, reproducible check
  (assertion, file diff, subprocess test, JSON shape
  match)
- Takes < 60 seconds to run
- Has at least one *negative* assertion
  (e.g., `assert output != "TODO"`)

If a `grade.sh` doesn't have a negative assertion, it's
reward-hackable. The agent will pass it with an empty
function and a comment.

**4. Add at least one cross-task `grade.sh`.** Beyond
the per-task graders, add a `verifiers/cross-task-check.sh`
that runs after the design set and checks a property
that spans tasks (e.g., "no two tasks import the same
helper", "the artifact is under 100KB", "no test takes
longer than 30s"). This catches architectural smells
that per-task graders miss.

**5. Make the instruments actually measure.** V0
instruments often `echo "100"` for "100% budget
remaining" or `cat /dev/null` for "no tokens used."
Insist that each instrument:
- Reads a real log / queries a real API / parses a
  real file
- Returns a numeric or structured value, not a string
  placeholder
- Exits non-zero on its own internal failure
  (file missing, parse error), not on a "constraint
  violated" condition — that's the loop's job

A constraint without a real instrument is a vibe. The
agent will violate it because it cannot tell it is
violating it.

**6. Write the AGENTS.md in your own voice.** The V0
AGENTS.md is a generic "operating rules" list. Replace
it with what *you* would want a new engineer to read
on their first day:
- What this project is, in 2 sentences
- The 3-5 hard rules (what NOT to do)
- The iteration log format
- The "go look at X first" links (your docs, your
  conventions, your anti-patterns)

The agent reads AGENTS.md every cycle. The more
project-specific it is, the more the loop converges on
*your* project, not on a generic.

**7. Add 3-5 explicit reward-hack guards to the
target.** The @elvissun pattern: think about how a
motivated agent could game your grader. Common hacks:
- The agent deletes the test file
- The agent writes a stub that always returns the
  expected output
- The agent adds a `sleep` to make a timeout pass
- The agent modifies `AGENTS.md` to remove the hard
  rule
- The agent reads the held-out directory

For each guard, add a check to `verifiers/integrity.sh`
that runs before scoring and refuses to score if the
guard is tripped.

**8. Add a 2-3 line "definition of done" at the top of
GOAL.md.** The V0 GOAL.md opens with a long description
of the project. Replace the first 3 lines with:

```
DONE WHEN: <the single testable criterion that
defines success for this project, in one sentence>
NOT DONE WHEN: <the most common ways an agent will
mistakenly claim to be done>
```

The loop driver reads this. The agent reads this. You
read this. Keep it ruthlessly specific.

### Sample HITL exchange (V0 → V1)

This is a real exchange from expanding a Slack-clone
harness. Use it as a template.

> **You**: The design set is too uniform. All five tasks
> are "write a function that does X." Add three tasks
> where the function has to handle a malformed input
> and return an error, plus two where the right answer
> is to do *nothing* (e.g., posting to a channel the
> user isn't in should return a specific error code, not
> retry).

> **AI**: Adding tasks 06, 07, 08 for malformed inputs
> and 09, 10 for "right answer is no-op"...

> **You**: Task 04's grader passes when the function
> returns nil for everything. Make it assert the return
> value is a specific `*Thread` struct with a
> non-empty `RootID`. And add a negative assertion:
> the function should NOT call `time.Sleep`.

> **AI**: Updated grade.sh to assert the struct shape
> and grep the agent's output for `time.Sleep`...

> **You**: The held-out set is the same shape as the
> design set. Replace three of them with rate-limit
> behavior tests (the public docs say "429 after 30
> req/min" — the agent has to actually implement
> rate limiting, not match an example).

This is what HITL looks like. You're not writing the
harness; you're directing the AI to write a *better*
harness. Each round of the exchange makes the
harness 10-30% better, and the gains compound
across the loop.

## V1 → V2+: Iterate on the harness while the loop runs

The V0 → V1 expansion is the easy HITL. You do it once,
in the meta-session, with the AI focused on the
harness. The V1 → V2+ iteration is harder because it
happens *while the loop is running*, and you have to
read the iteration log to figure out when the harness
is the bottleneck rather than the candidate.

### When to improve the harness vs. let the loop work

The loop's iteration log tells you everything. Read the
last 10-20 entries. For each cycle, look at:

- **Hypothesis**: what change did the agent try?
- **Expected failure**: what did it predict would go
  wrong?
- **Pass rate**: did it actually go wrong?

Three patterns, three responses:

**Pattern 1: pass rate stuck at 0.X for many cycles**

The loop is trying and failing. The hypotheses are
sensible but the work doesn't move the score. This
usually means the harness is too narrow — the design
set isn't covering the failure modes the agent is
hitting.

*Action:* pause the loop, look at the failed cycle
transcripts in `logs/cycle-N/`, identify the failure
mode the agent is hitting, add a design task that
exercises that mode, restart the loop. Don't change
the held-out set — that's the test, not the training
set.

**Pattern 2: pass rate stuck at 1.0 but the candidate
looks bad**

The agent is gaming the grader. The design set is
reward-hackable — there's a shortcut that passes all
the checks but produces something you don't want.

*Action:* pause the loop, look at the actual candidate
in `skills/<name>/`, identify which `grade.sh` is
being gamed, tighten that `grade.sh` with a
behavioral assertion, restart the loop. The held-out
grader will likely catch the gaming on the next run,
but don't wait for that — fix the design grader
directly.

**Pattern 3: pass rate oscillating (0.4, 0.8, 0.3, 0.7,
0.2, 0.9...)**

The agent is making changes, scoring, sometimes
regressing. The loop is in forced-entropy territory
but not making net progress. This usually means the
harness is rewarding a proxy for the real goal, and
the proxy has multiple local maxima the agent is
jumping between.

*Action:* pause the loop, look at the highest-scoring
candidate, look at the lowest-scoring candidate, look
at what distinguishes them. The proxy is probably
something like "uses a specific API call" or
"matches a specific output structure." Replace the
proxy with a behavioral check (e.g., "the function
completes in < 1s on the mock server" instead of "the
function calls `slack.PostMessage`").

### The "the loop is stuck" playbook

When the loop has been running for >2 hours with
<10% improvement, stop and read `logs/iteration-log.md`
end-to-end. The pattern usually emerges:

1. **Last 5 hypotheses are minor variations of each
   other** → the agent is in a local maximum. Force
   entropy should have caught this, but the entropy
   rule is too small. Tighten `--delta` to require
   bigger improvements, or add a manual
   `cycle=N: forced-entropy=true` entry to the log to
   push the loop out.

2. **Last 5 hypotheses are unrelated** → the agent
   has no idea what to try. The harness is too broad
   and the agent is sampling randomly. Tighten the
   target: pick the 3-5 design tasks that matter most
   and disable the rest temporarily. The loop will
   converge on a smaller problem faster.

3. **Pass rate is 1.0 for 2+ cycles but you don't
   believe the candidate** → the harness is
   reward-hackable. The iteration log will lie. Don't
   trust it. Read the candidate, find the hack,
   tighten the grader.

4. **Held-out score is way below design score** →
   the agent is overfitting to the design set. The
   design set is too narrow or too similar to itself.
   Add design tasks that span the gap between design
   and held-out (these are sometimes called
   "validation" tasks — they live in design but act
   like a held-out-lite).

### Things that look like harness problems but aren't

- **"The agent is making dumb mistakes"** → usually a
  prompt problem, not a harness problem. The agent
  needs a clearer instruction in the per-task
  `prompt.txt`. Improve the prompt, not the harness.
- **"The agent runs out of tokens"** → the
  `wall-clock` / `tokens-remaining` instruments are
  reporting wrong, OR the design tasks are too big
  (a single task is the size of three). Check the
  instruments; if they're right, split the task.
- **"The agent's output is good but the iteration log
  is messy"** → not a problem. The iteration log is
  for the agent and the verifier, not for you. Leave
  it.
- **"The loop finished but I want a different
  solution"** → the held-out is the answer. If
  pass_rate=1.0 and held-out is satisfied, the loop
  found the optimum *of the harness*. Change the
  harness, not the loop.

### The V1 → V2 HITL cycle

When the loop is running, you have a few different
shapes of HITL:

**Asynchronous** (you read the log every few hours):
- `tail -f logs/iteration-log.md` in a terminal
- Check for the three stuck patterns above
- Add a manual entry to the log if you want to push
  the agent in a direction: `cycle 7: hypothesis="add
  3 negative-case tasks to the design set",
  expected_failure="score drops to 0.6, then climbs
  over 3 cycles", g, pass_rate=0.7`

**Synchronous** (you're in the loop session):
- The `/goal` prompt says to stop and report if
  something is wrong. When the agent stops, the
  conversation is the HITL. Most often the right
  answer is "tighten this grader" or "add this
  design task."

**Batch** (the loop finishes):
- Read `logs/best-cycle.json` to see the final
  score
- Read the winning candidate in
  `skills/<name>/SKILL.md`
- If the candidate is good: ship it.
- If the candidate is bad but the score was 1.0: the
  harness is wrong. Go back to the meta-session, fix
  the harness, re-run.
- If the candidate is bad and the score was <1.0: the
  loop didn't have time. Increase budget, re-run.

**The loop is a tool; the harness is the design.**
Improving the loop (more cycles, better entropy rules,
faster inner agent) is 20% of the leverage. Improving the
harness (better design tasks, tighter graders, real
instruments) is 80%.

## Ideas bank: 20 specific ways to make a V0 harness better

These are tactics that consistently move the needle.
Pick the ones relevant to your project; don't try to
do all 20.

### Design set (the visible training tasks)

1. **Add an "empty input" task per group.** A task
   where the input is `""`, `null`, or `[]` and the
   right answer is a specific error.
2. **Add an "oversized input" task per group.** A task
   where the input is 10x larger than the docs
   suggest and the right answer is a graceful
   rejection.
3. **Add a "concurrent" task per group.** A task that
   runs the same function twice in parallel and
   checks the outputs are consistent.
4. **Add a "round-trip" task.** A task that takes the
   output of one function and feeds it as input to
   another, and checks the result is correct.
5. **Add a "performance" task.** A task that runs the
   function 1000 times and asserts p99 < some bound.
6. **Add a "no-network" task.** A task that runs the
   function with no network access and asserts it
   still returns a sensible answer.
7. **Add a "second-instance" task.** A task that
   constructs the function twice and asserts they
   don't share state.
8. **Add a "resource-cleanup" task.** A task that
   runs the function and asserts no goroutines,
   file handles, or temp files are leaked.
9. **Add a "documentation" task.** A task where the
   agent has to *document* a function (write a
   docstring that matches a fixture's expected
   docstring) — this catches a class of agent
   failure where the code works but the public
   surface is undocumented.
10. **Add a "negative space" task.** A task where the
    function should NOT call a specific API or
    trigger a specific event. (e.g., "fetch the
    channel list, but do NOT make a network call to
    the channels endpoint — use the cache.")

### Held-out set (the invisible test set)

11. **Use the docs' "see also" links.** If the public
    docs for one API mention a related API in a
    "see also," the held-out task should require
    both.
12. **Use the docs' "common pitfalls."** Most public
    API docs have a "common pitfalls" or "gotchas"
    section. Each pitfall is a held-out task.
13. **Use the bug tracker / changelog.** The public
    changelog of most APIs lists the bugs that were
    fixed in each version. Each fix implies a
    behavior that *used to* fail. Those are held-out
    tasks.
14. **Use the rate limits.** A held-out task that
    calls the function 1000 times in 60 seconds
    and asserts the rate-limit response comes back
    at the documented threshold.
15. **Use the auth model.** A held-out task that
    calls the function with a missing or invalid
    auth token and asserts the specific documented
    error.

### Instruments (the things that measure the loop)

16. **Add a "design set freshness" instrument.** Run
    it before each cycle; assert that the design set
    hasn't been modified since the last cycle (the
    agent shouldn't be able to change the test to
    pass it).
17. **Add a "held-out unread" instrument.** Run it
    before each cycle; assert that the agent's
    transcript contains zero references to the
    held-out path. (The agent is reading the test.)
18. **Add a "wall-clock per cycle" instrument.**
    The loop's wall-clock budget is total, not
    per-cycle. Add a per-cycle budget that
    contributes to the score, so a fast-improving
    cycle ranks above a slow-improving one.

### Target (the loss function itself)

19. **Make the target a list, not a number.** V0
    targets are usually `pass_rate >= 0.8`. Better
    target: `pass_rate >= 0.8 AND p99_latency < 200ms
    AND no agent-modified-test-files AND held_out
    delta < 0.2`. The loop can't game a multi-axis
    target.
20. **Add a "specificity" reward.** Beyond pass/fail,
    reward candidates that are *smaller* (fewer
    lines, fewer files, fewer dependencies). The
    simplest candidate that passes is the best
    candidate. This is a strong anti-overfit
    signal.

## See also

- `skills/meta-loss-function-development/references/harness-completeness-checklist.md`
  — the 8-section checklist the meta-skill walks
  through with you. Run this *before* you paste the
  `/goal` prompt.
- `skills/harness-engineering/SKILL.md` — the
  play-book for designing the harness itself. Read
  this if you want to understand *why* the
  expansions above work.
- `skills/loss-function-design/SKILL.md` — the
  4-piece loss anatomy. The "V0 → V1" expansion
  above is a translation of the 4-piece spec into
  concrete changes.
- `examples/lfd-system-verifier/` — a real LFD
  harness used to verify the LFD system itself.
  Read its `verifiers/` and `test-tasks/` to see
  what a complete harness looks like in practice.



