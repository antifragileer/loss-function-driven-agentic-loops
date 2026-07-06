---
name: lfd-thinking-protocols
description: |
  Use when the user is mid-harness-build (between Rounds 0-7
  of `meta-loss-function-development`) and needs to make a
  first-principle decision before the next round can start.
  This skill enforces 10 thinking protocols — one per harness
  part — that force a written commitment the next round
  reads as a handoff. Each protocol writes a handoff file
  into the project root the meta-skill is building, not a
  separate artifact the loop ignores.

  Load when:
  - The user describes a project they want to build with
    LFD, before any meta-skill Round 0 has run. (This is
    the most common entry point — the user says "build X
    in Y" or "create a /goal prompt for X" and the gate
    fires before scaffolding.)
  - The user says "I don't know what I want yet", "help me
    think through this", "what should the harness measure",
    "what's the right target".
  - The user is at a Round-1-to-Round-7 transition in
    `meta-loss-function-development` and the meta-skill is
    about to scaffold the next piece without a committed
    answer.
  - The user pastes a goal like "build X" and the meta-skill
    would default to "ask 3 setup questions." This skill
    replaces the default with a structured thinking protocol
    that produces a written commitment.

  The 10 protocols (templates/gates.md):
  1. clarify-target — 2x2 placement + DONE WHEN
  2. shape-loss — 4 sub-losses with weights
  3. design-verifier — boundary check per sub-loss
  4. shape-context — AGENTS.md voice + per-task prompt
  5. design-tools — instrument inventory
  6. wire-loop — cycle contract shape
  7. set-rails — anti-cheat layer assignments
  8. wire-feedback — sub-loss readout format
  9. set-termination — multi-axis stop conditions
  10. tune-search — forced-entropy rule choice

  Each protocol is a **5-minute commitment**: the user fills
  in a one-page template, the skill writes the answer into
  the harness, the meta-skill picks up at the next round.
  Without the handoff, the next round does not start.
version: 0.4.1
author: open source
license: MIT
metadata:
  hermes:
    tags: [lfd, thinking, gate, socratic, harness, handoff]
    related_skills: [meta-loss-function-development, loss-function-design, harness-engineering, harness-scaffold, loop-driver]
---

# LFD Thinking Protocols

The bundle's 3-layer architecture has a gap. The
`meta-loss-function-development` skill walks the user
through 8 rounds of harness construction (Rounds 0-7)
and emits a `/goal` prompt at the end. The user does
**thinking** between rounds, but the bundle has no
structured way to do that thinking. The result is
defaults, vague targets, and over-asked clarifying
questions.

This skill fills the gap. It is a **gate** the
meta-skill invokes between rounds. Each gate forces a
written commitment, writes it to a handoff file in the
project root, and refuses to advance until the
commitment exists.

## The architecture

```
    Round 0 (scaffold)
        │
        ▼
    ┌─────────┐
    │ Gate 1  │  clarify-target
    │ (5 min) │  →  handoffs/01-target.md
    └────┬────┘
         ▼
    Round 1 (4-piece spec)
        │
        ▼
    ┌─────────┐
    │ Gate 2  │  shape-loss
    │ (5 min) │  →  handoffs/02-loss-shape.md
    └────┬────┘
         ▼
    Round 2 (design set)
        │      ┌─────────┐
           ┌───│ Gate 3  │  design-verifier (per task)
           │   └─────────┘
           ▼
    ┌─────────┐
    │ Gate 4  │  shape-context
    │ (5 min) │  →  handoffs/04-context-shape.md
    └────┬────┘
         ▼
    Round 4 (instruments + integrity)
        │      ┌─────────┐
           ┌───│ Gate 5  │  design-tools
           │   └─────────┘
           │   ┌─────────┐
           └───│ Gate 7  │  set-rails
               └─────────┘
               ┌─────────┐
           ┌───│ Gate 8  │  wire-feedback
           │   └─────────┘
           ▼
    Round 5 (AGENTS.md + README)
        │
        ▼
    ┌─────────┐
    │ Gate 6  │  wire-loop
    │ (5 min) │  →  handoffs/06-loop-shape.md
    └────┬────┘
         ▼
    Round 6 (completeness check)
        │
        ▼
    ┌─────────┐
    │ Gate 9  │  set-termination
    │ (5 min) │  →  handoffs/09-termination.md
    └────┬────┘
         ▼
    Round 7 (/goal emit)
        │
        ▼
    ┌─────────┐
    │ Gate 10 │  tune-search
    │ (5 min) │  →  handoffs/10-entropy-rules.md
    └─────────┘
```

