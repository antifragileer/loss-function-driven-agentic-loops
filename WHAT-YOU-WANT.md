# What You Want

A companion to `BUILDING-A-GREAT-HARNESS.md`. That
document answers the question "given a target, how do
I build a harness that measures it well?" This
document answers the prior question: "do I actually
know what my target is?"

Implementation is solved by current models. The
bottleneck is the human. The leverage sits in three
places: the **vocabulary** to name what kind of
preference each harness rule expresses, the **taste**
to choose where on the imperative↔declarative dial
each rule belongs, and the **two prompt patterns**
(wiggle room, right generalization) that prevent
over-specification from leaking.

## 1. The bottleneck moved

When models were less capable, you had to specify
the work in ironclad prompts and supply few-shot
examples so the model would get the shape right.
Today, the model can read `AGENTS.md`, skim
`docs/`, look at the public surface, and produce
something close to what you want without your hand
holding every line.

This shifts the work. When implementation is
solved, what separates a 10x agentic engineer from
a 100x one is no longer prompt phrasing — it is the
clarity of the **target**. The agent is searching
over a solution space; the only thing that constrains
the search is what you told it to optimize. Vague
preferences produce vague solutions. Specific
preferences produce specific solutions. The
harness is the contract that turns those
preferences into something measurable.

The rest of this document is the working vocabulary
for getting those preferences specific enough that
the harness can be built.

## 2. The 2×2 of preferences

Two axes:

- **Imperative vs declarative.** Imperative: I
  know the *path*. Declarative: I know the
  *outcome*, the path is yours.
- **Strategic vs tactical.** Strategic: firm-level,
  holds across every project. Tactical:
  project-level, holds for this one.

That gives four quadrants. Each one has a *home*
in this repo, a *form* the rule takes, and a
*default* about whether the agent can override it.

| | **Strategic** (firm) | **Tactical** (project) |
|---|---|---|
| **Imperative** (the path) | `AGENTS.md` hard rules; the 4 `verifiers/integrity.sh` guards; the `chmod 600` held-out grader. The agent **cannot** override these. Mechanical, exit-coded. | `test-tasks/<id>/grade.sh` negative checks (the "do NOT call `time.Sleep`" line, the "parser must not contain `eval`" check). Project-level, but the specific failure mode is non-negotiable. |
| **Declarative** (the outcome) | The `docs/loss-functions/<name>.md` rubric, the firm-wide success criteria in `GOAL.md`'s `DONE WHEN`, the golden-principle linters. Agent **may** override *if* it raises the override and the override is reviewed. | `test-tasks/<id>/prompt.txt` happy-path description; the visible test set's positive questions; the legibility rubric. Project-level; the agent chooses how. |

The matrix isn't descriptive — it's a design
tool. When you add a rule and don't know which
quadrant it belongs in, the four questions are:

1. Is this true across every project in the firm,
   or only this one? (strategic vs tactical)
2. Do I know the *exact path* the agent must take,
   or just the *outcome* I need? (imperative vs
   declarative)

If the answer to (1) is "every project" and (2)
is "exact path," the rule belongs in `AGENTS.md`
or `verifiers/integrity.sh` and is enforced
mechanically. If "every project" and "outcome,"
it belongs in the rubric. If "this project" and
"exact path," it belongs in the per-task
`grade.sh` as a negative check. If "this project"
and "outcome," it belongs in the per-task
`prompt.txt`.

## 3. Taste: the 20/80 rule applied to the harness

Good agentic engineering is knowing how far along
the imperative↔declarative axis to tilt each rule.
A common rule of thumb: **20% of the harness is
imperative, 80% is declarative.** The 20% is the
non-negotiable path; the 80% is the outcome you're
delegating.

Worked example. The 5 design tasks in
`test-tasks/design/` are the harness's visible
training signal. Of those 5:

- **Imperative (20%, ~1 task).** The negative
  checks inside each `grade.sh` — the things the
  agent is *forbidden* from doing. In
  `d1-parse-cline-output/grade.sh`:

  ```bash
  if grep -qE 'eval.*input|exec.*input|subprocess\.call.*shell=True' "$PARSER" 2>/dev/null; then
    NEG_FAIL="parser source contains eval/exec/shell=True"
  fi
  ```

  This is imperative. There is no acceptable
  solution that includes `eval`-of-input. The
  agent cannot override.

- **Declarative (80%, ~4 tasks).** The positive
  assertions — the 8 shared keys, the integer
  type, the non-empty string, the exact
  `tokens=3900`. The agent gets to choose *how*
  to produce a parser that satisfies them. It
  could be hand-written, regex-based, or
  library-driven; the task does not specify.

The 4 `verifiers/integrity.sh` guards sit
*entirely* in the imperative strategic quadrant.
The rubric and the positive questions sit in the
declarative quadrants. The mix is the design
choice.

