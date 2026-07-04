# /goal: Refactor Internal CLI Tool (Python → Rust)

A worked example of the /goal prompt for an internal-tool
refactor. The user says "refactor our internal `pyforge` CLI from
Python to Rust"; the meta-skill turns it into the block below.

---

/goal — Refactor `pyforge` (Python CLI) to a Rust port

# Operating rules

Read `AGENTS.md` first. Hard rules: do NOT read `verifiers/private/` or `test-tasks/held-out/`; do NOT modify `verifiers/`; the only Codex invocation is via `verifiers/codex-wrapper.sh`; after EACH design-set run, append a one-line entry to `logs/iteration-log.md` with cycle number, hypothesis, expected failure, and pass_rate; if pass_rate doesn't improve by ≥ 0.05 vs prior cycle, force entropy (pick the OPPOSITE of your last change, apply it, document it).

# The 4-piece loss spec

**Target.** A Rust port of `pyforge` (a 4 KLOC Python CLI for managing internal developer environments) that:
- passes 100% of the existing Python test suite when invoked from the new binary (Correctness, weight 1.0, gate)
- compiles with `cargo build --release` on a clean checkout, no warnings (Buildability, weight 1.0, gate)
- median invocation latency ≤ 50 ms (vs Python's 220 ms) (Performance, 0.7)
- zero `unsafe` blocks in production code (Safety, weight 1.0, gate)
- the binary is a single static executable (Legibility, 0.4)
- 100% of the public Python CLI surface is preserved (Invariants, 1.0, gate)
- the skill degrades gracefully on missing toolchain (Drift, 0.2)
- median token spend per task < 12k tokens (Cost, 0.3)

Aggregate target: weighted sum ≥ 0.90. Correctness, Buildability, Safety, and Invariants are gates.

**Constraints.** Wall-clock budget 6 h; token budget 800,000; surface: read `$PROJECT_DIR`, invoke Codex via wrapper, read/write `skills/pyforge-rust-driver/`, append to `logs/`; methodology: deterministic verifiers only — the harness uses the existing Python test suite as the ground truth and a `hyperfine` benchmark for performance.

**Instruments (for every constraint, a CLI command).**
- `verifiers/instruments/time-remaining.sh` — seconds left in the 6h budget
- `verifiers/instruments/tokens-remaining.sh` — tokens left
- `verifiers/instruments/tokens-this-iter.sh` — tokens used last cycle
- `verifiers/instruments/codex-version.sh` — installed Codex version
- `verifiers/instruments/codex-skills-dir.sh` — where Codex scans for skills
- `verifiers/instruments/sub-loss-readout.sh <cycle-N.json>` — per-cycle sub-losses
- `verifiers/run-design-set.sh` — runs the 5 design tasks, emits `logs/design-set-score.json`
- `verifiers/codex-wrapper.sh` — the ONLY way to invoke Codex

**Forced entropy.** Each cycle continues from the previous run's entire context. Local maxima is the default state. Force entropy:
1. **Overfit reflection every cycle.** Before invoking Codex, append to `logs/iteration-log.md`: `cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>"`. If memorizing, the next change must REMOVE an eval-shaped artifact (cap a list, blind a feature, widen the eval, reject a seed), not add one.
2. **Force entropy on stall.** If the last cycle's weighted sum did not improve by ≥ 0.05 over the prior cycle, you MUST read the last 5 entries of `logs/iteration-log.md`, pick the OPPOSITE of your last change, and apply it. Log it.
3. **Keep an iteration log.** The grader will read `logs/iteration-log.md`.

# Candidate / verifier contract

```
candidate: $PROJECT_DIR/skills/pyforge-rust-driver/SKILL.md
verifier:  $PROJECT_DIR/verifiers/instruments/sub-loss-readout.sh <cycle-N.json>
inputs:
  candidate: $PROJECT_DIR/skills/pyforge-rust-driver/SKILL.md
  evidence:   $PROJECT_DIR/verifiers/private/test-suite.log
  evidence:   `cargo build` output
  evidence:   `hyperfine` benchmark output
outputs:
  score: 0.0..1.0
  details: { sub_loss, signal, ... }
  artifacts: [ SKILL.md, test-suite.log, build-output.txt, hyperfine.txt ]
exit_code: 0 on success, non-zero if verifier itself failed
determinism: deterministic
budget: 240s wall-clock, 12000 tokens
```

# Design-set tasks (5, the development signal)

1. `test-tasks/design/01-argparse/` — implement CLI arg parsing matching the existing `pyforge --help` output.
2. `test-tasks/design/02-config-loader/` — implement YAML config loading with the same schema as the Python `pyforge.yaml`.
3. `test-tasks/design/03-logger/` — implement structured logging matching the Python output format.
4. `test-tasks/design/04-errors/` — implement error types and exit codes matching the Python exit codes.
5. `test-tasks/design/05-subcommand-router/` — implement the subcommand routing matching the existing CLI.

# Held-out tasks (10, the test set — DO NOT READ)

`test-tasks/held-out/h01` ... `h10`. Generated from the existing Python test suite and our internal acceptance tests. The grader at `verifiers/private/grader.sh` runs the agent's candidate skill against these. **Reading these voids the held-out score.**

# Harness layout

```
PROJECT_DIR/
├── AGENTS.md                          # the loop driver rules (already there)
├── GOAL.md                            # this file
├── README.md                          # project description
├── verifiers/
│   ├── codex-wrapper.sh               # the only way to invoke Codex
│   ├── compute_sub_losses.py          # 7 sub-losses, deterministic
│   ├── run-design-set.sh              # runs the 5 design tasks
│   ├── instruments/
│   │   ├── time-remaining.sh
│   │   ├── tokens-remaining.sh
│   │   ├── tokens-this-iter.sh
│   │   ├── codex-version.sh
│   │   ├── codex-skills-dir.sh
│   │   └── sub-loss-readout.sh
│   ├── private/                       # HELD-OUT — agent must NOT read
│   │   └── grader.sh                  # the 10 held-out tasks grader
│   └── python-test-suite/             # the existing pyforge tests (read-only)
│       └── ...
├── test-tasks/
│   ├── design/{01..05}/<task>.rs      # 5 design tasks (Rust source stubs)
│   ├── design/{01..05}/prompt.txt
│   ├── design/{01..05}/grade.sh
│   └── held-out/{h01..h10}/...        # 10 held-out tasks (off-limits)
├── skills/pyforge-rust-driver/        # the agent's candidate skill
└── logs/                              # the loop's running trace
```

# Stop conditions

1. pass_rate == 1.0 for 2 consecutive cycles AND last 2 overfit-reflections say "generalizing" — submit.
2. Wall-clock or token budget exhausted — submit best.
3. 3 consecutive cycles with no improvement AND forced entropy applied — submit best.

# First action

0. **Locate your project root.** This prompt uses `$PROJECT_DIR` to refer to the directory containing the harness tree (the `verifiers/`, `test-tasks/`, `GOAL.md`, etc.). Your shell's cwd may or may not be that directory — you have to find it before any other action. In order of preference: (1) if the env var `LFD_PROJECT_DIR` is set and that directory contains a `GOAL.md` or `verifiers/`, use it; (2) if your cwd contains a `GOAL.md` or `verifiers/`, use your cwd; (3) walk up from your cwd: for each ancestor directory, check if it contains a `GOAL.md` or `verifiers/`, the first match is your project root. Once you find it: `cd <project-root>` and set `PROJECT_DIR` to that path. All `$PROJECT_DIR` references in this prompt are relative to that path. If none of the three checks finds the root, **stop** and report the failure. Do not guess.

1. Read `GOAL.md` (this file), `AGENTS.md`, `README.md`, `verifiers/codex-wrapper.sh`, `verifiers/run-design-set.sh`, and every script in `verifiers/instruments/`. (About 5-10 file reads.)
2. Read each design task's `prompt.txt` and the starting file at the top of each design task dir. (5 tasks.)
3. Establish baseline: with no candidate skill installed, run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh` and record the result. Append cycle 0 to `logs/iteration-log.md`.
4. Begin cycle 1. Write a candidate `skills/pyforge-rust-driver/SKILL.md` (and references if needed).
5. Install the skill at the Codex skills dir (use `verifiers/instruments/codex-skills-dir.sh` to confirm the path).
6. Run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh` to score.
7. Compare to baseline. If improved, save `logs/best-cycle.json`. If not, force entropy.
8. Iterate. After each cycle, append to `logs/iteration-log.md`. Apply forced entropy on stall.
9. Stop when one of the stop conditions above is met.
10. On stop, leave `skills/pyforge-rust-driver/SKILL.md` + references + `logs/iteration-log.md` + `logs/best-cycle.json`. Verify the skill is also installed at the Codex skills dir.

# Practical hints

- The existing `pyforge` Python source is in the user's repo. Read it for reference but don't modify it.
- The Python test suite is the ground truth. Any test the Rust port fails is a regression. Don't ship partial ports.
- Codex v0.x with whatever model the user has authenticated (default GPT-5). Do not switch the model.
- Wall-clock per design set is ~60-180 s. With 6 h budget, you can do ~120-240 cycles. Don't waste them.
- The 3-cheats pattern from the @elvissun article is exactly what you're guarding against: don't reward-hack the design set. The held-out grader will catch it.
- The Rust port should follow idiomatic Rust: no `unwrap()` in production code, prefer `Result<T, E>` returns, use `clap` for arg parsing, `serde_yaml` for config.

DONE
