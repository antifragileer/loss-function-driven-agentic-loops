# Building a Great Harness

This is a manual for the human in the loop (HITL) when
you want to use a coding agent to do a non-trivial task
well. The LFD (Loss-Function Driven) pattern is one way
to do that. The pattern works at *any* harness quality —
but the *quality of the result* is a near-direct function
of *the quality of the harness*. A great harness turns a
plain coding agent into something that converges on a
strong solution. A thin harness turns it into something
that plateaus at "OK."

If you have never used LFD before, read **What the
harness actually does** first. If you have used a plain
`/goal` or "ask the AI to write X" prompt and it "kind of
worked," the **V0 → V1: Expand the first attempt** section
is where the leverage is. If your loop is already
running, skip to **V1 → V2+: Iterate on the harness
while the loop runs**.

## What the harness actually does

Think of the AI as a student taking a test. The
"harness" is everything around the test: the questions,
the answer key, the timer, the calculator, the rules
about what books the student can bring in.

```
                ┌──────────────────────────────────┐
                │           THE HARNESS             │
                │                                  │
                │  The questions the AI sees       │
                │  The answer key the AI does NOT  │
                │  The timer ("2 hours max")       │
                │  The rules ("don't read the      │
                │  answer key", "no network")      │
                │  The grader ("right answer =     │
                │  pass, wrong = fail")            │
                │  The score ("8/10 questions      │
                │  right = 80%")                   │
                │                                  │
                └──────────────────────────────────┘
                              ▲
                              │ takes the test
                              │
                          ┌───┴───┐
                          │  AI  │
                          └───┬───┘
                              │
                              ▼
                ┌──────────────────────────────────┐
                │  GRADED RESULT: pass / fail,     │
                │  plus a score 0.0 - 1.0          │
                └──────────────────────────────────┘
```

The "score" in the picture is the **loss function**.
A low score means the AI is far from done. A high score
means the AI is close. The loop runs the AI again and
again, with the goal of making the score go up. That's
all "loss-function driven" means: a number the loop
tries to make bigger (or smaller, depending on the
convention).

A plain prompt is like giving the student a question and
hoping for the best. A harness is like giving them a
*practice test* with a known answer key, a timer, and a
grader — and then running them through it 50 times,
studying what they get wrong, and giving them another
chance. The harness is the practice test.

### Why bother with a harness

A plain prompt gives you one shot. A harness lets the AI
improve over many shots, with measurable feedback. Three
concrete differences:

1. **You can stop the loop at any time and see whether
   the AI is making real progress.** The log shows each
   attempt: what the AI tried, what it expected to go
   wrong, what actually went wrong, and what the score
   is. A plain prompt gives you a single answer; you
   have to read it and judge for yourself.
2. **The AI can't quietly cheat.** A good harness has
   questions the AI has never seen (the "held-out" set).
   If the AI memorizes the visible questions, the
   hidden questions catch it. A plain prompt has no
   hidden questions.
3. **You can hand the harness to someone else and they
   can re-run the loop.** A plain prompt is one
   conversation; a harness is a reusable artifact.

### The four parts of every harness

Every harness has the same four parts. If any of them
is missing, the loop will fail in a predictable way.

**1. The target — what does "good" look like?**

A description of what the AI is trying to produce.
"The function should return the channel list as a
JSON array" is a target. "Build a Slack clone" is not
a target — it's a wish.

The target needs to be **specific and measurable**.
Not "the code is good" but "this function takes a
channel name and a message, posts the message, and
returns the message ID; the test runs the function
and checks the returned ID matches the message the
mock server received."

Before you write the target, the prior question is
*do you actually know what you want?* "Specific
and measurable" is downstream of having a clear
preference. See
[`WHAT-YOU-WANT.md`](./WHAT-YOU-WANT.md) for the
2×2 of preferences (imperative vs declarative,
strategic vs tactical) and the 5-question
Socratic-discovery template that produces a
target specific enough to be measured.

A good target is also **hard to memorize**. If the
target is "pass these 5 questions," the AI will
memorize the 5 questions and pass them without
learning anything. A good target has 50-200 examples
the AI has never seen, and the AI has to learn the
*pattern* to pass them.

**2. The constraints — what the AI is not allowed to do**

