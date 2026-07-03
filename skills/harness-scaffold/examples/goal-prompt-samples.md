# Goal Prompt Samples

Three /goal prompts the scaffold has been tested against. The
format is the one from `meta-loss-function-development/templates/goal-prompt.md`.
The scaffold accepts any prompt that follows this shape; free-form
prompts will fall back to defaults.

---

## Sample 1: Slack desktop clone in Go

```
/goal — Build a Slack Desktop Clone in Go (via Cline + LFD)

# Operating rules

Read `AGENTS.md` first. Hard rules: do NOT read `verifiers/private/` or `test-tasks/held-out/`; do NOT modify `verifiers/`; the only Cline invocation is via `verifiers/cline-wrapper.sh`; after EACH design-set run, append a one-line entry to `logs/iteration-log.md`.

# The 4-piece loss spec

**Target.** A Cline skill (SKILL.md + references) that, when loaded, helps Cline build a working Go binary that mirrors the *visible behavior* of the Slack desktop client on a held-out task set. The skill must:
- pass ≥ 8/10 held-out tasks (Correctness, weight 1.0, gate)
- the produced code passes `go build` on a clean checkout (Buildability, weight 0.7, gate)
- median p50 task completion < 180 s wall-clock (Performance, 0.5)
- zero destructive commands in any transcript (Safety, weight 1.0, gate)

# Design-set tasks (5, the development signal)

1. `test-tasks/design/01-send-message/` — implement a function that takes a channel name and message string, posts the message, returns the message ID.
2. `test-tasks/design/02-list-channels/` — implement a function that returns `[]Channel{ID, Name}` for the current user.
3. `test-tasks/design/03-react-emoji/` — add a `:fire:` reaction to a given message ID; return the reaction count after.
4. `test-tasks/design/04-thread-reply/` — given a parent message ID and a reply string, post the reply as a threaded reply; return the thread root ID.
5. `test-tasks/design/05-mark-read/` — mark a channel as read for the current user up to a given message ID.

# Held-out tasks (10, the test set — DO NOT READ)

`test-tasks/held-out/h01` ... `h10`. Generated from the public Slack web API docs (https://api.slack.com/web) and public webhooks. The grader at `verifiers/private/grader.sh` runs the agent's candidate skill against these.

DONE
```

**What the scaffold produces:** 5 design tasks with `task-NN` slugs
`01-send-message/` through `05-mark-read/`, 10 held-out task
directories `h01` through `h10`, all 6 instrument scripts, the
wrapper, the design-set runner, and the held-out grader stub.

---

## Sample 2: Internal CLI tool in Rust

```
/goal — Refactor our internal CLI tool from Python to Rust

# Operating rules

Read `AGENTS.md` first. Hard rules: do NOT read `verifiers/private/` or `test-tasks/held-out/`; do NOT modify `verifiers/`; the only Codex invocation is via `verifiers/codex-wrapper.sh`; ...

# The 4-piece loss spec

**Target.** A Rust port of our internal CLI tool (currently Python) that:
- passes 100% of the existing Python test suite (Correctness, weight 1.0, gate)
- compiles with `cargo build --release` on a clean checkout (Buildability, 1.0, gate)
- median invocation latency < 50 ms vs Python's 220 ms (Performance, 0.7)
- zero `unsafe` blocks in production code (Safety, 1.0, gate)
- the binary is a single static executable (Legibility, 0.4)

# Design-set tasks (5, the development signal)

1. `test-tasks/design/01-argparse/` — implement CLI arg parsing matching the existing Python interface.
2. `test-tasks/design/02-config-loader/` — implement YAML config loading with the same schema.
3. `test-tasks/design/03-logger/` — implement structured logging matching the Python output format.
4. `test-tasks/design/04-errors/` — implement error types and exit codes matching the Python exit codes.
5. `test-tasks/design/05-subcommand-router/` — implement the subcommand routing matching the existing CLI.

# Held-out tasks (10, the test set — DO NOT READ)

`test-tasks/held-out/h01` ... `h10`. Generated from the existing Python test suite and our internal acceptance tests. The grader at `verifiers/private/grader.sh` runs the agent's candidate skill against these.

DONE
```

**What the scaffold produces:** 5 design tasks (slugged
`01-argparse/` etc.), 10 held-out tasks, **a Codex wrapper** (because
`inner loop is the \`codex\` CLI` was in the prompt), all
instruments, the design-set runner, and the held-out grader
stub.

---

## Sample 3: Algorithm from a paper

```
/goal — Implement the FlashAttention-2 algorithm from the paper

# Operating rules

Read `AGENTS.md` first. ...

# The 4-piece loss spec

**Target.** A Cline skill that helps Cline implement FlashAttention-2 (Dao et al., 2023) correctly on a held-out benchmark of attention-pattern tests. The skill must:
- pass 9/10 of the held-out numerical-correctness tests (Correctness, 1.0, gate)
- the implementation runs on a single H100 GPU (Buildability, 0.7)
- median p50 latency < 80% of the PyTorch reference (Performance, 0.6)
- zero `torch.empty_like` or uninitialized memory (Safety, 1.0, gate)
- the skill is self-contained: a fresh agent can load it cold (Legibility, 0.3)

# Design-set tasks (5, the development signal)

1. `test-tasks/design/01-tile-shape/` — compute the tile shape for a given (B, H, M, N, D) tuple.
2. `test-tasks/design/02-online-softmax/` — implement the online softmax recurrence.
3. `test-tasks/design/03-block-mask/` — implement the causal block mask construction.
4. `test-tasks/design/04-rescale/` — implement the running rescale of the output accumulator.
5. `test-tasks/design/05-kernel-launch/` — implement the CUDA kernel launch grid.

# Held-out tasks (10, the test set — DO NOT READ)

`test-tasks/held-out/h01` ... `h10`. Generated from the FlashAttention-2 reference tests and the HuggingFace `transformers` test suite. The grader at `verifiers/private/grader.sh` runs the agent's candidate skill against these.

DONE
```

**What the scaffold produces:** 5 design tasks, 10 held-out
tasks, Cline wrapper, all instruments, design-set runner, held-out
grader stub. The actual test fixtures (CUDA source files,
numerical references, etc.) are user-supplied; the scaffold
emits empty `prompt.txt` + `README.md` stubs for each design
task and the user fills in the real test files.

---

## What the scaffold does NOT do

- It does not implement the design task graders. The user (or
  the fresh session running the loop) writes the actual
  `grade.sh` scripts. The scaffold writes stubs that exit 1
  with a TODO.
- It does not implement the held-out tasks. The user provides
  them. The scaffold creates empty directories with a
  `README.md` placeholder.
- It does not write the candidate skill. That's the agent's
  job during the loop.
- It does not run the loop. The loop-driver (separate skill)
  does that.

## Running the scaffold on a sample

```bash
# From any Hermes profile (no profile-specific paths):
harness-scaffold \
  --project-root <project-root> \
  --goal-prompt /path/to/this/sample.txt

# Smoke-test the output:
cd /tmp/slack-clone-go
PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh
# Expected: pass_rate=0.0 (no candidate skill yet)
cat logs/design-set-score.json
```
