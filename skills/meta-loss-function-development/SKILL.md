---
name: meta-loss-function-development
description: |
  Turn a high-level goal ("build X in Y using loss-function
  development") into a COMPLETE, on-disk harness project, then
  emit a paste-able /goal prompt that runs the outer loop
  against it. The harness is built in THIS session, with the
  user, iteratively, until every stub is filled and every
  held-out task exists as a real test case. The /goal prompt
  is the last thing this skill does — a thin shim that points
  a fresh session at the already-finished harness.

  Load this skill whenever the user says any of: "loss function
  development", "LFD", "/goal", "use the loop pattern on X",
  "set up a loss-driven loop for Y", "I want to build Z with
  the harness-engineering pattern", or describes a project they
  want to drive with a loss-function loop. Also load it when
  the user pastes a /goal prompt and asks for review, or says
  "this loop isn't converging" and the failure is in the goal
  spec rather than in the harness.

  This skill is the *meta-loop*: it produces the artifacts
  that the loss-function-design skill describes. It does not
  run the loop itself. The output is consumed by a new
  session that runs the loop.
version: 1.1.0
author: open source
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [meta, loss-function-development, lfd, goal, harness, agentic]
    related_skills: [loss-function-design, harness-engineering, cline-orchestration]
---

# Meta Loss-Function Development

The loss-function loop has three layers:

1. **Inner loop** — the coding agent (Cline, Codex, Aider, …)
   running the spec-driven development cycle. Spec-driven
   development: "build this, make the tests pass."
2. **Outer loop** — the loss-function driver. The driver
   invents hypotheses, runs the inner loop, scores the result
   against the loss, decides whether to refine or accept.
3. **Meta loop** — *this* skill. Given a high-level goal,
   produce the COMPLETE harness the outer loop drives, plus
   the thin /goal prompt that points the outer loop at it.

This skill runs in an interactive session WITH THE USER. The
output is two things on disk: a fully-built harness tree, and
a paste-able /goal prompt. The user then pastes the prompt
into a *different*, fresh session to run the outer loop. The
fresh session never has to build the harness — the harness
already exists.

## The core invariant: harness first, then prompt

**Build the complete harness before emitting the /goal prompt.**
Every `grade.sh` is a real grader, every held-out task has
real task content, every instrument script actually measures
what it claims to measure. The /goal prompt is the *last*
thing this skill does, not the first.

## What the output is

When you load this skill and the user says "build a clone of
the slack desktop app from slack.com in golang using loss
function development", the output is TWO things:

1. **A complete harness tree on disk** at the project root
   the user specified. Every file is finished:
   - `GOAL.md` (the /goal prompt, finalized)
   - `AGENTS.md` (loop driver rules)
   - `README.md` (run instructions)
   - `verifiers/` (wrapper, run-design-set, instruments,
     compute_sub_losses, parse_cline_output, **private
     held-out grader that actually grades**)
   - `test-tasks/design/NN-*/` (5-10 tasks, each with
     real `prompt.txt`, real starting file, real
     `grade.sh`)
   - `test-tasks/held-out/hNN/` (5-10 tasks, each with
     real task content, real grader the loop reads
     indirectly)
   - `logs/` (empty, ready for the loop to write into)
2. **A paste-able /goal prompt** as a single text block. The
   user copies it, opens a fresh session, pastes it, and
   the loop runs.

The block's first line after the title is `PROJECT_DIR:
<absolute-path>`, so the fresh session finds the project.

## How to use this skill (for the user)

1. Describe the goal in one sentence. Include: the artifact
   ("build X"), the constraints ("in Y", "for Z"), and any
   quality bar ("looks like reference", "passes acceptance
   tests"). **Also tell the skill the absolute path of the
   project root** (the directory where the harness should
   live). If you don't, the skill will ask, because the
   harness MUST be at a known path before any files are
   written.
2. The skill will iterate with you. Each round: the skill
   builds a piece of the harness, you review it, you say
   "add more X" or "this grader is wrong, fix Y" or "this
   design task is too easy, here's a harder variant." The
   skill updates the tree on disk each round.
3. The skill walks through the **harness completeness
   checklist** (see `references/harness-completeness-checklist.md`)
   explicitly. It does not emit the /goal prompt until every
   item is checked off and you've confirmed.
4. When the harness is complete, the skill emits the
   /goal prompt as a code-fenced text block. You copy the
   block.
5. Open a **fresh session** (new chat, new context). Paste
   the block as the first message. The fresh session has
   only the three inner skills (loss-function-design,
   harness-engineering, cline-orchestration) and the goal
   prompt itself. It reads the complete harness on disk,
   establishes baseline, runs cycle 1.

## How the meta-skill drives the iteration

The meta-skill builds the harness piece by piece, in order of
dependency, with the user reviewing each piece:

### Round 0: project root + scaffold

- Confirm the absolute project root path. (Refuse to
  proceed without it.)
- Create the directory tree (`verifiers/`, `test-tasks/`,
  `skills/`, `logs/`) using the `harness-scaffold` skill's
  tooling. All files start as stubs with explicit `TODO`
  comments and `agent-edited: yes` markers absent. The
  scaffold also generates `verifiers/integrity.sh` with
  5 default anti-cheat guards (Section 5 of the
  completeness checklist covers which guards), plus
  `verifiers/instruments/test-freshness.sh`,
  `hidden-unread.sh`, and `per-cycle-wall-clock.sh`. The
  loop session will invoke `integrity.sh` before every
  cycle; the harness is not runnable until every
  grade.sh in `test-tasks/design/` is a real grader.

### Round 1: the 4-piece loss spec

- Ask 1-3 clarifying questions in priority order (project
  root, "done" definition, budget, agent, defense list,
  held-out set source). See "Discovering information" below.
- Draft the 4-piece spec in conversation with the user.
  Show it as a markdown block. Get explicit sign-off.
- This spec becomes the backbone of the /goal prompt's
  `Target`, `Constraints`, `Instruments`, and `Forced
  entropy` sections.

### Round 2: design set (5-10 tasks, 4 categories)

- For each task, write: a `prompt.txt` (what the inner
  agent sees), a starting file (the buggy code / blank
  file the agent modifies), and a `grade.sh` (the
  deterministic grader, exit 0 on pass, non-zero on
  fail, with a real check — `go test`, `pytest`, `diff`,
  `jq` comparison, etc.).
- The 5-10 tasks must span **4 categories** (BUILDING-A-
  GREAT-HARNESS.md V0-1):
  - 2-4 **happy-path** tasks (the basic case works)
  - 2-4 **error / edge-case** tasks (broken / empty /
    oversized / weird input; specific error shape)
  - 1-2 **cross-cutting** tasks (exercise 2+ components
    at once; break naive solutions)
  - 1-2 **negative** tasks (right answer is to NOT do
    something — the agent must NOT call a helper, NOT
    retry forever, NOT block)
- Each `grade.sh` must include at least one **negative
  check** (e.g., `grep -v time.Sleep` to assert the
  function did not use a sleep to mask a timing failure).
  A grader with only positive checks passes for an empty
  stub function — that is the largest single class of V0
  failure mode.
- Each grade.sh must be runnable standalone
  (`bash grade.sh` from inside the task dir) and must
  exit 0 deterministically. Stub graders that `exit 1
  // TODO` are explicitly disallowed in the finished
  harness.
- Show the user the 5-10 tasks. Ask: "Are these the right
  shape? Any obvious gaps? Any reward hacks these graders
  would reward?" Iterate.

### Round 3: held-out set (5-10 tasks, categorically different)

- Synthesize held-out tasks from public sources (API docs,
  public test cases, the reference's public surface). For
  each: same shape as a design task (prompt + starting
  file + grader), but stored in `test-tasks/held-out/`
  with `chmod 700` on the parent and `chmod 600` on the
  files.
- The held-out set must be **categorically different**
  from the design set, not just "10 more examples of the
  same shape" (BUILDING-A-GREAT-HARNESS.md V0-2). At
  least one held-out task must exercise a property the
  public docs *mention but don't fully explain* — rate
  limits, retry behavior, auth edge cases, error-format
  quirks, cross-component integration. The visible test
  is the practice exam; the held-out set is the real
  exam, with different question shapes.
- The held-out graders are referenced from
  `verifiers/private/grader.sh`, which the loop session
  reads but cannot inspect (it runs the grader, doesn't
  see its source).
- Show the user the 10 held-out tasks. The user reviews
  the *names* and high-level descriptions (not the
  contents — those should be the user's secret test set
  unless the user explicitly approves generating
  them). Iterate.

### Round 4: instruments and integrity script

- For each constraint in the 4-piece spec, write a CLI
  command the loop can run to measure it. `time-remaining.sh`,
  `tokens-remaining.sh`, etc. Each script must actually
  return a real measurement (parse a log, query an API,
  read a file), not echo a placeholder.
- Verify the three loop-side anti-cheat instruments:
  - `verifiers/instruments/test-freshness.sh` — record
    the design-set SHA on first run, fail on subsequent
    change (the agent must not be able to edit a test
    to pass it).
  - `verifiers/instruments/hidden-unread.sh` — fail if
    the agent's last-cycle transcript references
    `test-tasks/held-out/` task names or
    `verifiers/private/` paths.
  - `verifiers/instruments/per-cycle-wall-clock.sh` —
    record per-cycle wall-clock so the loop can reward
    fast-improving cycles.
- Verify `verifiers/integrity.sh` runs the 5 default
  anti-cheat guards and exits 0 on the finished harness.
  The 5 guards: no grade.sh is a TODO/stub, no grade.sh
  is an empty stub-always-passes, no grade.sh uses
  `sleep` / `time.Sleep`, AGENTS.md still has the hard
  rules, no transcript references the held-out or
  private surfaces. The user may add project-specific
  guards.
- Test each instrument and `integrity.sh` by hand
  (`bash verifiers/instruments/X.sh`,
  `bash verifiers/integrity.sh`) before showing the user.

### Round 5: AGENTS.md and README.md

- Write `AGENTS.md` (loop driver rules — surface,
  forbidden files, iteration log format, and the
  requirement to run `verifiers/integrity.sh` before
  every cycle and refuse to score if any guard fires).
  `AGENTS.md` must be <100 lines, project-specific, and
  **in your own voice** — not the scaffold's default
  boilerplate. The default scaffold emits a placeholder;
  the user must rewrite it before the /goal prompt is
  emitted.
- Write `README.md` (how a human runs the loop:
  `bash verifiers/run-design-set.sh`, the loop driver
  command, where to read the iteration log).

### Round 6: completeness check

- Walk through `references/harness-completeness-checklist.md`
 with the user. Every item must be checked. If any are
 not, go back to the relevant round and finish them.
 The user signs off on the harness.

### Round 7: emit the /goal prompt

- Fill `templates/goal-prompt.md` with the 4-piece spec,
  the project root, the design task list, the held-out
  task list (names only), the harness layout, the runtime
  instructions.
- Open `GOAL.md` with a 2-3 line `DONE WHEN` /
  `NOT DONE WHEN` block (BUILDING-A-GREAT-HARNESS.md
  V0-8). `DONE WHEN` is the single testable criterion
  for success; `NOT DONE WHEN` lists the most common
  ways the agent will mistakenly claim to be done. The
  loop, the agent, and the user all read these two
  lines first.
- The Target section is **multi-axis** (BUILDING-A-
  GREAT-HARNESS.md ideas-bank #19): a list of
  conditions, not a single number. At least 2 of
  pass-rate threshold, p99 latency, "no AI-modified
  test files" assertion, hidden-test delta, integrity-
  pass assertion, or a smallness reward (fewer lines /
  fewer files). All axes must hold simultaneously for
  the loop to stop on success.
- The stop conditions in the /goal prompt reflect the
  multi-axis target. "Pass `pass_rate == 1.0`" alone
  is not a sufficient stop condition.
- The Hard Rules section requires the loop session to
  run `verifiers/integrity.sh` before every cycle and
  to refuse to score if any guard fires.
- Print the prompt as a single code-fenced block.
- Remind the user: paste this into a *fresh session* in a
  *different chat*. Do not resume this session for the
  loop run.

## How orchestrators drive this skill (non-interactive)

The interactive flow above assumes the user is in
conversation with this skill. Non-interactive
orchestrators (CI scripts, the LFD system verifier, etc.)
can drive it via a single prompt that asks for the full
deliverable. The same completeness-checklist gate
applies, but it's enforced by the orchestrator (e.g. the
LFD system verifier rejects an emitted /goal prompt if
grade.sh files in `test-tasks/design/` are still stubs).

Project-root pinning protocol:

- **Pinned (recommended — interactive or orchestrator).** The
  generated prompt embeds `PROJECT_DIR: <absolute-path>` as a
  header line. The fresh session's first action reads that
  line and uses it as the authoritative project root.
- **Env-var (orchestrator fallback).** The orchestrator sets
  `LFD_PROJECT_DIR=/path/to/project` in the env when launching
  the fresh session.
- **cwd / walk-up (last-resort fallback).** Discovery step's
  third / fourth preference.

If none of the checks find the root, the agent stops and
reports the failure. Silent guessing is not allowed.

## How to write the goal prompt (for the skill itself)

The /goal prompt has six parts:

1. **The 4-piece loss spec.** Target, constraints,
   instruments, forced entropy.
2. **The candidate / verifier contract.** Where the agent
   writes its work, where the verifier reads, and what the
   JSON contract between them looks like.
3. **The design task list.** 5-10 tasks the agent will see
   during the loop, with deterministic graders.
4. **The held-out task list.** 5-10 tasks the agent will NOT
   see during the loop. Names only in the prompt — the
   actual task content is in `test-tasks/held-out/`.
5. **The harness layout.** File tree of `verifiers/`,
   `instruments/`, `AGENTS.md`, `GOAL.md`.
6. **The runtime instructions.** Which agent, which model
   (**whatever the user has currently authenticated — never
   ask, never pin**), which budget, which stop conditions.

Each part is filled in from the harness built in rounds
0-6. The /goal prompt does NOT need to re-describe how to
build the harness — that's done.

## Discovering information (the question phase)

The user often doesn't say everything needed. Ask 1-3
clarifying questions, *in priority order*, before round 1:

- "What absolute path should the harness live at?" — the
  **project root**. If the user does not specify, ask. Do
  NOT default this — wrong-path harnesses are unrecoverable.
- "What does 'done' look like for X? A reference output, a
  behavior spec, an acceptance test?" — the **target**.
- "What's the wall-clock budget? 1h? 6h? 24h?" — the
  **constraints**.
- "What agent and (implicitly) what model? Cline with its
  default provider? Codex with whatever OpenAI model the
  user has? Aider with whatever Anthropic key the user
  has? A Hermes session? — Note: do NOT ask the user to
  name a specific model. The model is whatever they have
  currently authenticated for whichever agent they pick.
  The /goal prompt should pin the agent but NOT the model
  and NOT the provider. The agent's own config (e.g. `cline
  auth`) is the source of truth." — the **runtime**.
- "What reference artifacts exist publicly that I should
  generate the held-out set from?" — the **held-out set
  source**.
- "What are the obvious reward hacks for X? Tests that can
  be deleted? Lints that can be suppressed? Token budgets
  that can be gamed?" — the **defense list**.

Aim for **at most 3 questions** per round. Beyond that, the
user is better served by a default than a Q&A. Use the
user's "use defaults" affordance from
`loss-function-design`: pick sensible defaults, state them
in the harness, the user can change them.

When the user already specified everything, do not ask
redundant questions. Skip the question.

## Researching the goal (the synthesis phase)

For goals that involve an external reference ("clone of X",
"implement Y from the paper", "match the public API of Z"),
the skill should do **bounded research**:

- Pull the reference's public artifacts (homepage, API docs,
  sample inputs/outputs, public test cases).
- Identify what "looks like the reference" means in 5-10
  concrete test cases.
- For each test case, identify the deterministic grader
  (does the output match, does the function return the right
  shape, does the binary build, does the unit test pass).
- Identify the *cheap reference* the loop can score against.

Bounded = **at most 10 minutes of web/tool calls per round**.
The skill must not turn into a research project.

For goals that are *internal* ("build our internal tool", "add
feature Y to our codebase"), the research phase is just
reading the project's existing files. Same time budget.

## Composing the prompt (the writing phase)

The skill emits the prompt as a single code-fenced text
block. The format is the one from the @elvissun article,
adapted to the user's specific goal. A canonical template
is at `templates/goal-prompt.md` in this skill. Examples of
completed prompts are at `examples/`.

The writing phase is mechanical once the discovery,
research, and round-by-round harness build are done. Fill
the template from the harness that's already on disk. Do
not improvise the format.

**Mandatory template fill: the project-root header.** When
filling `templates/goal-prompt.md`, replace
`<ABSOLUTE-PATH-TO-PROJECT-ROOT>` with the absolute path the
user specified. The fresh session will read this line and
use it as the authoritative project root — see "Project-root
pinning" above. Replace `<SHORT-SLUG>` with a filesystem-safe
short name for the project.

## What this skill is NOT

- **Not a loop driver.** It does not run the outer loop. It
  produces the harness; the user runs the loop in a fresh
  session.
- **Not a research project.** 10 minutes of bounded research
  per round is the cap.
- **Not a domain expert.** If the user says "build a slack
  clone", the skill does not become a slack engineer. It
  reads the public artifacts, identifies the testable
  behaviors, and produces a harness that drives an agent
  toward those behaviors.
- **Not a verifier implementer in one shot.** The harness
  is built iteratively with the user. Stubs that get filled
  in later are forbidden — every piece must be finished
  before the next round starts.

## Pitfalls when using this skill

- **Don't emit the /goal prompt before the harness is
  complete.** If `grade.sh` is still a stub, the harness is
  not complete. The user must sign off via the
  completeness checklist.
- **Don't skip the completeness check.** It is the HITL
  gate. Skipping it produces a minimal harness.
- **Don't load this skill in the loop session.** The loop
  session should have only the three inner skills
  (`loss-function-design`, `harness-engineering`,
  `cline-orchestration`) plus the goal prompt. Loading the
  meta-skill voids the held-out guarantee.
- **Don't ask 5+ questions per round.** The user wants the
  harness to converge, not to be interviewed. Ask the top
  1-3 per round, build the piece, iterate.
- **Don't write the prompt before the harness is done.** If
  the harness has stubs, the prompt is a lie. Build the
  harness first; the prompt is a summary of what's on disk.
- **Don't put machine-specific paths in the prompt body.**
  Use `$PROJECT_DIR` and the project-root discovery
  protocol. The one exception is the `PROJECT_DIR:` header
  line — that's the whole point.
- **Don't hard-code the model.** The model is the user's
  choice. Pick a *capability tier* and let `cline auth`
  decide. Do not name a specific model anywhere in the
  prompt, the harness, or the wrapper script. The
  verification rule: if the string in the prompt's
  `INNER_MODEL:` line, the wrapper script, or the
  constraints section names a specific model or provider,
  the verifier should fail the prompt.
- **Don't make the held-out set larger than the design
  set.** 5/5 or 5/10 is fine. 50/50 dilutes the loop's
  attention budget.
- **Don't fill stubs "for the user."** If a grader is a
  stub, the right answer is to ask the user what the
  grader should check, not to write a plausible-looking
  grader on the user's behalf. The user is the only one
  who knows what the harness should reward.

## The 4-piece loss spec — quick reference

This is the same anatomy from `loss-function-design`. The
Fill each piece from the user's goal:

- **Target.** What the agent is descending toward. Must be
  large enough that enumeration doesn't pay, and must be
  **blind** to the agent during the run.
- **Constraints.** What the agent is allowed to do. Time,
  money, surface, methodology. For every constraint, ship a
  CLI command the agent can inspect.
- **Instruments.** The harness the agent runs against. A
  constraint without an instrument is a vibe.
- **Forced entropy.** Each loop continues from the *entire*
  previous run's context. The model is reading its own last
  hundred decisions. Force entropy to escape local maxima.

## The candidate / verifier contract — quick reference

```
verifier: <path to script or MCP tool>
inputs:
  candidate: <how the agent emits the candidate — file, dir, deploy url>
  evidence: <what the verifier reads — logs, screenshots, pprof, …>
outputs:
  score: float in [0.0, 1.0]
  details: { sub_loss: <name>, signal: <key>, … }
  artifacts: [ <paths to evidence files the agent can read> ]
exit_code:
  0: success (verifier ran, score is real)
  non-zero: verifier itself failed (DO NOT score 0; surface the failure)
determinism: deterministic | stochastic(seed) | llm_judge(model, prompt, temperature)
budget: <max wall-clock + max tokens>
```

## The skill's deliverables

When invoked, this skill produces:

1. **A complete harness tree on disk** at the project root.
2. **A single paste-able text block** — the /goal prompt
   that drives the loop against the harness.
3. **A short summary** above the block — what the harness
   assumes, what it doesn't, what the user should change.
4. **The completeness-checklist sign-off** as the final
   confirmation that HITL has happened.

## Related skills (install separately if not present)

- `loss-function-design` — the 4-piece loss anatomy. Its
  upstream.
- `harness-engineering` — what the agent sees.
- `harness-scaffold` — scaffolds the directory tree.
- `cline-orchestration` — the Cline runtime. Substitute
  your own if not using Cline.

## References in this skill

- `references/four-piece-anatomy.md` — the canonical 4-piece
  loss spec, with the @elvissun article's worked example.
- `references/research-budget.md` — the 10-minute research
  cap, with examples of what counts and what doesn't.
- `references/harness-completeness-checklist.md` — the
  checklist walked through with the user before emitting
  the /goal prompt.
- `templates/goal-prompt.md` — the canonical /goal prompt
  template, filled in here.
- `examples/slack-clone-golang.md` — a worked example.
- `examples/cli-tool-rust.md` — another worked example.
- `examples/algorithm-from-paper.md` — another worked example.
