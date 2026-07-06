# Companion Frameworks (inlined for self-containment)

This file inlines the framework content the LFD thinking
gates reference. The canonical source-of-truth lives in
`WHAT-YOU-WANT.md` and `BUILDING-A-GREAT-HARNESS.md` in the
LFD repo (https://github.com/antifragileer/loss-function-driven-agentic-loops).
If you have access to those files, treat them as authoritative.
If you don't (e.g. installed via `npx skills add` without
the repo), this file is the canonical version of the
frameworks the gates use.

---

## Part 1: The 2x2 of preferences (`WHAT-YOU-WANT.md` §2)

Two questions put every rule in the harness into one of
four boxes.

**Question 1: Imperative or declarative?**
- *Imperative.* The path is fixed. The agent is told exactly how.
- *Declarative.* The outcome is fixed. The agent picks the path.

**Question 2: Strategic or tactical?**
- *Strategic.* True for every project in the firm. A firm-level rule.
- *Tactical.* True for this one project. A project-level rule.

| | Strategic (firm) | Tactical (project) |
|---|---|---|
| Imperative (path) | `AGENTS.md` hard rules; the 4 `verifiers/integrity.sh` guards; the `chmod 600` held-out grader. The agent **cannot** change these. | `test-tasks/<id>/grade.sh` negative checks (e.g. "do NOT call `time.Sleep`"). Project-level, but the specific failure mode is not up for debate. |
| Declarative (outcome) | The `docs/loss-functions/<name>.md` rubric; firm-wide success line in `GOAL.md`'s `DONE WHEN`; golden-principle linters. The agent **may** change these *if* it raises the change. | `test-tasks/<id>/prompt.txt` happy-path description; the visible test set's positive questions; the legibility rubric. |

**Routing rules:**
- "Every project" + "exact path" → `AGENTS.md` or `verifiers/integrity.sh`. Mechanical, exit-coded.
- "Every project" + "outcome" → rubric.
- "This project" + "exact path" → per-task `grade.sh` negative check.
- "This project" + "outcome" → per-task `prompt.txt`.

---

## Part 2: The 20/80 taste rule (`WHAT-YOU-WANT.md` §3)

Good agentic engineering is knowing how strict each rule
should be. **20% of the harness is imperative, 80% is
declarative.** The 20% is what the user is not willing to
negotiate. The 80% is what the user is handing over.

The 4 default `verifiers/integrity.sh` guards sit entirely
in the imperative-strategic box. The rubric and positive
questions sit in the declarative boxes. The mix is the
design choice.

When writing a new `grade.sh`, ask of each line: is this
telling the agent the *outcome* (declarative) or the
*forbidden path* (imperative)? A line that says "the output
must include key X" is declarative — the agent can satisfy
it any way. A line that says "the source must not contain
Y" is imperative.

---

## Part 3: The 5-question Socratic discovery (`WHAT-YOU-WANT.md` §4)

For each design task in `test-tasks/design/<id>/`, ask:

