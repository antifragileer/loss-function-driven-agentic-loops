# LFD System Verification Report

**Generated:** 2026-07-04T00:25:49Z
**Bundle version:** 2.1.0
**Repo:** `/Users/oxenated/fleet/loss-function-development-skills`
**Profile:** `/var/folders/36/4qcyx1yx7936hgvr4lxvv1h80000gp/T/lfd-verify-profile-XXXXXX.ENDpaWbdXw`
**Elapsed:** 2s

## Overall: **PASS**

| Metric | Value |
|---|---|
| Design-set pass rate | 1.0 |
| Weighted normalized | 1.0 |
| Gates passed | True |
| Cycle driver exit | 0 |
| Held-out grader exit | 0 |

## Design tasks

The 5 design tasks are listed in `test-tasks/design/`. Each has a
`prompt.txt` (the cycle prompt) and a `grade.sh` (the per-task
grader, runs after the wrapper returns). The design set's
`design-set-score.json` is in `logs/cycle-1/`.

To re-run a single design task:

```bash
cd examples/lfd-system-verifier
./verifiers/run-design-set.sh d1
```

## Held-out tasks

The 5 held-out tasks are listed in `test-tasks/held-out/`. They
test harder properties the agent never sees during the loop.
The held-out grader is `verifiers/private/grader.sh`. Its output
is in `logs/held-out.log`.

## What the verifier proves

This verifier proves the following about the LFD system:

1. The `install.sh` script installs all 11 skills into a
   fresh profile and `install.sh --check` passes.
2. The 5 Python parsers (cline, claude-code, codex,
   hermes-agent, opencode) all compile and produce the
   shared 8-key JSON shape on empty input.
3. The `bundle.json` manifest is internally consistent
   (version, skills list, install_order, license).
4. The per-cycle sub-loss scorer (`compute_sub_losses.py`)
   returns all 7 sub-losses and reports gates correctly.
5. The loop driver (`cycle.sh`) runs a complete cycle:
   reads the iteration log, forms a hypothesis, invokes
   the wrapper, runs the design set, scores, appends to
   the log, updates best-cycle.json.
6. The fake-agent adapter produces deterministic output
   (no model, no network, bit-exact reproducible).

If this verifier passes, the LFD system is healthy.

## How to invoke

```bash
cd examples/lfd-system-verifier
./run-verification.sh
```

The verifier is fully self-contained. It installs the bundle
into a fresh temp profile, runs 1 cycle, and produces the
report. The temp profile is removed at the end.

## Determinism

Two consecutive runs of this script produce byte-identical
output except for the timestamp and elapsed_seconds fields.
The fake-agent adapter has no model and no network, so the
determinism guarantee is exact.

To verify determinism:

```bash
./run-verification.sh
sha256sum verification-report.json
./run-verification.sh
sha256sum verification-report.json
# Compare the two sha256sums (modulo the timestamp field).
```
