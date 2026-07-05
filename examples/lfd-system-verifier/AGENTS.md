# AGENTS.md — loop driver rules for the LFD system verifier

These are the loop driver rules for the LFD system
verifier (dogfood). The inner agent (the `fake`
adapter, by default; a real coding agent when
`run-verification-real.sh` is used) does not
actually read this — the cycle driver is the only
thing that reads it, and only to follow the
workflow.

## Hard rules

1. Read `GOAL.md` first.
2. Hard rules:
   - DO NOT read `verifiers/private/` or `test-tasks/held-out/`. These are graded out-of-band by the held-out grader.
   - DO NOT modify `verifiers/`. The wrapper, parsers, sub-loss scorer, and instruments are the system under test.
   - The only agent invocation is via `verifiers/fake-wrapper.sh` (in the `run-verification.sh` tools gate) or `verifiers/<runtime>-wrapper.sh` (in the `run-verification-real.sh` integration gate; the runtime is selected by the script's third arg, default `cline`).
   - Before every cycle, run `verifiers/integrity.sh`. If any guard fails, refuse to score that cycle.
3. After EACH design-set run, append a one-line
   entry to `logs/iteration-log.md` with cycle
   number, hypothesis, expected failure,
   pass_rate, weighted_sum, gates, axes_met,
   and wall_clock_s.
4. If weighted_sum does not improve by >= 0.05,
   force entropy: pick the OPPOSITE of your last
   change, apply it, document it. (This is the
   loss-function-design rule, applied even when
   the agent is fake.)

## Workflow

1. Read `GOAL.md`, this file, `README.md`,
   `verifiers/fake-wrapper.sh`,
   `verifiers/run-design-set.sh`, and every script
   in `verifiers/instruments/`.
2. Read each design task's `prompt.txt` and
   `grade.sh`.
3. Establish baseline: no candidate skill
   installed, run
   `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh`.
4. Begin cycle 1. Write a candidate
   `skills/lfd-system-driver/SKILL.md` (and
   references).
5. Install the skill where the agent will pick it
   up (`verifiers/instruments/fake-agent-skills-dir.sh`
   prints the dir).
6. Run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh`
   to score.
7. Compare to baseline. Force entropy on stall.
8. Iterate until one of the stop conditions in
   `GOAL.md` is met.
9. Leave the skill, references,
   `logs/iteration-log.md`, and
   `logs/best-cycle.json`.

## Why this matters for dogfood

The AGENTS.md file is part of the LFD system under
test. The cycle driver must read it, the wrapper
must respect it, and the held-out grader must
verify it exists with the right shape.

The held-out task `h4-force-entropy-trigger` runs
a 3-cycle loop with a no-op candidate and asserts
that the cycle driver appends a `FORCED_ENTROPY=true`
entry to the iteration log on the second stall. If
the AGENTS.md file is missing the "force entropy"
rule, the cycle driver will not trigger it.
