# /goal prompt examples

Three worked examples of the `/goal` prompt the
`meta-loss-function-development` skill emits. Each is a
complete, paste-able block — copy it, edit the goal statement
in the `**Target.**` section, and paste into a fresh session.

The canonical sources live at
[`skills/meta-loss-function-development/examples/`](../../skills/meta-loss-function-development/examples/).
This directory exists so `examples/README.md` has a
single jumping-off point for the "show me a /goal prompt"
reading path. If you add a new example, **add it to
both locations** (or, preferably, add it to the canonical
location and link to it from here).

## The three

| Goal | Inner agent | Language | File |
|---|---|---|---|
| Build a Slack desktop clone | Cline (default) | Go | [`slack-clone-golang.md`](./slack-clone-golang.md) |
| Port an internal CLI tool from Python to Rust | Cline (default) | Rust | [`cli-tool-rust.md`](./cli-tool-rust.md) |
| Implement FlashAttention-2 from the paper | Cline (default) | CUDA / Python | [`algorithm-from-paper.md`](./algorithm-from-paper.md) |

All three are the same template filled in differently. The
template itself is at
[`skills/meta-loss-function-development/templates/goal-prompt.md`](../../skills/meta-loss-function-development/templates/goal-prompt.md).

## Anatomy of a `/goal` prompt

Every prompt the meta-skill emits has the same six parts.
Reading them top-to-bottom in any of the three examples
above will show you the pattern. The labels are stable
(`**Target.**`, `**Constraints.**`, `**Instruments.**`,
`# Design-set tasks`, `# Held-out tasks`, `# Stop when`),
the sections are non-negotiable, and the order is fixed.

1. **Target.** The artifact the loop is descending toward.
   A list of per-sub-loss targets with weights. Gates are
   marked `(weight, gate)`; failing any gate blocks
   acceptance.
2. **Constraints.** Wall-clock budget, token budget, the
   surface the agent may touch (read `$PROJECT_DIR`, invoke
   the wrapper, write to `skills/<name>/`, etc.), and the
   methodology (deterministic verifiers only — no LLM
   judges in the harness).
3. **Instruments.** A CLI command for every constraint. A
   constraint without an instrument is a vibe — the agent
   will violate it because it cannot tell it is violating
   it. The meta-skill always emits at least:
   `time-remaining.sh`, `tokens-remaining.sh`,
   `tokens-this-iter.sh`, `<agent>-version.sh`,
   `<agent>-skills-dir.sh`, `sub-loss-readout.sh`,
   `run-design-set.sh`, `<agent>-wrapper.sh`.
4. **Design-set tasks.** 5 tasks the agent *sees* during
   the loop. The training signal. Each is a small,
   deterministic, well-bounded problem.
5. **Held-out tasks.** 5-10 tasks the agent *never sees*.
   The test set. The user (you) provides the actual files;
   the loop runs the candidate against them at the end. The
   agent must not be able to read these directories.
6. **Stop conditions.** When the loop submits. Defaults
   are: pass_rate == 1.0 for 2 consecutive cycles, wall-
   clock / token budget exhausted, or 3 consecutive stalls
   with forced entropy applied.

## How the meta-skill picks defaults

When the user describes a goal in one sentence, the meta-
skill emits a `/goal` block with sensible defaults for
everything they didn't specify:

- **Wall-clock budget:** 6h (default for "small" goals),
  8h (medium), 24h (large). Edit in the `**Constraints.**`
  block.
- **Token budget:** 800k for 6h, 1M for 8h, 2M for 24h.
- **Design tasks:** 5 (the minimum to give the loop a
  useful signal).
- **Held-out tasks:** 10 (5 also works; the meta-skill
  will not emit fewer than 5).
- **Sub-loss weights:** Correctness, Buildability, Safety,
  Invariants default to 1.0 with `gate`; Performance
  defaults to 0.5-0.7; Legibility, Drift, Cost default
  to 0.2-0.3. The meta-skill tunes these from the goal
  statement ("looks like reference" raises Correctness,
  "fast" raises Performance, "no destructive commands"
  raises Safety).
- **Inner agent:** the user's choice. Cline is the
  default because the bundle ships the Cline adapter; the
  user can switch to Claude Code, Codex, Hermes Agent,
  OpenCode, or the deterministic `fake-agent` stub.

## Writing your own

To write a `/goal` prompt for your own goal:

1. **Describe the goal in one sentence.** Include the
   artifact ("build X"), the constraints ("in Y", "for
   Z"), and any quality bar ("passes acceptance tests",
   "looks like the public reference").
2. **Open a session with the LFD bundle installed** and
   say: *"use loss function development to build X in
   Y with constraints Z"*. The meta-skill loads.
3. **Answer 1-3 clarifying questions.** The meta-skill
   asks at most 3 — usually "what does done look like?",
   "what's the budget?", "which agent and model?". For
   everything else, the meta-skill emits with defaults.
4. **Copy the emitted `/goal` block** into a fresh
   session. The fresh session has only the three inner
   skills (loss-function-design, harness-engineering,
   cline-orchestration) and the goal prompt itself. It
   scaffolds the project, runs the loop, and reports.

## See also

- [`skills/meta-loss-function-development/SKILL.md`](../../skills/meta-loss-function-development/SKILL.md)
  — the meta-skill that emits these prompts
- [`skills/meta-loss-function-development/templates/goal-prompt.md`](../../skills/meta-loss-function-development/templates/goal-prompt.md)
  — the canonical template
- [`skills/loss-function-design/SKILL.md`](../../skills/loss-function-design/SKILL.md)
  — the 4-piece loss anatomy (target / constraints /
  instruments / forced entropy) referenced inside every
  prompt
- [`../lfd-system-verifier/`](../lfd-system-verifier/) —
  a complete scaffolded project (the dogfood example)
