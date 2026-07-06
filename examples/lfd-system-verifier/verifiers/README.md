# verifiers/

The harness the loop runs against. Two wrappers (fake +
real), one anti-cheat firewall, the per-task driver, and
33 instruments.

## Wrappers

| File | What it does | When it's used |
|---|---|---|
| `fake-wrapper.sh` | Deterministic stub. Writes a fixed `cycle-summary.json` and exits 0. No model, no network. | `run-verification.sh` (the tools gate) |
| `fake-method-wrapper.sh` | 3-cycle stub for the method test. Emits different candidate text per cycle to simulate an agent improving and then plateauing. | The method task in `run-verification.sh` |
| `cline-wrapper.sh` | Real Cline wrapper. Invokes `cline` with `--auto-approve true --thinking none --json` (no `--worktree`, no `--provider`/`--model`). Parses the NDJSON, emits the 8-shared-key `cycle-summary.json`. | `run-verification-real.sh` (the integration gate) |

The wrappers' contract is documented at
[`../../skills/cline-orchestration/references/cline-wrapper-contract.md`](../../skills/cline-orchestration/references/cline-wrapper-contract.md).
Any new agent adapter (Claude Code, Codex, Hermes, OpenCode)
must satisfy the same contract.

## Anti-cheat firewall

`integrity.sh` runs before the design set on every cycle.
The 4 default guards:

| Guard | What it detects |
|---|---|
| `no-grade-todo-stub` | A `grade.sh` is a TODO marker (agent didn't fill it in) |
| `no-stub-always-pass` | A `grade.sh` has no real assertion (empty stub that always returns 0) |
| `no-sleep-in-grader` | A `grade.sh` uses `time.Sleep` / `sleep` to mask timing failures |
| `agents-md-has-hard-rules` | The agent removed the held-out / private rules from `AGENTS.md` |

The user (you) adds project-specific guards inside the
same file. Each guard is a bash function that returns
0 (clean) or 1 (violation); the script's `check` helper
aggregates results. Exits 1 on any violation, which
makes the loop's cycle driver abort the run.

## Per-task driver

`run-design-set.sh` walks `test-tasks/design/`, invokes
the configured wrapper (`LFD_WRAPPER`, defaults to
`verifiers/fake-wrapper.sh`) once per task, then runs
each task's `grade.sh` against the wrapper's output.
Emits a JSON aggregate (pass_rate + per-task scores)
to stdout. The orchestrator captures that to
`logs/cycle-N/design-set-score.json` for the cycle driver
to read.

## Per-cycle sub-loss scorer

`compute_sub_losses.py` is copied at runtime from
[`../../skills/cline-orchestration/references/compute-sub-losses.py`](../../skills/cline-orchestration/references/compute-sub-losses.py).
Takes a `cycle-summary.json` plus a `design-set-score.json`
and emits the 7-sub-loss breakdown (`correctness`,
`performance`, `safety`, `legibility`, `invariants`,
`drift`, `cost`) with weights, gates, weighted sum, and
`gates_passed`. The loop driver reads this as
`logs/cycle-N/sub-losses.json`.

## Instruments

33 shell scripts in `instruments/`. 5 are **real**
(non-stub, the loop depends on them); 27 are **stubs**
that return 0.0 by default and have a `# HITL:` section
the user wires for their stack.

**Real instruments** (the loop fails if any of these is
broken):

- `time-remaining.sh` — seconds left in the wall-clock
  budget
- `tokens-remaining.sh` — tokens left in the token budget
- `tokens-this-iter.sh` — tokens used in the last cycle
- `per-cycle-wall-clock.sh` — wall-clock spent in the last
  cycle (recorded on every cycle)
- `test-freshness.sh` — design-set SHA unchanged since
  last cycle (catches agent editing tests to pass them)
- `hidden-unread.sh` — agent's last-cycle transcript
  doesn't reference `verifiers/private/` or held-out task
  names
- `smallness.sh` — parses `MAX_LOC_PER_CYCLE` from
  `GOAL.md` (default 200), returns 1.0 if candidate LOC
  ≤ budget, decaying to 0.0

**Stub instruments** (return 0.0; user wires each in
3-5 lines for their stack): see
[`./instruments/EXAMPLE-IMPLEMENTATIONS.md`](./instruments/EXAMPLE-IMPLEMENTATIONS.md)
for opinionated example implementations of all 27
stubs (linter, type-check, complexity, unit-tests,
integration-tests, test-coverage, mutation-tests,
e2e-tests, regression-tests, contract-tests, secret-scan,
sast, dependency-audit, sbom, a11y, i18n, docs-coverage,
observability, trace-coverage, perf-budget, bundle-size,
startup-time, hermeticity, determinism, flakiness,
license-audit, supply-chain), with anti-cheat defenses,
exit-code contracts, and the partial-credit gradient
shape from `loss-function-design`.

**Per-runtime stubs** (only used by one orchestrator):

- `cline-version.sh`, `cline-skills-dir.sh` — only used
  by the real-agent run with Cline
- `fake-agent-skills-dir.sh` — only used by the fake-agent
  run

## Held-out grader

`private/grader.sh` is **off-limits to the agent**. It
runs the candidate against the held-out tasks
(`test-tasks/held-out/h*`) and emits
`logs/held-out-score.json`. The held-out tasks test
harder properties the agent never saw during the loop:
shared-parser-shape, install-determinism, drift-opt-in,
force-entropy-trigger, compatibility-matrix-consistency.

The directory is `chmod 700` and the grader is `chmod 600`.
The loop's `AGENTS.md` says: "DO NOT read
`verifiers/private/`."

The held-out grader is **layer 2 of 4** in the
anti-cheat defense. Layer 1 (integrity.sh), layer 3
(hidden-unread.sh), and layer 4 (test-freshness.sh)
catch different cheats. For the full mapping and the
honest gaps (e.g. no git-status snapshot), see
[`../../BUILDING-A-GREAT-HARNESS.md`](../../BUILDING-A-GREAT-HARNESS.md)
section 7 — "The 4 layers of anti-cheat defense."

## Per-file exit-code contract

| File | Exit 0 | Exit 1 | Exit 2 |
|---|---|---|---|
| `*wrapper.sh` | Wrapper ran, emitted valid `cycle-summary.json` | Wrapper ran, emitted invalid output (e.g. parse failure) | Missing arg or `cline` not on PATH |
| `integrity.sh` | All guards pass | One or more guards failed | `--help` or unknown flag |
| `run-design-set.sh` | All tasks passed (`pass_rate == 1.0`) | At least one task failed | No design tasks found, or wrapper not executable |
| `compute_sub_losses.py` | Sub-losses computed | Malformed input | Missing arg |
| `instruments/*.sh` | Measurement present (printed a number) | Internal error (file missing, parse failure) | — |

## See also

- [`../../skills/loss-function-design/SKILL.md`](../../skills/loss-function-design/SKILL.md)
  — the verifier contract: candidate × evidence → score
- [`../../BUILDING-A-GREAT-HARNESS.md`](../../BUILDING-A-GREAT-HARNESS.md)
  — the full V0→V1 surface specification
- [`../test-tasks/README.md`](../test-tasks/README.md) —
  the per-task contract this directory grades
