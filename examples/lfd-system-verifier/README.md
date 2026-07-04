# LFD System Verifier

The LFD system verifies itself. This project scaffolds a
complete loss-function-driven loop and runs it two ways:

- **Fake-agent** (deterministic, no model, no network):
  tests that the LFD *tools* work — parsers, install,
  driver, scorer shape. Bit-exact reproducible, ~10s.
- **Real-agent** (with a real coding agent — Cline,
  Claude Code, Codex, Hermes, OpenCode): tests that the
  LFD *integration* works — the agent actually exercises
  the harness, the per-cycle outputs flow correctly, and
  the per-task graders evaluate real agent output. Non-
  deterministic by construction, runs in ~3-5 minutes.

This is **dogfood**: the system is its own first user.
Both verifiers must pass for the LFD system to be
considered fully verified.

## Quick start

```bash
cd examples/lfd-system-verifier

# Fast deterministic gate (CI, ~10s)
./run-verification.sh

# Real-agent gate (proves integration, ~3-5 min)
./run-verification-real.sh              # Cline (default)
./run-verification-real.sh "" "" claude-code
./run-verification-real.sh "" "" opencode
```

The fake-agent script (`run-verification.sh`):

1. Installs the LFD bundle into a fresh temp profile
2. Runs 1 cycle of the loss-function-driven loop against
   the fake agent