Concretely, when you write a new `grade.sh`, ask
of each line: is this telling the agent the
*outcome* (declarative) or the *forbidden path*
(imperative)? If the line says "the output must
include key X," that's declarative — the agent
can satisfy it any way it likes. If the line says
"the source must not contain Y," that's
imperative — the agent cannot override.

The 4 default integrity guards are a good audit
template:

| Guard | Quadrant | What it forbids |
|---|---|---|
| `no-grade-todo-stub` | Imperative strategic | The agent leaving a `TODO` in a grader |
| `no-stub-always-pass` | Imperative strategic | A grader with no real assertion |
| `no-sleep-in-grader` | Imperative strategic | Masking timing failures with `sleep` |
| `agents-md-has-hard-rules` | Imperative strategic | Removing the held-out / private rules from `AGENTS.md` |

All four are firm-level ("we will not ship a
harness that does X") and path-specific ("the
agent may not produce a grader that does Y"). None
of them say what the grader *should* do — that's
the design task's declarative prompt.

## 4. Socratic discovery with the agent

The `BUILDING-A-GREAT-HARNESS.md` sample
V0→V1 conversation (the HITL asking "add three
questions where the function has to handle a
broken input and return an error") *is* the
discovery process. It doesn't have a name in that
doc. Here it is named and packaged as a
5-question template you can run with the agent
before you paste the `/goal` prompt.

For each design task in `test-tasks/design/<id>/`:

1. **What are the 3 assumptions in this harness
   that, if wrong, would invalidate the visible
   test?** Examples: "the parser is a Python
   script" / "the agent has network access during
   grading" / "the wrapper emits the 8 shared
   keys in this order."
2. **For each, what's the cheapest negative check
   I can add to the `grade.sh`?** (The `d1` parser
   check is the pattern: a `grep -qE` over the
   parser source for forbidden constructs.)
3. **Which of those assumptions are firm-level
   (true for every project) and which are
   project-level (true only here)?** Firm-level
   assumptions become `integrity.sh` guards;
   project-level assumptions become per-task
   negative checks.
4. **Of the firm-level ones, which deserve a
   held-out task?** Held-out tasks are
   expensive — they take time to write, the
   agent will never see them, and the grader
   is `chmod 600`. Spend them on assumptions
   whose violation would be *invisible* to the
   visible test. `h4-force-entropy-trigger` is
   the model: the visible test cannot see
   whether the force-entropy rule fires, so a
   held-out task runs `cycle.sh` for 2 cycles
   and asserts the log contains a
   `FORCED_ENTROPY=true` entry.
5. **Of the project-level ones, which belong in
   `AGENTS.md` as a hard rule (imperative
   strategic) vs in the per-task `prompt.txt`
   as a description (declarative tactical)?**
   Rule of thumb: if the project-level
   assumption affects multiple design tasks, it
   belongs in `AGENTS.md`. If it affects only
   one, it belongs in that task's `prompt.txt`.

Worked example, applied to
`test-tasks/design/d1-parse-cline-output/`:

1. Three assumptions: (a) the parser is a Python
   script (not a binary), (b) the parser
   doesn't `eval` its input, (c) the parser
   source is committed (not regenerated at
   runtime).
2. Cheapest negative checks: (a) no
   `#!/usr/bin/env python3` shebang check is
   cheap; (b) the `grep -qE 'eval.*input'`
   check in the existing grader; (c) a
   `test -f "$PARSER"` check.
3. (a) is a project-level fact about the LFD
   bundle (parsers are Python, that's a
   bundle-level choice). (b) is a firm-level
   rule (no `eval` on untrusted input is
   non-negotiable across the firm). (c) is
   project-level.
4. The firm-level one (no `eval` on untrusted
   input) already lives in the design task's
   `grade.sh`. It does not need a held-out
   duplicate — the design task catches it
   already.
5. The project-level (a) is encoded in
   `prompt.txt` ("Parse a sample Cline NDJSON
   transcript…") — the agent knows what kind
   of artifact it's producing. (c) is encoded
   in the `grade.sh` itself (the `[[ ! -f
   "$PARSER" ]]` check).

The discovery is not free — the V0→V1
expansion typically takes 30-60 minutes of
HITL time. The payoff is a harness whose
negative checks are not a guess list but
arise from named assumptions, each of which
has a clear owner.

## 5. Two prompt patterns

Two patterns show up over and over in
well-shaped task prompts. Neither is in the
current docs by name.

### 5.1 Wiggle room

The pattern: state the imperative preference,
then add a declarative addendum that surfaces
better designs the agent might find.

**Bad** (`test-tasks/<id>/prompt.txt`):

```
Implement <X>. Use <specific approach A>.
```

This locks the agent into approach A. If the
agent sees a better design — say, a design that
hits the p99 budget the rubric requires — it
will not raise it, because the prompt told it
to use approach A.

**Good**:

```
Implement <X>. Use <specific approach A>.

If you discover a design that achieves the
objectives in DONE WHEN better than approach A,
raise it as an option in your iteration-log.md
entry before proceeding. Do not implement the
alternative without surfacing it.
```

The imperative ("use A") stays. The declarative
addendum ("if you find something better, raise
it") gives the agent one specific, bounded
permission to override. The cost of being wrong
is small: the agent has to write one log entry.
The cost of being right is real: the loop finds
a design the human didn't anticipate.

Wiggle room belongs in the declarative
*tactical* quadrant. It is per-task. The
firm-level rule is "every task prompt has a
wiggle-room clause" — that rule itself
*belongs in `AGENTS.md` as a hard rule.*

### 5.2 Right generalization

The pattern: when you would otherwise leak
future-project context, abstract the
interaction to its general form.

**Bad** (`GOAL.md` or `test-tasks/<id>/prompt.txt`):

```
Implement <X>. Later, <X> will need to
integrate with project B by passing <some
specific data shape> to it.
```

The "later, project B" clause is a
context-pollutant. Every cycle the agent
re-reads this prompt; every cycle the agent
has to ignore or partially attend to
information about a project that does not yet
exist. The cost compounds.

**Good**:

```
<X> emits <data shape Y>, indexed by
<dimension 1> and columned by <dimension 2>.
Any future consumer that needs <dimension 1> ×
<dimension 2> matrices can read from <X>'s
output.
```

The right generalization — the shape of the
interaction, not the name of the future
project — gives the agent the same
information without the context leak. The
agent now has a *contract* (Y, indexed by
dimension 1, columned by dimension 2) and
not a *dependency* (B, which doesn't exist
yet).

Right generalization belongs in the
*imperative tactical* quadrant. The shape of
the output is non-negotiable; the choice of
how to produce that shape is the agent's.

## 6. Preferences build objectives, objectives build loops

The closing line of the source essay is a
bridge, not a flourish. The 2×2 of preferences
*is* the 4-piece loss anatomy in
`BUILDING-A-GREAT-HARNESS.md`, viewed from
upstream:

- **Target.** Built from declarative
  preferences (the outcomes you want,
  firm-level and project-level). The target's
  *shape* comes from your firm-level
  declarative preferences (you will not
  accept X); the target's *content* comes
  from project-level declarative preferences
  (for this project, success looks like Y).
- **Constraints.** Built from imperative
  preferences. The firm-level ones go in
  `AGENTS.md` and `integrity.sh`. The
  project-level ones go in `grade.sh` and
  the per-task `prompt.txt`. A constraint
  without an instrument is a wish; an
  imperative preference without a `grade.sh`
  line is exactly that.
- **Instruments.** Determined by the
  preference type. Declarative preferences get
  *soft* instruments (a linter, a legibility
  rubric, the `smallness.sh` reward that
  decays from 1.0 to 0.0). Imperative
  preferences get *hard* instruments (an
  exit-coded guard, a held-out task, a
  negative check).
- **Forced entropy.** The meta-preference
  that the *type* of a constraint can shift
  as the loop runs. A rule that started as
  imperative (a `grep -qE` negative check in
  `d1/grade.sh`) might migrate to a
  declarative preference (a legibility
  rubric in `docs/`) once the loop has
  established the negative check is stable
  enough. The `cycle.sh` `FORCED_ENTROPY`
  rule and the `consecutive_no_improvement`
  counter in the `h4-force-entropy-trigger`
  held-out grader are the wiring.

When you start a new harness, walk the four
questions in §2 for every rule you add. When
you review a candidate rule, ask which
quadrant it belongs in and whether the
instrument matches the quadrant. A
declarative preference with an exit-coded
instrument is over-specified; an imperative
preference with a soft linter is under-
specified; either will produce a loop that
spirals.

## See also

- `BUILDING-A-GREAT-HARNESS.md` — the manual
  this document is the predecessor of. The
  4-piece anatomy, the V0→V1 expansion
  checklist, the 4-layer anti-cheat defense,
  and the stuck-loop playbook are the *how*
  once the *what* is clear.
- `skills/loss-function-design/SKILL.md` —
  the 4-piece loss anatomy in technical
  detail, including the `L: Candidate ×
  Evidence → Score` contract and the
  sub-loss decomposition.
- `skills/meta-loss-function-development/
  references/harness-completeness-checklist.md`
  — the gate every new harness must pass
  before the loop runs.
- `examples/lfd-system-verifier/verifiers/
  integrity.sh` — the 4 default imperative
  strategic guards this document cites.
- `examples/lfd-system-verifier/test-tasks/
  design/d1-parse-cline-output/grade.sh` —
  the worked example for §3 (the imperative
  `eval` negative check) and §4 (the
  Socratic discovery template applied).
- `examples/lfd-system-verifier/test-tasks/
  held-out/h4-force-entropy-trigger/
  prompt.txt` — the model for §4 question 4
  (when a firm-level assumption deserves a
  held-out task).