1. **What are the 3 assumptions in this harness that, if
   wrong, would break the visible test?** (E.g. "the
   parser is a Python script" / "the agent has network
   access during grading" / "the wrapper emits the 8
   shared keys in this order.")
2. **For each, what is the cheapest negative check I can
   add to `grade.sh`?** Pattern: a `grep -qE` over the
   source for forbidden code, or a structural check.
3. **Which assumptions are firm-level (true for every
   project) and which are project-level (true only
   here)?** Firm-level → `integrity.sh` guards.
   Project-level → per-task negative checks.
4. **Of the firm-level ones, which deserve a held-out
   task?** Held-out tasks are expensive. Spend them on
   assumptions the visible test cannot see.
5. **Of the project-level ones, which belong in
   `AGENTS.md` as a hard rule vs in the per-task
   `prompt.txt` as a description?** If it affects more
   than one design task, it belongs in `AGENTS.md`. If
   only one, it belongs in that task's `prompt.txt`.

---

## Part 4: Wiggle room (`WHAT-YOU-WANT.md` §5.1)

The pattern: state the imperative preference, then add a
declarative addendum that surfaces better designs the
agent might find.

**Bad** (`test-tasks/<id>/prompt.txt`):
```
Implement <X>. Use <specific approach A>.
```

**Good**:
```
Implement <X>. Use <specific approach A>.

If you discover a design that achieves the objectives
in DONE WHEN better than approach A, raise it as an
option in your iteration-log.md entry before
proceeding. Do not implement the alternative without
surfacing it.
```

Wiggle room belongs in the declarative *tactical* box.
The firm-level rule "every task prompt has a wiggle-room
clause" itself belongs in `AGENTS.md` as a hard rule.

---

## Part 5: Right generalization (`WHAT-YOU-WANT.md` §5.2)

When you would otherwise leak context about a future
project, write the general shape of the connection
instead.

**Bad**:
```
Implement <X>. Later, <X> will need to integrate with
project B by passing <some specific data shape> to it.
```

**Good**:
```
<X> emits <data shape Y>, indexed by <dimension 1> and
columned by <dimension 2>. Any future consumer that
needs <dimension 1> × <dimension 2> matrices can read
from <X>'s output.
```

Right generalization belongs in the imperative *tactical*
box. The shape of the output is not up for debate. The
choice of how to produce that shape is the agent's.

---

## Part 6: The 4-piece loss anatomy (`BUILDING-A-GREAT-HARNESS.md` §"The four parts of every harness")

1. **Target.** What the agent is descending toward.
   Specific and measurable ("function takes channel
   name + message, posts it, returns message ID; test
   runs the function and checks the returned ID matches
   the message the mock server received"). Hard to
   memorize (50-200 examples the agent has never seen).

2. **Constraints.** What the agent is not allowed to do.
   "No more than 2 hours wall-clock. No more than $5 of
   API spend. You can't read the held-out directory.
   You can't change the test file." A constraint
   without an instrument is a wish.

3. **Instruments.** CLI commands, scripts, or tests the
   loop can run to measure. Every constraint needs an
   instrument. "The function should return in < 100ms"
   → a timer that measures the function call. "No
   network calls" → a network monitor. "No more than
   1000 lines of code" → `wc -l` on the candidate.

4. **Forced entropy.** When the loop plateaus, force
   the agent to try something different. "You haven't
   improved in 3 rounds. Stop tweaking the same thing.
   Try a completely different approach." Without
   forced entropy, the loop grinds forever on the
   same small improvement and never escapes.

---

## Part 7: The 4-layer anti-cheat defense (`BUILDING-A-GREAT-HARNESS.md` §"The 4 layers of anti-cheat defense")

| Layer | Mechanism | Runs when | Catches |
|---|---|---|---|
| 1. Integrity | `verifiers/integrity.sh` — static checks on harness files | Before each cycle, before any scoring | Harness edits (grade.sh stubs, sleep in grader, rules-file tampering) |
| 2. Held-out grader | `verifiers/private/grader.sh` runs the *finished* candidate against `test-tasks/held-out/` | After the loop ends | Visible-test workarounds the visible test can't see |
| 3. Hidden-unread | `verifiers/instruments/hidden-unread.sh` greps the agent's transcript for held-out task names and `verifiers/private/` paths | After each cycle, before scoring | Agent *reading* the exam during the run |
| 4. Test-freshness | `verifiers/instruments/test-freshness.sh` SHA-checks the design set's `grade.sh` files | Before each cycle | Agent editing a `grade.sh` to make a design task pass |

**Cheat → defense mapping:**

| Cheat | Caught by | Default guard in scaffold? |
|---|---|---|
| Agent deletes a test | Layer 4 | Yes |
| Agent writes a stub grade.sh | Layer 1 | Yes |
| Agent adds `time.Sleep` | Layer 1 | Yes |
| Agent removes held-out rule from AGENTS.md | Layer 1 | Yes |
| Agent reads `verifiers/private/` | Layer 3 + chmod 600 | Yes |
| Agent memorizes the 5 visible questions | Layer 2 | Yes |
| AI edits `.gitleaksignore` | (none in default) | Add Layer 1: `no-secret-ignore-edit` |
| AI removes `package-lock.json` / `go.sum` | (none in default) | Add Layer 1: `no-deps-lockfile-removed` |
| AI ships perf endpoint that's `/health` (cached) | (none in default) | Add Layer 1: `perf-endpoint-real` |
| AI makes parser emit JSON only on a specific model | (none in default) | Add Layer 2: `parser-shape-across-adapters` |

The 4 default integrity guards:
1. `no-grade-todo-stub`
2. `no-stub-always-pass`
3. `no-sleep-in-grader`
4. `agents-md-has-hard-rules`

---

## Part 8: The 3 stuck-loop patterns (`BUILDING-A-GREAT-HARNESS.md` §"The 'the loop is stuck' playbook")

When the loop has been running for more than 2 hours with
less than 10% improvement, read the last 5-10 entries
of `logs/iteration-log.md`. Three patterns:

1. **Last 5 changes are minor variations of each other** →
   the AI is on a small hill. The forced-entropy rule
   should have caught this, but the rule is too gentle.
   Make the rule stricter, or push the loop out manually.
2. **Last 5 changes are unrelated** → the AI has no idea
   what to try. The harness is too broad and the AI is
   sampling randomly. Tighten the target: pick the 3-5
   questions that matter most and disable the rest
   temporarily.
3. **Score is 1.0 for 2+ rounds but you don't believe
   the output** → the harness is cheat-able. The log
   will lie. Don't trust it. Read the output, find the
   cheat, tighten the grader.

---

## Part 9: Multi-axis target + DONE/NOT DONE block

`GOAL.md` opens with a 2-3 line `DONE WHEN` / `NOT DONE
WHEN` block. `DONE WHEN` is the single testable criterion
for success. `NOT DONE WHEN` lists the most common ways
the agent will mistakenly claim to be done.

The Target section is **multi-axis** — a list of
conditions, not a single number. At least 2 of
`pass_rate` threshold, p99 latency, "no AI-modified
test files" assertion, hidden-test delta, integrity-pass
assertion, or a smallness reward. All axes must hold
simultaneously for the loop to stop on success.

**DONE WHEN / NOT DONE WHEN example:**
```
DONE WHEN: all 5 design tasks pass, all 7 sub-losses >=
0.8, integrity.sh exits 0, pass_rate >= 0.8 on the
held-out grader.

NOT DONE WHEN: pass_rate == 1.0 on the design set but
the held-out score is missing; integrity.sh fails; the
agent declares done without running
verifiers/private/grader.sh; or the agent edits a
grade.sh to make a design task pass.
```

---

## See also (if you have the LFD repo available)

- `WHAT-YOU-WANT.md` — the canonical preference vocabulary.
  Part 1 (2x2), Part 2 (20/80), Part 3 (Socratic 5-Q),
  Part 4 (wiggle room), Part 5 (right generalization).
- `BUILDING-A-GREAT-HARNESS.md` — the canonical harness
  manual. Part 6 (4-piece anatomy), Part 7 (4-layer
  defense), Part 8 (stuck patterns), Part 9 (DONE/NOT DONE).