The rules. "No more than 2 hours wall-clock." "No
more than $5 of API spend." "You can't read the held-
out directory." "You can't change the test file."

A constraint without an instrument (below) is not a
real constraint. The AI will break it because it has
no way to know it's breaking it. Writing "no network
calls" in the prompt doesn't work. Shipping a CLI
command that checks "did the AI make a network call?"
and refuses to score if it did — *that* works.

**3. The instruments — the things that measure**

A CLI command, or a script, or a test, that the loop
can run to check the AI's work. Every constraint needs
an instrument. Every part of the target needs an
instrument.

Examples:
- "The function should return in < 100ms" → a timer
  that measures the function call
- "No network calls" → a network monitor that
  records every outbound request
- "The test should pass" → the test runner itself
- "No more than 1000 lines of code" → a `wc -l` on
  the candidate

If a constraint has no instrument, it's a wish. The
AI will violate it because it cannot tell it is
violating it.

**4. Forced entropy — what to do when the AI gets stuck**

The loop runs the AI many times. After enough rounds,
the AI will find itself doing the same small thing
over and over, getting a tiny bit better each time.
This is called "hitting a wall" or "local maximum" —
the AI is on a small hill and can't see the bigger
hills.

The fix: when the AI's score stops improving, *force
it to try something different*. The harness tells the
AI: "You haven't improved in 3 rounds. Stop tweaking
the same thing. Try a completely different approach."

This is one of the most important parts of the
harness, and one of the easiest to skip. A harness
without forced entropy will grind forever on the
same small improvement and never escape.

### The "3 cheats" story — why all of this matters

The most important reason to use a harness is that
the AI will cheat if you let it. Here's a real
sequence of what happens when you don't fence off
the cheating:

**Round 1 (5 minutes):** You give the AI a test with
30 questions. The AI memorizes the 30 questions, and
the answers, in 5 minutes. The grader says 100% pass.
But the AI didn't learn anything — it just memorized.
*Score: 100%. Real quality: 0%.*

**Fix:** Hide the answer key from the AI. Now the AI
can't memorize because it can't see the answers.

**Round 2 (20 minutes):** Without the answer key, the
AI runs the test, gets 25/30 right. You tell it "you
missed these 5." The AI notices: every miss becomes a
keyword to add to its next attempt. After a few rounds,
the AI has memorized 30 keywords (one per question) and
gets 100% again. *Score: 100%. Real quality: 0%.*

**Fix:** Make the test bigger. 200 questions instead
of 30.

**Round 3 (30 minutes):** With 200 questions, the AI
tries to memorize 200 keywords. The keyword list
balloons to hundreds of entries. The grader still says
100% — but the AI is just keyword-matching, not actually
solving the problem. *Score: 100%. Real quality: 0%.*

**Fix:** Block the cheating. Cap the keyword list. Force
the AI to use real logic. Require the test cases to
cover edge cases the AI hasn't seen. Now the only way
to get 100% is to actually be good at the task.

**Round 4 (30 hours):** The AI runs. It can't cheat
anymore. It actually learns. After 30 hours, it
produces something that's not just a memorizer — it's
genuinely better at the task. The final score is high
because the AI is actually good. *Score: high. Real
quality: high.*

This is the entire reason the harness exists. **Every
shortcut you don't block is a direction the AI will
sprint down.** The harness is what blocks the
shortcuts so the only path forward is the right one.

## V0 → V1: Expand the first attempt

The AI's first draft of a harness, in response to a goal
like "build a Slack clone in Go," will look like this:

