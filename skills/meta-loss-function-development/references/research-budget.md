# Research Budget — Reference

10 minutes of bounded research. This file defines what that
means.

## The 10-minute cap

The user is paying for a /goal prompt, not a domain analysis.
10 minutes of tool calls (web search, file reads, code
inspection) is the maximum. Beyond that, emit a /goal prompt
with whatever you have and a "research is incomplete" note.

## What counts as research

These are research, and they each have a soft sub-budget:

| Activity | Soft cap | Examples |
|---|---|---|
| Web search for the reference's public artifacts | 3 min | "slack api docs", "rust cli example", "paper pdf link" |
| Reading the reference's docs / spec | 3 min | API surface, public test cases, behavior examples |
| Reading the user's project files (if internal) | 2 min | AGENTS.md, docs/, existing code structure |
| Identifying the held-out set source | 2 min | "what 5-10 specific behaviors can I grade on?" |

**Total: 10 minutes.** If you hit a sub-cap, move on. The
held-out set can be "10 specific behaviors the agent's output
should exhibit" even if the exact artifacts aren't fully
enumerated.

## What does NOT count

These are not research, they are scope creep:

- Building the actual harness (`verifiers/`, `instruments/`,
  `AGENTS.md`). The fresh session does that based on the
  /goal prompt.
- Writing the Cline wrapper or other runtime glue. The fresh
  session does that, copying from `cline-orchestration`.
- Implementing the design tasks. The fresh session does
  that based on the task descriptions in the /goal prompt.
- Picking the model. The user picks the model. The
  /goal prompt says "any current Cline-compatible model
  the user has authenticated."
- Tuning the held-out grader. The fresh session writes
  the graders based on the task descriptions.

## When the research is incomplete

Emit the /goal prompt with what you have and a one-line
note: "I didn't fully enumerate the held-out set; the fresh
session will generate the 10 tasks from the public surface
as best it can." This is honest and gives the user a chance
to fill the gap.

## Common research pitfalls

- **Don't go down a rabbit hole.** One web search for the
  reference's public surface, then stop. The agent in the
  fresh session has the same tools; let it do deeper
  research.
- **Don't read the user's entire codebase.** 2 minutes
  max. If the project is bigger than that, emit the
  prompt with a generic "read AGENTS.md first" instruction.
- **Don't try to enumerate every public test case.** The
  /goal prompt's "5-10 held-out tasks" is a *signal*
  source, not a complete test suite. The fresh session
  generates the actual tasks from the prompt.
- **Don't wait for a slow web request.** If a search takes
  >30 s, cancel and move on. 10 minutes total is the cap;
  per-call caps are tighter.

## When the goal is fully internal (no public reference)

For goals like "build our internal tool X" or "add feature Y
to our codebase":

- The 10-minute cap is mostly reading the project's existing
  files.
- The "reference surface" is the codebase itself: existing
  tests, existing docs, existing AGENTS.md if any.
- The held-out tasks come from the user's stated acceptance
  criteria. If they didn't state any, ask. If they say
  "use defaults", emit the prompt with a "5-10 behaviors
  derived from existing tests" placeholder.

## The "10 minutes" rule is a budget, not a goal

The point is not to maximize research. The point is to
emit a /goal prompt that's *good enough* to drive a loop
that will produce something useful. A prompt based on 5
minutes of research that drives a 6-hour loop is better
than a prompt based on 30 minutes of research that never
gets run because it's too long to paste.

If you find yourself wanting more research time, the
signal is: the prompt is getting too long. Stop. Compress
to the essentials. The fresh session can do more research
in the first cycle of the loop.
