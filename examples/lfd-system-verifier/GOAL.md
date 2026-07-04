# GOAL — verify the LFD system end-to-end

This is the `/goal` prompt for the LFD system verifier
(dogfood). It runs the loop against the deterministic
`fake-agent` adapter — no model, no network, no real
coding agent. The loop runs for **1 cycle only**, and
the verifier is bit-exact deterministic.

## Target

**Goal:** Prove the LFD system itself is operational by
running a complete loss-function-driven loop against
itself, in under 5 minutes, with bit-exact reproducible
output.

**Done condition:** `verification-report.md` exists at
`$VERIFY_ROOT/verification-report.md`, marked `PASS`,
with all 5 design tasks and all 5 held-out tasks passing.

## Constraints

- **Wall-clock budget:** 300 seconds (5 minutes). The
  fake-agent wrapper is instant, so this is generous.
- **Token budget:** 0 (no model is invoked).
- **Forced entropy:** disabled. Single cycle, no
  iteration.
- **Output determinism:** byte-exact reproducible.
  Two consecutive runs of `run-verification.sh` must
  produce identical output (modulo timestamp and
  elapsed_seconds).

## Runtime

- **Inner loop:** the `fake` CLI.
- **Wrapper contract:** see
  `verifiers/fake-wrapper.sh` and
  `skills/fake-agent-orchestration/`.

## Instruments

- `verifiers/instruments/time-remaining.sh` — wall-clock
  budget tracker
- `verifiers/instruments/tokens-remaining.sh` — token
  budget tracker (always 0 for fake)
- `verifiers/instruments/tokens-this-iter.sh` — per-cycle
  tokens (always 0)
- `verifiers/instruments/fake-agent-skills-dir.sh` — the
  agent's skills directory (the fake agent's)
- `verifiers/instruments/sub-loss-readout.sh` — per-cycle
  sub-loss scorer

## Design-set tasks

The 5 design tasks exercise every bundle skill. Each
lives in `test-tasks/design/d<n>-<name>/`:

- `d1-parse-cline-output/` — run
  `parse_cline_output.py` on a sample NDJSON, assert
  the 8 required keys are present and have the
  expected types.
- `d2-verify-bundle-manifest/` — read `bundle.json`,
  assert version 2.1.0, 11 skills, MIT license, all
  6 adapter names present.
- `d3-verify-install-script/` — run
  `install.sh --check` against a fresh profile, assert
  exit 0 and the expected skills present.
- `d4-compute-sub-losses/` — run
  `compute_sub_losses.py` on a sample input, assert
  all 7 sub-losses present and gates pass.
- `d5-loop-driver-smoke/` — invoke
  `cycle.sh` with a stub candidate, assert
  cycle-summary.json + sub-losses.json +
  best-cycle.json all exist with the correct schema.

## Held-out tasks (the agent never sees these)

The 5 held-out tasks test harder properties the agent
never reads. They live in
`test-tasks/held-out/h<n>-<name>/` and are graded by
`verifiers/private/grader.sh`:

- `h1-shared-parser-shape/` — all 5 adapter parsers
  produce the same 8-key shape on identical input.
- `h2-install-determinism/` — `install.sh` is
  deterministic: same input → same output.
- `h3-drift-opt-in/` — the `drift` sub-loss correctly
  handles the `expected_model=""` opt-in.
- `h4-force-entropy-trigger/` — the loop's force-entropy
  rule triggers on consecutive stalls.
- `h5-compatibility-matrix-consistency/` — the
  `compatibility.md` matrix is internally consistent.

## Reference artifacts

The held-out graders use the public LFD bundle as
reference. To regenerate the held-out tasks:

- All 5 adapter parsers: see
  `skills/<adapter>-orchestration/scripts/parse_<adapter>_output.py`
  in the LFD bundle.
- The drift sub-loss logic: see
  `skills/cline-orchestration/references/compute-sub-losses.py`
  in the LFD bundle.
- The compatibility matrix: see `compatibility.md`
  in the LFD bundle.

## Stop conditions

- **Success:** the held-out grader exits 0 (all 5
  held-out tasks pass) AND the design-set pass rate
  is 1.0.
- **Wall-clock:** 300 s elapsed.
- **Failure:** any held-out task fails (the loop
  stops immediately and the report is marked `FAIL`).

## Notes

- The verifier is **not** a substitute for running
  the LFD loop against a real coding agent. It's the
  test for the LFD system itself.
- The verifier is **deterministic** because the
  fake-agent wrapper has no model and no network. Any
  non-determinism in the report is a bug in the loop
  driver, the parsers, or the wrapper.
- After the run, only `verification-report.md`,
  `verification-report.json`, `logs/iteration-log.md`,
  `logs/best-cycle.json`, and `logs/held-out.log`
  remain. All `.iterations/` and `logs/cycle-*/`
  artifacts are removed.