- 5 questions, all on the same shape ("write a function
  that does X")
- 5 hidden questions lifted from the public docs, often
  at exactly the same shape as the visible ones
- Measurement tools that just print placeholder values
  like "100"
- A grader that checks "the file exists" rather than
  testing behavior

This V0 harness is functional. The loop will run. The
score will move. But the score will stop moving quickly
because the harness is measuring the wrong things. Your
job in V0 → V1 is to expand the harness so it measures
the *right* things.

### The V0 expansion checklist

Walk through this with the AI *before* you paste the
`/goal` prompt into the loop session. Each item is a
specific expansion. Don't skip any.

**1. Triple the question set, not double it.** Five
questions aren't enough. Aim for 15-25 questions across
deliberately different shapes:
- 5-6 happy-path questions ("the basic case works")
- 5-7 error/edge cases ("what happens when the input is
  empty, missing, oversized, or weird")
- 3-5 cross-cutting questions (a question that exercises
  2-3 components at once — the kind that breaks naive
  solutions)
- 2-4 negative questions (a question where the right
  answer is *not* to do something — "the function should
  NOT crash, NOT block, NOT retry forever")

The negative questions are the ones the AI will skip by
default. Insist on them. They catch the largest class
of AI failures: over-eager implementations that do too
much.

Negative questions are the **imperative tactical**
quadrant of the 2×2 in
[`WHAT-YOU-WANT.md`](./WHAT-YOU-WANT.md) §2 — the
agent is forbidden from a specific path, not
encouraged toward a specific outcome. The
happy-path questions are the **declarative tactical**
quadrant — the agent chooses how. The 20/80
rule (20% imperative, 80% declarative) from
§3 of that doc is the design check for whether
your question set is balanced.

**2. Make the hidden test set *categorically different*
from the visible one.** A common V0 mistake: the AI
reads the public docs, sees 30 examples, and uses 5 for
the visible test + 5 for the hidden test. The AI
memorizes the category. The right structure:

- Visible test: standard examples from the public docs
- Hidden test: things the public docs *mention* but
  don't fully explain (rate limits, retry behavior,
  auth edge cases, error format quirks)

The hidden test should make the AI *think* about the
problem, not match patterns.

**3. Replace every placeholder grader.** A V0 grader
often just checks "the file exists" or "the function
compiles" — those are smoke tests, not graders. A real
grader:
- Returns "pass" (exit 0) on real success
- Returns "fail" (non-zero exit) on real failure
- Has a *deterministic* check (assertion, file diff,
  test run, JSON shape match)
- Takes less than 60 seconds to run
- Has at least one *negative* check
  (e.g., "the function must NOT call `time.Sleep`")

If a grader doesn't have a negative check, the AI can
pass it with an empty function and a comment. That's
not a real test.

**4. Add a cross-task grader.** Beyond the per-question
graders, add one that runs after the whole test set
and checks a property that spans questions (e.g.,
"no two questions import the same helper", "the
artifact is under 100KB", "no test takes longer than
30 seconds"). This catches architectural problems
that per-question graders miss.

**5. Make the measurement tools actually measure.** V0
measurement tools often just `echo "100"` (claiming
"100% budget remaining") or `cat /dev/null` (claiming
"no tokens used"). Insist that each measurement tool:
- Reads a real log / queries a real API / parses a
  real file
- Returns a real number, not a placeholder string
- Fails loudly (non-zero exit) on its own internal
  error (file missing, parse broken) — but does NOT
  fail on a "constraint violated" condition (that's
  the loop's job, not the instrument's)

A constraint without a real instrument is a wish. The
AI will violate it because it cannot tell it is
violating it.

**6. Write the rules file (`AGENTS.md`) in your own
voice.** The V0 rules file is a generic "operating
rules" list. Replace it with what *you* would want a
new engineer to read on their first day:
- What this project is, in 2 sentences
- The 3-5 hard rules (what NOT to do)
- The log format
- The "go look at X first" links (your docs, your
  conventions, your anti-patterns)

The AI reads the rules file every round. The more
project-specific it is, the more the loop converges on
*your* project, not on a generic one.

**7. Add 3-5 explicit anti-cheat guards.** Think about
how a determined AI could game your grader. Common
cheats:
- The AI deletes the test file
- The AI writes a stub that always returns the
  expected output
- The AI adds a `sleep` to make a timeout pass
- The AI modifies the rules file to remove the hard
  rule
- The AI reads the hidden test directory

For each cheat, add a check to a `verifiers/integrity.sh`
script that runs *before* scoring and refuses to score
if the cheat is detected.

**But which check catches which cheat?** The "anti-cheat
firewall" isn't a single script. It's **four layers**,
and the held-out grader is just one of them. A cheat
slips through if the wrong layer is the only one
covering it.

### The 4 layers of anti-cheat defense

Every guard in the harness maps to exactly one of these
four layers. If a cheat is not covered by *some* layer,
it will happen. If a cheat is covered by *one* layer
but that layer is misconfigured, the cheat still
happens. The layers are independent — a single layer
failing does not collapse the others.

| Layer | Mechanism | Runs when | Catches |
|---|---|---|---|
| **1. Integrity** | `verifiers/integrity.sh` — static checks on harness files | Before each cycle, before any scoring | The AI editing the *harness* (grade.sh stubs, sleep in grader, rules-file tampering) |
| **2. Held-out grader** | `verifiers/private/grader.sh` runs the *finished* candidate against `test-tasks/held-out/` | After the loop ends | The AI passing the visible test by cheating in a way the visible test can't see (wrong parser shape, missing force-entropy, non-deterministic install) |
| **3. Hidden-unread** | `verifiers/instruments/hidden-unread.sh` greps the AI's transcript for held-out task names and `verifiers/private/` paths | After each cycle, before scoring | The AI *reading* the exam during the run |
| **4. Test-freshness** | `verifiers/instruments/test-freshness.sh` SHA-checks the design set's `grade.sh` files | Before each cycle | The AI editing a `grade.sh` to make a failing design task pass |

**Layer 1 is the primary defense.** It runs every
cycle, before the agent is graded, and refuses to
score the cycle if any guard fires. The default
guard set covers the 5 cheats listed above. **You
add project-specific guards** — the 4 defaults are
the scaffold's known cheats, not yours.

**Layer 2 is the strongest behavior-level check.**
The held-out directory is `chmod 700`, the grader
is `chmod 600`, and `AGENTS.md` says "DO NOT read
`verifiers/private/`." The held-out grader runs
the *finished* candidate — the AI has already
stopped, so it can't change anything mid-grade.
The held-out tasks test properties the visible
test can't see: parser shape across all 5 adapters,
install determinism, force-entropy wiring, drift
opt-in, compatibility-matrix consistency.

**Layer 3 is the tripwire.** If the AI *reads* the
held-out surface during the run, the cycle is
rejected. This is what stops the memorization cheat
described in the 3-cheats story above.

**Layer 4 is the test-file guard.** The agent can't
edit a `grade.sh` to make a failing design task
pass without the SHA changing.

### Cheat → defense mapping (what catches what)

The V0 cheats from the list above, mapped to the
layer that catches them. If a cheat has no layer
listed, *the harness does not catch it* and you
need to add a guard.

| The cheat | Caught by | Default guard in scaffold? |
|---|---|---|
| AI deletes a test file | Layer 4 (test-freshness) — SHA changes | Yes |
| AI writes a stub grade.sh that always returns 0 | Layer 1 (no-stub-always-pass) | Yes |
| AI adds `sleep` to mask a timing failure | Layer 1 (no-sleep-in-grader) | Yes |
| AI removes the held-out rule from AGENTS.md | Layer 1 (agents-md-has-hard-rules) | Yes (but only AGENTS.md) |
| AI reads `verifiers/private/` | Layer 3 (hidden-unread) + chmod 600 | Yes |
| AI memorizes the visible 5 questions | Layer 2 (held-out is different tasks) | Yes |
| AI reverse-engineers the miss list | Layer 2 + design set widened in V0→V1 | Partial — see honest gaps below |
| AI enumerates a finite eval | The eval is widened, but is also finite | No — see 3-cheats story |
| AI edits `.gitleaksignore` to suppress secrets | No layer in default scaffold | **Add Layer 1 guard: no-secret-ignore-edit** |
| AI removes `package-lock.json` / `go.sum` | No layer in default scaffold | **Add Layer 1 guard: no-deps-lockfile-removed** |
| AI ships a perf-budget endpoint that's `/health` (cached) | No layer in default scaffold | **Add Layer 1 guard: perf-endpoint-real** |
| AI makes the parser emit JSON only on a specific model | No layer in default scaffold | **Add Layer 2 task: parser-shape-across-adapters** |
| AI removes the forced-entropy rule from cycle.sh | Layer 2 (h4-force-entropy-trigger) | Yes |
| AI changes the model name field by hand to bypass drift | Layer 2 (h3-drift-opt-in) | Yes |

The bottom four rows are cheats the *default*
scaffold does not cover. They are in the "you add
this" category. The
`skills/meta-loss-function-development/references/harness-completeness-checklist.md`
file is the canonical list of guards every project
should ship.

### The honest gaps

The 4-layer defense is good, not perfect. The
following gaps are *known* — they are not bugs,
they are the boundaries of what a static-analysis
defense can catch.

1. **The held-out is also finite.** If the AI had
   access to the full test set (design + held-out),
   it could enumerate. The defense is that the
   held-out is *narrow* (5 tasks by default) and
   tests *architectural* properties (parser shape,
   install determinism, force-entropy), not
   exhaustive functional tests. Widening the
   held-out from 5 to 50 tasks does not close this
   gap — the agent can still enumerate 50.

2. **The held-out grader runs the finished
   candidate, not the loop behavior.** If the
   agent's loop driver is broken in a way that
   doesn't surface in the held-out tasks, it's not
   caught. h4-force-entropy-trigger checks that
   the rule is *wired*; it doesn't check that the
   rule *actually fires* on a 5-cycle stall in a
   different scenario.

3. **The 4 default integrity guards are a small
   set.** They cover the scaffold's known cheats,
   not your project's specific cheats. The default
   set is `no-grade-todo-stub`,
   `no-stub-always-pass`, `no-sleep-in-grader`, and
   `agents-md-has-hard-rules`. The first three are
   universal. The fourth is `AGENTS.md`-specific.
   For your project, you will need at least 1-3
   more (see the table above for the common ones).

4. **The agent can read `verifiers/integrity.sh`.**
   The integrity guards are public (not chmod'd).
   A smart agent can study them and learn exactly
   what to avoid. The held-out grader (chmod 600)
   is the only surface the agent *cannot* study.
   This is why Layer 1 catches *unintentional*
   cheating and Layer 2 catches *intentional*
   cheating.

5. **No git-status snapshot.** The verifier runs
   against the committed version of the candidate.
   If the agent's last commit differs from what it
   actually ran (e.g. it tested locally, then
   committed a different version), the verifier
   still scores the committed version. A
   `git-status`-aware verifier would close this
   gap; the current scaffold does not include one.

6. **The 3-cheats pattern is not fully solved.**
   The 3-cheats story above describes a sequence
   where each fix is met with a new cheat. The
   4-layer defense addresses each cheat with a
   specific layer, but the *class* of "agent
   optimizes exactly the target you give it" is
   not closed. The mitigation is to widen the
   target (multi-axis), keep the eval growing
   (don't ship a fixed-size test set), and force
   entropy on stalls.

### How to test the strength of your held-out defense

The held-out grader is the strongest layer, but
only if it actually catches what it's supposed to
catch. The recipe:

1. **Introduce an intentionally broken harness.**
   Pick one held-out task (e.g. h4) and break the
   behavior it's testing (e.g. remove the
   forced-entropy logic from `cycle.sh`).
2. **Run the verifier.** Confirm the held-out task
   fails (`h4-force-entropy-trigger` returns
   `score=0.0`).
3. **Restore the harness.** Re-add the
   forced-entropy logic, re-run. Confirm h4 passes
   again.

If the intentionally-broken harness still passes
the held-out task, the held-out defense is broken.
Common causes:

- The held-out task's `grade.sh` is a stub that
  always returns 0 (Layer 1 should catch this).
- The held-out task's `prompt.txt` doesn't
  exercise the broken behavior.
- The held-out grader is reading the wrong path
  (cycle.sh writes to `logs/cycle-1/`, the grader
  reads from `logs/`).

The
`skills/lfd-system-verifier/references/fixture-vs-wrapper-grader.md`
reference has a more elaborate version of this
test (the "always-fail-wrapper" test) that catches
a class of bugs where the per-task grader doesn't
read the wrapper's output at all.

### Anti-cheat guard template

When you add a project-specific guard to
`verifiers/integrity.sh`, follow this template:

```bash
# ----- guard: <short name> -----
# <one-line description of the cheat this prevents>
check_<short_name>() {
  local project_root="$1"
  # <bash/python check — return 0 if clean, 1 if violation>
}
# Add to the main check loop:
#   check_<short_name> "$project_root" || FAILED+=("<short_name>")
```

Run `verifiers/integrity.sh` standalone to test the
guard in isolation. The script exits 0 if all
guards pass, 1 if any fail, 2 on usage error.

**8. Add a 2-3 line "definition of done" at the top of
the goal file (`GOAL.md`).** The V0 goal file opens
with a long description of the project. Replace the
first 3 lines with:

```
DONE WHEN: <the single testable criterion that
defines success for this project, in one sentence>
NOT DONE WHEN: <the most common ways an AI will
mistakenly claim to be done>
```

The loop reads this. The AI reads this. You read this.
Keep it ruthlessly specific.

`DONE WHEN` and `NOT DONE WHEN` are the
**declarative strategic** quadrant of the
preference 2×2 — the firm-level outcome
you're committing to. When the `DONE WHEN`
line drifts ("we'll know it when we see it"),
the harness will not save you. See
[`WHAT-YOU-WANT.md`](./WHAT-YOU-WANT.md) §2 for
the quadrant classification and §4 for the
Socratic-discovery template that produces a
specific-enough `DONE WHEN`. The two prompt
patterns in §5 (wiggle room, right
generalization) belong in the per-task
`prompt.txt` for each design task, not in
`GOAL.md` itself.

### A sample conversation: V0 → V1

This is a real exchange from expanding a Slack-clone
harness. Use it as a template.

> **You:** The question set is too uniform. All five
> questions are "write a function that does X." Add
> three questions where the function has to handle a
> broken input and return an error, plus two where the
> right answer is to do *nothing* (for example, posting
> to a channel the user isn't in should return a
> specific error code, not retry).

> **AI:** Adding questions 06, 07, 08 for broken inputs
> and 09, 10 for "right answer is no-op"...

> **You:** Question 04's grader passes when the
> function returns nothing for everything. Make it
> check that the return value is a specific struct with
> a non-empty field. And add a negative check: the
> function should NOT call `time.Sleep`.

> **AI:** Updated the grader to check the struct shape
> and search the AI's code for `time.Sleep`...

> **You:** The hidden test set is the same shape as the
> visible one. Replace three of them with rate-limit
> tests (the public docs say "429 after 30 requests
> per minute" — the AI has to actually implement rate
> limiting, not match an example).

This is what working with the AI looks like. You're
not writing the harness; you're directing the AI to
write a *better* harness. Each round of the exchange
makes the harness 10-30% better, and the gains
compound across the loop.

## V1 → V2+: Iterate on the harness while the loop runs

The V0 → V1 expansion is the easy part. You do it
once, in the meta-session, with the AI focused on the
harness. The V1 → V2+ iteration is harder because it
happens *while the loop is running*, and you have to
read the log to figure out when the harness is the
bottleneck rather than the AI's work.

### When to improve the harness vs. let the loop work

The loop's log tells you everything. Read the last
10-20 entries. For each round, look at:

- **What the AI tried:** the change it made
- **What it expected to go wrong:** its prediction
- **The score:** whether the change actually helped

Three patterns, three responses:

**Pattern 1: score stuck at 0.X for many rounds**

The loop is trying and failing. The changes are
sensible but the work doesn't move the score. This
usually means the harness is too narrow — the visible
test isn't covering the failure modes the AI is
hitting.

*Action:* pause the loop, look at the failed-round
transcripts, identify the failure mode the AI is
hitting, add a question that exercises that mode,
restart the loop. Don't change the hidden test — the
hidden test is the real exam, not the practice test.

**Pattern 2: score stuck at 1.0 but the AI's work
looks bad**

The AI is gaming the grader. The visible test is
cheatable — there's a shortcut that passes all the
checks but produces something you don't want.

*Action:* pause the loop, look at the actual AI
output, identify which grader is being gamed, tighten
that grader with a real-behavior check, restart the
loop. The hidden test will likely catch the gaming on
the next run, but don't wait for that — fix the
visible grader directly.

**Pattern 3: score oscillating (0.4, 0.8, 0.3, 0.7,
0.2, 0.9...)**

The AI is making changes, scoring, sometimes
regressing. The loop is trying to escape but not
making net progress. This usually means the harness
is rewarding a *proxy* for the real goal, and the
proxy has multiple local maxima the AI is jumping
between.

*Action:* pause the loop, look at the highest-scoring
output, look at the lowest-scoring output, look at
what distinguishes them. The proxy is probably
something like "uses a specific function call" or
"matches a specific output shape." Replace the proxy
with a behavioral check (e.g., "the function
completes in < 1 second" instead of "the function
calls `slack.PostMessage`").

### The "the loop is stuck" playbook

When the loop has been running for more than 2 hours
with less than 10% improvement, stop and read the log
end-to-end. The pattern usually emerges:

1. **Last 5 changes are minor variations of each
   other** → the AI is on a small hill. The forced-
   entropy rule should have caught this, but the rule
   is too gentle. Make the rule stricter, or push
   the loop out manually.

2. **Last 5 changes are unrelated** → the AI has no
   idea what to try. The harness is too broad and
   the AI is sampling randomly. Tighten the target:
   pick the 3-5 questions that matter most and
   disable the rest temporarily. The loop will
   converge on a smaller problem faster.

3. **Score is 1.0 for 2+ rounds but you don't
   believe the output** → the harness is
   cheat-able. The log will lie. Don't trust it. Read
   the output, find the cheat, tighten the grader.

4. **Hidden score is way below visible score** →
   the AI is overfitting to the visible test. Add
   questions that span the gap between visible and
   hidden (these are sometimes called "validation"
   questions — they live in the visible test but act
   like a hidden-lite).

### Things that look like harness problems but aren't

- **"The AI is making dumb mistakes"** → usually a
  prompt problem, not a harness problem. The AI
  needs a clearer instruction in the per-question
  prompt. Improve the prompt, not the harness.
  The "dumb mistakes" are usually the agent
  filling in a missing preference with its own
  default — your `prompt.txt` left a gap and
  the agent picked one. See
  [`WHAT-YOU-WANT.md`](./WHAT-YOU-WANT.md) §2
  (the 2×2) and §5.1 (wiggle room) for the
  pattern that closes the gap without
  over-specifying.
- **"The AI runs out of tokens"** → the wall-clock /
  tokens-remaining measurement tools are reporting
  wrong, OR the questions are too big (a single
  question is the size of three). Check the tools; if
  they're right, split the question.
- **"The AI's output is good but the log is messy"**
  → not a problem. The log is for the AI and the
  grader, not for you. Leave it.
- **"The loop finished but I want a different
  solution"** → the hidden test is the answer. If
  the visible score is 1.0 and the hidden test is
  satisfied, the loop found the optimum *of the
  harness*. Change the harness, not the loop.

### The V1 → V2 HITL cycle

When the loop is running, you have a few different
shapes of HITL:

**Asynchronous** (you read the log every few hours):
- `tail -f logs/iteration-log.md` in a terminal
- Check for the three stuck patterns above
- Add a manual entry to the log if you want to push
  the AI in a direction

**Synchronous** (you're in the loop session):
- The loop prompt says to stop and report if
  something is wrong. When the AI stops, the
  conversation is the HITL. Most often the right
  answer is "tighten this grader" or "add this
  question."

**Batch** (the loop finishes):
- Read `logs/best-cycle.json` to see the final score
- Read the winning output
- If the output is good: ship it.
- If the output is bad but the score was 1.0: the
  harness is wrong. Go back to the meta-session, fix
  the harness, re-run.
- If the output is bad and the score was <1.0: the
  loop didn't have time. Increase budget, re-run.

**The loop is a tool; the harness is the design.**
Improving the loop (more rounds, better entropy rules,
faster AI) is 20% of the leverage. Improving the
harness (better questions, tighter graders, real
measurement tools) is 80%.

## Ideas bank: 20 specific ways to make a V0 harness better

These are tactics that consistently move the needle.
Pick the ones relevant to your project; don't try to
do all 20.

### Visible test set (the practice questions)

1. **Add an "empty input" question per group.** A
   question where the input is `""`, `null`, or `[]`
   and the right answer is a specific error.
2. **Add an "oversized input" question per group.** A
   question where the input is 10x larger than the
   docs suggest and the right answer is a graceful
   rejection.
3. **Add a "concurrent" question per group.** A
   question that runs the same function twice in
   parallel and checks the outputs are consistent.
4. **Add a "round-trip" question.** A question that
   takes the output of one function and feeds it as
   input to another, and checks the result is
   correct.
5. **Add a "performance" question.** A question that
   runs the function 1000 times and checks the
   slowest run is under some time bound.
6. **Add a "no-network" question.** A question that
   runs the function with no network access and
   checks it still returns a sensible answer.
7. **Add a "second-instance" question.** A question
   that constructs the function twice and checks
   they don't share state.
8. **Add a "resource-cleanup" question.** A question
   that runs the function and checks no leftover
   processes, file handles, or temp files exist.
9. **Add a "documentation" question.** A question
   where the AI has to *document* a function (write
   a comment that matches a fixture's expected
   comment) — this catches a class of AI failure
   where the code works but the public surface is
   undocumented.
10. **Add a "negative space" question.** A question
    where the function should NOT call a specific
    helper or trigger a specific event. (For
    example, "fetch the channel list, but do NOT
    make a network call — use the cache.")

### Hidden test set (the real exam)

11. **Use the docs' "see also" links.** If the
    public docs for one function mention a related
    function in a "see also," the hidden question
    should require both.
12. **Use the docs' "common pitfalls."** Most public
    docs have a "common pitfalls" or "gotchas"
    section. Each pitfall is a hidden question.
13. **Use the changelog.** The public changelog of
    most products lists the bugs that were fixed
    in each version. Each fix implies a behavior
    that *used to* fail. Those are hidden questions.
14. **Use the rate limits.** A hidden question that
    calls the function 1000 times in 60 seconds and
    checks the rate-limit response comes back at the
    documented threshold.
15. **Use the auth model.** A hidden question that
    calls the function with a missing or invalid
    auth token and checks the specific documented
    error.

### Measurement tools (the things that measure the loop)

16. **Add a "test freshness" tool.** Run it before
    each round; assert that the visible test
    hasn't been modified since the last round
    (the AI shouldn't be able to change the test
    to pass it).
17. **Add a "hidden unread" tool.** Run it before
    each round; assert that the AI's transcript
    contains zero references to the hidden test
    directory. (The AI is reading the exam.)
18. **Add a "wall-clock per round" tool.** The
    loop's wall-clock budget is total, not per-
    round. Add a per-round budget that contributes
    to the score, so a fast-improving round ranks
    above a slow-improving one.

### Target (the score itself)

19. **Make the target a list, not a number.** A
    V0 target is usually "pass rate >= 0.8."
    Better: "pass rate >= 0.8 AND p99 latency <
    200ms AND no AI-modified test files AND
    hidden-test delta < 0.2." The loop can't
    game a multi-axis target.
20. **Add a "smallness" reward.** Beyond pass/fail,
    reward outputs that are *smaller* (fewer
    lines, fewer files, fewer dependencies). The
    simplest output that passes is the best
    output. This is a strong anti-overfit signal.

## Why the harness is the moat

The product is the AI's output, and the AI's output
is bounded by what the harness measures. A weak
harness produces a weak output. A strong harness
produces a strong output. The company that owns the
strongest, most private test set wins, because their
test set is something the AI of any competitor can't
see or train against.

This is why all the work in this document matters.
The 20 ideas in the bank aren't busywork — they're
how you build a test set that no one else has. The
expansion checklist is how you make it hard to cheat.
The 3-cheats story is why the test set has to be
fenced off. The 4-part anatomy is how you keep the
test set honest as the loop runs.

A great harness is the single most leveraged thing
in this whole system. Build it well.

## See also

- [`WHAT-YOU-WANT.md`](./WHAT-YOU-WANT.md) — the
  companion to this document. Read it *first* if
  you have not yet decided what you want the
  harness to measure. The 2×2 of preferences
  (imperative vs declarative, strategic vs
  tactical), the 20/80 taste rule, the
  Socratic-discovery template, and the two
  prompt patterns (wiggle room, right
  generalization) are the upstream decisions
  this document assumes you have already made.
- `skills/meta-loss-function-development/references/harness-completeness-checklist.md`
  — the 8-section checklist the meta-skill walks
  through with you. Run this *before* you paste the
  `/goal` prompt.
- `skills/harness-engineering/SKILL.md` — the playbook
  for designing the harness itself.
- `skills/loss-function-design/SKILL.md` — the
  4-part loss anatomy in technical detail. The "4
  parts of every harness" section above is the
  plain-language version.
- `examples/lfd-system-verifier/` — a real LFD
  harness used to verify the LFD system itself.
  Read its `verifiers/` and `test-tasks/` to see
  what a complete harness looks like in practice.