The gates are **round-boundary disciplines**, not
parallel skills. The user does not see 10 new skills
in the trigger list; they see one skill with 10 named
gates, each invoked explicitly by the meta-skill at
the right point.

## The handoff contract

Every gate writes to a file under
`$PROJECT_DIR/handoffs/`. The file name is fixed and
known to the next round. The next round **refuses to
start** if the file is missing.

The handoff files are not a separate documentation
tree. They are read by the meta-skill, the loop driver,
and the integrity script. They are part of the
harness. A harness with empty `handoffs/` is a
harness with no committed target, no committed loss
shape, no committed stop conditions — and the loop
will not start.

| Gate | Handoff file | Read by | Source framework |
|---|---|---|---|
| 1 clarify-target | `handoffs/01-target.md` | meta-skill Round 1, loop-driver stop-conditions parser | `references/frameworks.md` §1 (2x2), §3 (5-Q Socratic) |
| 2 shape-loss | `handoffs/02-loss-shape.md` | meta-skill Round 1, `verifiers/compute_sub_losses.py` | `loss-function-design/SKILL.md` lines 50-101 (4-piece anatomy) |
| 3 design-verifier | `handoffs/03-verifier-spec.md` + per-task `test-tasks/<id>/grade.sh` | meta-skill Round 2, integrity.sh Layer-1 guards | `loss-function-design/SKILL.md` lines 178-205 (reward-hacking table) |
| 4 shape-context | `handoffs/04-context-shape.md` + `AGENTS.md` + per-task `test-tasks/<id>/prompt.txt` | loop driver, inner agent | `harness-engineering/SKILL.md` (AGENTS.md as TOC); `references/frameworks.md` §4 (wiggle room), §5 (right generalization) |
| 5 design-tools | `handoffs/05-tools-inventory.md` + `verifiers/instruments/*.sh` | loop driver, integrity.sh | `harness-scaffold/SKILL.md` lines 1-37 (33-instrument taxonomy) |
| 6 wire-loop | `handoffs/06-loop-shape.md` | loop-driver, cycle.sh | `loop-driver/SKILL.md` lines 27-78 (the 10-step cycle) |
| 7 set-rails | `handoffs/07-rails.md` + `verifiers/integrity.sh` | integrity.sh (every cycle) | `references/frameworks.md` §7 (4-layer defense) |
| 8 wire-feedback | `handoffs/08-feedback-format.md` + `verifiers/compute_sub_losses.py` | loop-driver, score-cycle.py | `loss-function-design/SKILL.md` lines 86-94 (sub-loss template) |
| 9 set-termination | `handoffs/09-termination.md` + `GOAL.md` DONE/NOT DONE | loop-driver stop-conditions parser | `references/frameworks.md` §9 (DONE/NOT DONE); `meta-loss-function-development/SKILL.md` (the Round 7 emit) |
| 10 tune-search | `handoffs/10-entropy-rules.md` + `scripts/cycle.sh` FORCED_ENTROPY | cycle.sh, held-out h4 task | `loop-driver/SKILL.md` lines 127-149 (3 forced-entropy rules) |

**If the handoff file is empty, the gate has not been
run. The next round does not start.**

## The 5-minute commitment

Each gate is a one-page template. The user fills it
in. The skill reads the file and updates the harness.
The 5 minutes is a *commitment* by the user, not a
wall-clock budget for the protocol itself.

Why 5 minutes: long enough to think, short enough to
do. The user can spend 30 minutes on a gate if they
want. The protocol just refuses to let them rush
through with a one-word answer.

The protocol for a single gate:

1. The skill loads `templates/gates.md` and shows the
   relevant section (e.g., section 1 for
   `clarify-target`).
