# Harness Completeness Checklist

The meta-skill walks through this checklist with the user
**before** emitting the /goal prompt. Every item must be
checked. If any item is unchecked, go back to the relevant
round and finish the work. The /goal prompt is emitted only
after every box is ticked and the user has signed off.

This checklist is the **explicit HITL gate**. Without it, the
harness ends up minimal and the candidates end up minimal —
exactly the failure mode this checklist exists to prevent.

## How to use this checklist

The meta-skill reads each section aloud (or summarizes it),
shows the user the relevant on-disk artifacts, and asks "is
this complete?" The user replies yes, no, or "here's the
change." If the user says no or requests a change, the
meta-skill updates the harness, then re-shows that section.
Only after the user explicitly says "complete" or "approved"
does the meta-skill tick the box and move on.

The user signs off at the end with a single message ("harness
approved" or equivalent). The meta-skill records the
sign-off timestamp in `logs/harness-signoff.md` and then
emits the /goal prompt.

---

## Section 1: project root

- [ ] Absolute path confirmed and exists on disk
- [ ] Directory is empty (or user has explicitly approved
  using an existing non-empty directory and merging with
  what's there)
- [ ] `PROJECT_DIR` value matches what the user said

If the directory is not empty and the user has not approved
merging, the meta-skill must ask before writing. Wrong-path
harnesses are unrecoverable.

## Section 2: 4-piece loss spec

- [ ] **Target** — the user has stated what "done" looks
  like in measurable terms. Form: `pass_rate >= N` on
  held-out tasks, where N is explicit and the held-out
  task count is explicit (e.g., "8 of 10").
- [ ] **Constraints** — wall-clock budget, token budget,
  surface (which files the agent can read/write), and
  methodology (LLM-as-judge allowed? External API calls?
  Network access?) are all stated and explicit. For every
  constraint, an instrument exists (Section 4).
- [ ] **Instruments** — every constraint has a CLI command
  the loop can run to measure it. The list of instruments
  matches the constraints one-to-one. (See Section 4 below
  for the actual on-disk instruments.)
- [ ] **Forced entropy** — the three rules (overfit
  reflection every cycle, stall entropy on plateau, log is
  required) are stated and the user has agreed to the
  threshold (default 0.05, 3-stall cap).

The 4-piece spec is shown to the user as a single markdown
block. The user can edit it inline. The meta-skill updates
the on-disk `GOAL.md` to match.

## Section 3: design set (5-10 tasks)

- [ ] 5-10 tasks exist at `test-tasks/design/NN-<name>/`
- [ ] Each task has a `prompt.txt` (the prompt given to the
  inner agent)
- [ ] Each task has a starting file (the buggy code, blank
  file, or broken state the agent modifies)
- [ ] Each task has a `grade.sh` that is a **real
  deterministic grader**: exits 0 on pass, non-zero on
  fail, with a real check (`go test`, `pytest`, `diff`,
  `jq` comparison, etc.) — NOT `exit 1 // TODO`
- [ ] Each `grade.sh` is runnable standalone from inside
  the task dir (`cd test-tasks/design/NN-<name>/ && bash
  grade.sh` works)
- [ ] The user has run each `grade.sh` by hand and
  confirmed it actually checks the right thing
- [ ] The design set as a whole covers the user's
  "definition of done" — no obvious gaps the user can
  name
- [ ] No reward-hackable graders (graders that pass for
  "I deleted the test" or "I added a sleep" or "I
  hardcoded the answer key"). The user has reviewed
  each grader for hack-resistance.

If any `grade.sh` is a stub, the meta-skill does NOT
proceed. It writes the real grader with the user — even
if that means asking "what should this actually check?"
and waiting for the answer. Stub graders are forbidden in
the finished harness.

## Section 4: held-out set (5-10 tasks)

- [ ] 5-10 tasks exist at `test-tasks/held-out/hNN/`
- [ ] Each task has real task content (the user has
  reviewed the names and the meta-skill has shown
  high-level descriptions; the user has either
  approved the meta-skill to generate the contents
  from public sources, OR has written the contents
  themselves)
- [ ] Each held-out task dir is `chmod 700`, each file
  is `chmod 600`
- [ ] The held-out grader at `verifiers/private/grader.sh`
  is a real grader that runs the agent's candidate
  against the held-out tasks and emits a JSON score.
  The grader source is `chmod 600`.
- [ ] The grader is NOT readable by the loop session.
  The `AGENTS.md` says so explicitly: "DO NOT read
  `verifiers/private/`."
- [ ] The held-out set is **not memorized-able**: the
  agent can't pattern-match its way to 100% without
  actually solving the problem. The user has reviewed
  for this.
- [ ] The held-out set is **not in the meta-session's
  context window at /goal-paste time** — it lives only
  on disk in chmod'd directories. (This is automatic
  if the user signs off in this session and then
  pastes the /goal prompt into a *fresh* session
  later. The meta-skill must remind the user to use
  a fresh session.)

## Section 5: instruments

- [ ] One instrument script per constraint, in
  `verifiers/instruments/`
- [ ] Each script is a real shell script that returns a
  real measurement (parses a log, queries an API, reads
  a file with a real format) — NOT `echo "100"` or
  similar placeholder
- [ ] Each script exits 0 with the measurement on stdout
  and exits non-zero only on its own internal failure
  (not on a "constraint violated" condition — that's
  the loop's job to detect)
- [ ] The user has run each instrument by hand and
  confirmed the output is what they expect

## Section 6: AGENTS.md and README.md

- [ ] `AGENTS.md` is <100 lines, points to the harness
  tree, lists the surface rules, lists the forbidden
  files (`verifiers/private/`, `test-tasks/held-out/`),
  describes the iteration log format
- [ ] `README.md` has a one-paragraph "what this is" and
  a copy-pasteable "how to run the loop" command
- [ ] The user has read both files and approved

## Section 7: runtime instructions

- [ ] Which agent (Cline, Codex, Aider, Hermes) is
  explicit in the /goal prompt
- [ ] Which model is NOT named anywhere — only "whatever
  the user has authenticated via `<agent> auth`"
- [ ] Which provider is NOT named anywhere
- [ ] Wall-clock and token budget are explicit numbers
- [ ] The runtime is pinned in the wrapper script
  (e.g., `verifiers/cline-wrapper.sh` calls `cline` at
  the right path) and the wrapper is runnable from
  inside the project

## Section 8: meta-skill discipline

- [ ] The user has been told explicitly: **paste the /goal
  prompt into a fresh session, do not resume this
  meta-session for the loop run**
- [ ] The /goal prompt's Hard Rules section explicitly
  forbids loading `meta-loss-function-development` in
  the loop session
- [ ] The user understands that the meta-session's
  context window (which contains the held-out task
  synthesis, the user's private notes, etc.) is the
  threat model, and a fresh session is the mitigation

---

## Sign-off

After every section is checked, the user signs off with a
single message (e.g., "harness approved" or "looks good,
emit the prompt"). The meta-skill writes:

```
# Harness Sign-off

- date: <ISO timestamp>
- user: <user-identifier if available>
- meta-session: <session-id>
- harness root: <absolute path>
- sections checked: 1-8 all green
- notes: <any final user notes>
```

to `logs/harness-signoff.md`. Then the meta-skill emits
the /goal prompt.

The sign-off is for the user's record. The actual gate is
the on-disk state of the harness — every grade.sh is real,
every held-out task has content, every instrument is real.
The /goal prompt is a description of that on-disk state,
not a substitute for it.

## If a section can't be completed

If a section genuinely cannot be completed (e.g., the user
doesn't have a public reference to synthesize held-out
tasks from, so the held-out set has to be small), the
meta-skill records the gap explicitly in
`logs/harness-known-gaps.md` with the user's reason, and
the user signs off on the gap. The /goal prompt then
states the limitation in its Target section. The
limitation is not a bug — it's a recorded constraint
the loop can score against.

What is NEVER acceptable: skipping a section silently,
emitting a /goal prompt that points at an incomplete
harness, or filling stubs on the user's behalf without
asking.