3. Runs 5 design tasks (the loop's main grader)
4. Runs 5 held-out tasks (a separate grader for harder
   properties)
5. Runs 1 method task (3 cycles with the fake-method
   wrapper, to exercise the loop's improvement + plateau
   detection machinery)
6. Produces `verification-report.md` and
   `verification-report.json`
7. Cleans all per-cycle artifacts (`.iterations/`,
   `logs/cycle-*/`) keeping only the report

The real-agent script (`run-verification-real.sh`):

1. Installs the LFD bundle into a fresh temp profile
2. Runs 5 design tasks with a real coding agent
3. Produces `verification-report-real.md` and
   `verification-report-real.json`
4. Cleans all per-cycle artifacts

After the run, only these files remain:

```
# Fake-agent run outputs (run-verification.sh)
verification-report.md       # the markdown report
verification-report.json     # the machine-readable report
logs/iteration-log.md        # the loop's log
logs/best-cycle.json         # the best cycle so far
logs/held-out.log            # the held-out grader log

# Real-agent run outputs (run-verification-real.sh)
verification-report-real.md
verification-report-real.json
logs/iteration-log.md        # overwritten by the real-agent run
logs/best-cycle.json         # overwritten by the real-agent run
```

All `.iterations/` and `logs/cycle-*/` artifacts are
removed.

## How long does it take?

**Fake-agent** (`run-verification.sh`): ~10–15 seconds.
The fake agent is instant, so the wall-clock is dominated
by:

- `install.sh --force` (~1 s)
- 5 design tasks (each ~0.5 s, total ~3 s)
- 5 held-out tasks (each ~0.5 s, total ~3 s)
- Method test (3 cycles, ~5 s)
- Cycle driver overhead (~1 s)

If the fake-agent verifier takes more than 60 seconds,
something is wrong.

**Real-agent** (`run-verification-real.sh`): ~3-5 minutes,
depending on the agent. Cline with kimi-for-coding in our
test runs took ~3.5 minutes. Claude Code or Codex will
vary. Wall-clock budget is 5 min by default; configurable
via `LFD_REAL_BUDGET` (e.g. `LFD_REAL_BUDGET=900` for
15 min).

## What the verifier proves

The verifier exercises every bundle skill end-to-end:

| Component | How it's tested |
|---|---|
| `install.sh` | design task `d3-verify-install-script`; held-out `h2-install-determinism` |
| `bundle.json` manifest | design task `d2-verify-bundle-manifest` |
| Adapter parsers (5 of them) | design task `d1-parse-cline-output`; held-out `h1-shared-parser-shape` |
| Per-cycle sub-loss scorer | design task `d4-compute-sub-losses`; held-out `h3-drift-opt-in` |
| Loop driver (`cycle.sh`) | design task `d5-loop-driver-smoke`; held-out `h4-force-entropy-trigger` |
| Compatibility matrix | held-out `h5-compatibility-matrix-consistency` |

If this verifier passes, the LFD system is healthy. If
it fails, the report tells you which component regressed.

## Determinism

The fake-agent adapter has no model and no network. Two
consecutive runs of `run-verification.sh` produce
byte-identical output except for:

- the `timestamp` field in `verification-report.md` /
  `verification-report.json`
- the `elapsed_seconds` field (wall-clock drift)
- log timestamps (`logs/held-out.log`, etc.)

The data values (sub-loss scores, design pass rate,
held-out pass rate) are bit-exact reproducible.

To verify determinism:

```bash
./run-verification.sh
cp verification-report.json /tmp/run1.json
./run-verification.sh
cp verification-report.json /tmp/run2.json
diff <(jq 'del(.timestamp, .elapsed_seconds)' /tmp/run1.json) \
     <(jq 'del(.timestamp, .elapsed_seconds)' /tmp/run2.json)
# Should produce no output.
```

## CI integration

The verifier is designed to run in CI. Recommended usage:

```yaml
# .github/workflows/lfd-verifier.yml
- name: Verify LFD system
  run: |
    cd examples/lfd-system-verifier
    ./run-verification.sh
- name: Upload verification report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: lfd-verification-report
    path: examples/lfd-system-verifier/verification-report.md
```

The verifier exits 0 on pass, 1 on fail — standard CI
semantics.

## File layout

```
lfd-system-verifier/
├── README.md                            # this file
├── GOAL.md                              # the /goal prompt
├── AGENTS.md                            # the loop's hard rules
├── run-verification.sh                  # the orchestrator
├── verification-report.md               # produced by run-verification.sh
├── verification-report.json             # produced by run-verification.sh
├── verifiers/
│   ├── fake-wrapper.sh            # the deterministic stub
│   ├── run-design-set.sh                # per-task driver
│   ├── compute_sub_losses.py            # per-cycle sub-loss scorer
│   ├── instruments/
│   │   ├── fake-agent-skills-dir.sh     # the agent's skills dir
│   │   ├── time-remaining.sh            # wall-clock budget tracker
│   │   ├── tokens-remaining.sh          # token budget tracker
│   │   ├── tokens-this-iter.sh          # per-cycle tokens
│   │   └── sub-loss-readout.sh          # per-cycle sub-loss reader
│   └── private/
│       └── grader.sh                    # the held-out grader
├── test-tasks/
│   ├── design/                          # 5 design tasks (the loop sees these)
│   │   ├── d1-parse-cline-output/{prompt.txt, grade.sh, sample.ndjson}
│   │   ├── d2-verify-bundle-manifest/{prompt.txt, grade.sh}
│   │   ├── d3-verify-install-script/{prompt.txt, grade.sh}
│   │   ├── d4-compute-sub-losses/{prompt.txt, grade.sh}
│   │   └── d5-loop-driver-smoke/{prompt.txt, grade.sh}
│   └── held-out/                        # 5 held-out tasks (agent never sees these)
│       ├── h1-shared-parser-shape/{prompt.txt, grade.sh}
│       ├── h2-install-determinism/{prompt.txt, grade.sh}
│       ├── h3-drift-opt-in/{prompt.txt, grade.sh}
│       ├── h4-force-entropy-trigger/{prompt.txt, grade.sh}
│       └── h5-compatibility-matrix-consistency/{prompt.txt, grade.sh}
├── skills/
│   └── lfd-system-driver/SKILL.md       # the candidate skill the agent produces
└── logs/                                # populated by run-verification.sh
    ├── iteration-log.md
    ├── best-cycle.json
    ├── held-out.log
    ├── held-out-score.json
    └── <task>.log
```

## Extending the verifier

To add a new design task:

1. Create `test-tasks/design/d6-<name>/`
2. Write `prompt.txt` (the task description)
3. Write `grade.sh` (returns 0/1, prints `score=<float>`)
4. Re-run `./run-verification.sh` — the new task is
   auto-discovered by `run-design-set.sh`

To add a new held-out task:

1. Create `test-tasks/held-out/h6-<name>/`
2. Write `prompt.txt` and `grade.sh`
3. The held-out grader auto-enumerates from the dir

The verifier is intentionally **auto-discovering**: it
picks up new tasks from the filesystem without code
changes to the orchestrator.

## See also

- `../../skills/fake-agent-orchestration/` — the
  fake-agent adapter skill (the deterministic stub)
- `../../skills/loop-driver/` — the loop driver
- `../../skills/cline-orchestration/references/compute-sub-losses.py` —
  the canonical per-cycle sub-loss scorer (copied into
  the verifier at runtime)
- `../../compatibility.md` — the compatibility matrix
  that `h5-compatibility-matrix-consistency` checks
