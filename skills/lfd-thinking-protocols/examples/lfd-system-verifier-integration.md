# Integration test for lfd-thinking-protocols

This document is the **proof** that adding the
`lfd-thinking-protocols` skill did not break the
V0→V1→HITL→V2+ flow.

The proof is **two runs**:

1. The **fake-agent** run (`run-verification.sh`),
   which exercises the deterministic stub adapter.
   This proves the V0→V1 baseline still works.
2. The **real-agent** run (`run-verification-real.sh`),
   which exercises a real coding agent (Cline by
   default). This proves the V2+ flow still works
   with a real LLM.

Both runs are wrapped by
`examples/run-dev-integration.sh` (a developer-only
tool — see the script header for the path prerequisite), which:

1. Runs the fake-agent verifier and asserts
   `overall == "PASS"`,
   `design_pass_rate == 1.0`,
   `weighted_normalized >= 0.85`,
   `held_out_grader_exit == 0`.
2. Runs the real-agent verifier and asserts
   `design_pass_rate >= 0.8` (per the
   `lfd-system-verifier` threshold for real-agent
   runs, where a 4/5 is the norm).

If either assertion fails, the integration is
considered broken and the skill has regressed the
loop.

## How to run

From the repo root:

```bash
./skills/lfd-thinking-protocols/examples/run-dev-integration.sh (developer-only — requires LFD repo at a known path)
```

Or from the verifier-project root:

```bash
cd examples/lfd-system-verifier
# fake-agent (deterministic, ~10s)
./run-verification.sh ../../

# real-agent (Cline, ~3-5 min)
LFD_REAL_BUDGET=300 ./run-verification-real.sh ../../ "" cline
```

## What the 4 checks prove

The fake-agent held-out task
`h6-thinking-protocols-wired` (in
`test-tasks/held-out/h6-thinking-protocols-wired/`)
is the canonical integration test. It runs as part
of the fake-agent verifier's held-out pass. The 4
checks are independent:

1. **The skill is installed and discoverable.**
   The skill directory exists, the SKILL.md has the
   right frontmatter name, the 10 gate templates
   exist in `templates/gates.md`. A failure here
   means the bundle was not properly installed.
2. **The 10 handoff files exist in the project.**
   The verifier creates stub handoffs to prove the
   meta-skill's handoff contract works. A failure
   here means the meta-skill's gate-emit logic is
   broken.
3. **The 4 default anti-cheat guards still fire.**
   The integrity script is run; the 4 default guards
   (`no-grade-todo-stub`, `no-stub-always-pass`,
   `no-sleep-in-grader`,
   `agents-md-has-hard-rules`) are present and exit 0
   on the finished harness. A failure here means
   adding the skill regressed the V0→V1 baseline.
4. **The cycle driver still parses the multi-axis
   target.** `cycle.sh` still reads `pass_rate` and
   `weighted_sum` and loads without bash syntax
   errors. A failure here means the V2+ flow is
   broken.

The 5th check — "the full fake-agent run still
produces PASS" — is the integration test's
*meta-assertion*: the entire verifier (including
h1-h6 held-out tasks) returns `overall: PASS`. This
is what the integration script's `fake_overall`
check reads.

## What the real-agent run proves

The fake-agent run uses a deterministic stub
adapter. It proves the **system** works. The
real-agent run uses a real coding agent (Cline).
It proves the **integration** works — a real LLM
can drive the loop, the per-cycle outputs flow
correctly, and the per-task graders evaluate real
agent output.

A 4/5 real-agent pass is the norm. The threshold
is `pass_rate >= 0.8` per
`lfd-system-verifier/SKILL.md`. A task failing
*consistently* across multiple runs is a real
regression; a task failing *once in 5 runs* is
just model noise.

## Failure modes

If the integration test fails, the diagnostic
recipe is:

1. **Fake-agent fails on h6 check 1** (skill
   install). The bundle was not re-installed. Run
   `cd ~/fleet/loss-function-development-skills
   && ./install.sh
   ~/.hermes/profiles/loss-function-developer
   --force` to install.
2. **Fake-agent fails on h6 check 2** (handoff
   files). The handoff contract is broken. Check
   that the meta-skill actually writes
   `$PROJECT_DIR/handoffs/NN-<name>.md` for each
   gate. Read
   `references/handoff-files.md` for the
   expected paths.
3. **Fake-agent fails on h6 check 3** (integrity
   guards). Adding the skill regressed the
   `verifiers/integrity.sh` guards. Check the
   `examples/lfd-system-verifier/verifiers/integrity.sh`
   file has all 4 default guards present.
4. **Fake-agent fails on h6 check 4** (cycle
   driver). The loop driver's multi-axis parsing
   is broken. Check
   `skills/loop-driver/scripts/cycle.sh` still
   reads `pass_rate` and `weighted_sum` from
   `GOAL.md`.
5. **Fake-agent fails on overall assertion** (full
   run). The verifier's report is not PASS. Read
   `verification-report.md` for the failure shape.
   A failure in a design task (d1-d5) is usually a
   bug in the verifier-project's grader, not the
   LFD bundle.
6. **Real-agent fails with `design_pass_rate <
   0.8`.** This may be a flake. Re-run to
   disambiguate. If the failure is consistent
   across 3+ runs, a real-agent task is broken.
   Read the held-out `h6` grader's output to see
   which of the 4 checks failed.

## Verifying the verifier is honest

The held-out `h6-thinking-protocols-wired/grade.sh`
script is the integration test's *self-check*. It
runs as part of the fake-agent verifier's held-out
pass. The fact that the fake-agent verifier
produces `overall: PASS` is the proof that
`h6` itself is honest — a held-out grader that
always returns 1.0 would be caught by the
*intentionally-broken-harness* test. The pattern
is in `references/frameworks.md` §7 of this skill
("Anti-cheat guard template").

To run the intentionally-broken-harness test on
`h6`:

1. Add a deliberate bug to one of the 4 checks
   (e.g., rename a guard in `verifiers/integrity.sh`).
2. Run the fake-agent verifier.
3. Confirm `verification-report.md` shows FAIL and
   the held-out h6 task returns 0.0.
4. Restore the harness.
5. Run the fake-agent verifier again.
6. Confirm `verification-report.md` shows PASS.

If the broken-harness run does NOT catch the
bug, the h6 grader is dishonest and needs to be
rebuilt. (The recipe is from
`lfd-system-verifier/SKILL.md` lines 96-119.)