2. The user fills in the template, inline or in a
   buffer.
3. The skill writes the filled template to
   `$PROJECT_DIR/handoffs/NN-<gate-name>.md`.
4. The skill shows the next round's first action and
   asks: "Is this gate complete, or do you want to
   iterate?"

## What the skill does NOT do

- **Not a loop driver.** The thinking protocols are
  meta-skill helpers. They run in the meta-session,
  not the loop session. The loop session reads
  `handoffs/` as part of the harness; the loop
  session does not load this skill.
- **Not a replacement for the meta-skill.** The
  meta-skill owns the round flow. This skill is
  loaded *between* rounds, not instead of rounds.
- **Not exhaustive.** The 10 gates are the 10
  decision points the meta-skill walks through. The
  meta-skill's Rounds 0-7 do not change; this skill
  just makes the thinking between rounds explicit
  and committed.

## When to load this skill

- The user is mid-harness-build and the meta-skill is
  about to scaffold the next piece without a written
  commitment.
- The user says "I don't know what I want yet" or
  "help me think through this" during a meta-skill
  session.
- The user wants to review or update a handoff file
  after the harness is built (rare — usually they
  edit the file directly).
- The user pastes a goal and the meta-skill would
  default to "ask 3 setup questions." Load this
  skill instead and run `clarify-target` first; the
  filled template answers the meta-skill's Round-1
  questions before the meta-skill asks them.

## When NOT to load this skill

- The user has a finished harness and wants the loop
  to run — that's `loop-driver`.
- The user wants to debug a stuck loop — that's
  `loss-function-design` or `references/frameworks.md` in
  this skill.
- The user wants to scaffold a project tree — that's
  `harness-scaffold`.
- The user wants to debug the inner agent — that's
  `cline-orchestration` (or runtime equivalent).

## Operating principles

1. **One gate per round boundary.** A gate is a
   commitment, not a checklist. Asking the user to
   fill out all 10 at once is not the model.
2. **The handoff file is the contract.** The gate's
   output is the file, not the conversation. The
   next round reads the file, not the chat log.
3. **Defaults are visible.** When the user accepts a
   default, the gate records "user accepted default
   for X" in the handoff file. The next round knows
   which fields were committed and which were
   defaulted.
4. **Iteration is allowed.** The user can re-run a
   gate and overwrite the handoff file. The next
   round reads the latest version. A gate is not
   write-once.
5. **The handoff files survive harness builds.** They
   live under `$PROJECT_DIR/handoffs/`, not under
   the loop's `logs/`. The verifier's `.gitignore`
   must NOT exclude `handoffs/` (unlike `logs/`,
   `verification-report*.json`, etc.).
6. **No LLM-as-judge in the gate.** The user is the
   judge of their own commitment. The skill does not
   run any scorer; it writes the user's answer to
   disk and moves on.

## Related skills (install separately if not present)

- `meta-loss-function-development` — runs Rounds 0-7
  and loads this skill between rounds.
- `loss-function-design` — the 4-piece loss anatomy
  the gates reference.
- `harness-engineering` — what the agent sees
  (referenced by `shape-context`).
- `harness-scaffold` — scaffolds the project tree
  (referenced by `design-tools`).
- `loop-driver` — the runtime (referenced by
  `wire-loop`, `wire-feedback`, `set-termination`,
  `tune-search`).

## References in this skill

- `templates/gates.md` — the 10 gate templates, one
  per page, in the order the meta-skill invokes them.
- `references/handoff-files.md` — the exact file
  paths, owners, and readers for each gate's
  handoff. Load this when you need to know which
  handoff is read by which component.
- `examples/round-walkthrough.md` — a worked
  example of running all 10 gates against a sample
  "Slack clone in Go" goal, showing the filled
  handoff files.
- `examples/lfd-system-verifier-integration.md` —
  proof that the V0→V1→HITL→V2+ flow still works
  after this skill is added. The integration test
  runs both `run-verification.sh` (fake-agent) and
  `run-verification-real.sh` (real-agent) against
  the LFD system verifier and confirms the report
  shows PASS.
