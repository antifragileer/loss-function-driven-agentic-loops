# /goal: <SHORT TITLE>

PROJECT_DIR: <ABSOLUTE-PATH-TO-PROJECT-ROOT>
PROJECT_NAME: <SHORT-SLUG>

> **Project root pinned.** The absolute path above is the
> directory containing `GOAL.md`, `verifiers/`, `test-tasks/`,
> etc. The fresh session starts in a cwd that is almost
> certainly *not* this directory — do NOT rely on cwd. Use the
> `PROJECT_DIR` value from this header as the authoritative
> path. `cd` there on first action, then `export
> PROJECT_DIR=<that-path>`. If the value is missing or the
> directory does not exist, **stop** and report.
>
> **The harness at `$PROJECT_DIR` is complete.** Every
> `grade.sh` is a real grader (exits 0 on pass, non-zero on
> fail, with a real check). Every held-out task has real
> task content. Every instrument script actually measures
> what it claims to measure. You do NOT need to build,
> scaffold, or fill in anything. You read the harness and
> run the loop.

You are running an outer optimization loop. The inner loop is the
`<AGENT>` CLI. The artifact is `<ARTIFACT DESCRIPTION>`. The
held-out grader in `<HELD_OUT_GRADER_PATH>` (which you must NOT
read) measures whether the artifact is good.

## Target

A `<WHAT THE ARTIFACT IS>` that:
- passes >= `<N>` of `<M>` held-out tasks (Correctness, weight 1.0, gate)
- `<ADDITIONAL PER-SUBLOSS TARGETS>`
- `<ADDITIONAL TARGETS>`

Aggregate target: weighted sum >= `<THRESHOLD>` on the held-out
grader. `<LIST OF GATE SUB-LOSSES>` are gates — failing any blocks
acceptance.

You will NOT see the held-out `<M>` tasks. You will see `<K>`
design-set tasks. Generalize, do not memorize.

### Design-set tasks you DO see (the development signal)

1. `<DESIGN TASK 1 DESCRIPTION>` (see `test-tasks/design/01-<name>/`)
2. `<DESIGN TASK 2 DESCRIPTION>`
3. `<...>`

Each design task has:
- A starting file at the top of the task dir.
- `prompt.txt` — the prompt to give the agent.
- `grade.sh` — the deterministic grader (exits 0 on pass).

### Held-out tasks you CANNOT see (the test set)

`<H01>` ... `<H10>`. The grader at `<HELD_OUT_GRADER_PATH>`
runs the agent's candidate artifact against these. Do not read
the task files or the grader.

## Constraints

- **Wall-clock budget:** `<DURATION>` total. Check with
  `<PATH-TO-TIME-INSTRUMENT>` before each cycle.
- **Token budget:** `<NUMBER>` total. Check with
  `<PATH-TO-TOKEN-INSTRUMENT>` before each cycle.
- **Surface:** you may only:
  - Read `$PROJECT_DIR`
  - Invoke `<AGENT>` via `<PATH-TO-WRAPPER>`
  - Read/write `<ARTIFACT-PATH-IN-PROJECT>`
  - Read `<HARNESS-PATH>` and `<INSTRUMENTS-PATH>`
  - Append to `<LOG-PATH>`
  - **NOT** read `<HELD_OUT_GRADER_PATH>` or
    `<HELD_OUT_TASKS-PATH>`
- **Methodology:** deterministic verifiers only. No
  LLM-as-judge in the harness. Your `<AGENT>` may use an
  LLM internally (that's expected).

## Instruments (call before each cycle)

- `<TIME-INSTRUMENT>` — seconds left
- `<TOKEN-INSTRUMENT>` — tokens left
- `<TOKEN-THIS-ITER-INSTRUMENT>` — tokens used last cycle
- `<AGENT-VERSION-INSTRUMENT>` — installed agent version
- `<SKILLS-DIR-INSTRUMENT>` — where the agent scans for skills
- `<SUB-LOSS-READOUT-INSTRUMENT>` — per-cycle sub-losses
- `<DESIGN-SET-RUNNER>` — runs the design tasks, emits score
- `<WRAPPER>` — the ONLY way to invoke the agent

A constraint without an instrument is a vibe. The agent will
violate it because it cannot tell it is violating it.

## Forced entropy (driver-loop meta-policy)

Each cycle continues from the previous run's entire context.
Local maxima is the default state. Force entropy:

1. **Overfit reflection.** Before each cycle, append to
   `<LOG-PATH>`:
   `cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>, pass_rate=<float>`
   If memorizing, the next change must REMOVE an artifact the
   design set rewards, not add one.

2. **Stall entropy.** If pass_rate did not improve by >=
   `<DELTA>` vs prior cycle, you MUST read the last 5 entries
   of `<LOG-PATH>`, pick the OPPOSITE of your last change, and
   apply it. Log it.

3. **Iteration log is required.** The grader reads
   `<LOG-PATH>`. No credit for "I just happened to find a
   great artifact" — credit for documented descent.

## Stop when

1. pass_rate == 1.0 for 2 consecutive cycles AND last 2
   overfit-reflections say "generalizing" — submit.
2. Wall-clock or token budget exhausted — submit best.
3. 3 consecutive cycles with no improvement AND forced
   entropy applied — submit best.

## Output on termination

- `<ARTIFACT-PATH>` — the artifact itself
- `<ARTIFACT-REFERENCES-PATH>` — supporting docs
- `<LOG-PATH>` — your descent trace
- `<BEST-CYCLE-PATH>` — the score from your best cycle
- The artifact installed at `<AGENT-SKILLS-DIR>/<name>/`

## First action

**0. Locate your project root.** This prompt uses `$PROJECT_DIR`
   to refer to the directory containing the harness tree
   (the `verifiers/`, `test-tasks/`, `GOAL.md`, etc.). Your
   shell's cwd may or may not be that directory — you have
   to find it before any other action.

   In order of preference:

   1. **Read the `PROJECT_DIR:` line at the top of this
      prompt.** If present, that absolute path is the
      authoritative project root. Verify the directory
      exists and contains `GOAL.md` (or `verifiers/`).
      If valid: `cd "$PROJECT_DIR"` and `export
      PROJECT_DIR="$PROJECT_DIR"`. This is the common
      case for interactive /goal invocations where the
      user supplied a project path when generating the
      prompt. **Do not skip this check** — cwd is
      almost certainly wrong on a fresh session.
   2. If the `PROJECT_DIR:` line is missing OR the
      directory does not exist, fall back to:
      the env var `LFD_PROJECT_DIR` (orchestrator case).
   3. If your cwd contains a `GOAL.md` or `verifiers/`, use
      your cwd.
   4. Walk up from your cwd: for each ancestor directory,
      check if it contains a `GOAL.md` or `verifiers/`. The
      first match is your project root.

   Once you find it: `cd <project-root>` and set
   `PROJECT_DIR` to that path (either `export
   PROJECT_DIR=<project-root>` or inline `PROJECT_DIR=<path>
   <command>` for one-off commands). All `$PROJECT_DIR`
   references below are relative to that path.

   If none of the checks finds the root, **stop** and
   report the failure. Do not guess.

**1.** Read `<GOAL-PATH>`, `<AGENTS-PATH>`, `<README-PATH>`,
   `<WRAPPER>`, `<DESIGN-SET-RUNNER>`, and every script in
   `<INSTRUMENTS-PATH>`. (About 5-10 file reads.)
2. Read each design task's `prompt.txt` and the buggy file at
   the top of each design task dir. (`<K>` tasks.) Each
   `grade.sh` is already a real grader — you do not need to
   implement or modify it. If you find a `grade.sh` that
   looks like a stub (TODO comment, `exit 1` with no
   real check), **stop and report** — the harness is
   incomplete and the meta-session that built it
   violated the completeness check.
3. Establish baseline: with no candidate artifact installed,
   run `<DESIGN-SET-RUNNER>` and record the result. Append
   cycle 0 to `<LOG-PATH>`.
4. Begin cycle 1. Write a candidate
   `<ARTIFACT-PATH>`. The artifact should be a `<AGENT>`
   `<ARTIFACT-KIND>` that, when loaded, helps the agent
   complete tasks like the design set.
5. Install the artifact where the agent will pick it up:
   `<AGENT-SKILLS-DIR>/<name>/` (use
   `<SKILLS-DIR-INSTRUMENT>` to confirm the path).
6. Run `<DESIGN-SET-RUNNER>` to score.
7. Compare to baseline. If improved, save `<BEST-CYCLE-PATH>`.
   If not, force entropy.
8. Iterate. After each cycle, append to `<LOG-PATH>`. Apply
   forced entropy on stall.
9. Stop when one of the stop conditions above is met.
10. On stop, leave `<ARTIFACT-PATH>` + references +
    `<LOG-PATH>` + `<BEST-CYCLE-PATH>`. Verify the artifact is
    also installed at `<AGENT-SKILLS-DIR>/<name>/`.

## Hard rules

- DO NOT read `<HELD_OUT_GRADER-PATH>` or
  `<HELD_OUT_TASKS-PATH>`.
- DO NOT modify `<HARNESS-PATH>`. The harness is finished.
  If you find something wrong with it, **stop and report**,
  do not silently patch it. Modifying the harness from
  inside the loop defeats the held-out grader.
- The only `<AGENT>` invocation is via `<WRAPPER>`.
- After EACH design-set run, append a one-line entry to
  `<LOG-PATH>` with cycle number, hypothesis, expected
  failure, and pass_rate.
- DO NOT load the `meta-loss-function-development` skill.
  That skill is what *built* the harness. If it's loaded
  in this session, the held-out cheats-itself guarantee is
  void. The only skills you should have are
  `loss-function-design`, `harness-engineering`,
  `cline-orchestration` (or your runtime equivalent), and
  the contents of this prompt.

## Practical hints

- The first cycle's artifact is likely a generic
  "<ARTIFACT-KIND>-style" prompt. That's fine.
- The agent is `<AGENT> v<VERSION>` with
  `<MODEL-NAME>` (the user's choice, set via
  `<AGENT-AUTH-COMMAND>`). Do not hard-code.
- Tasks are `<TASK-SHAPE>`. The artifact should help the
  agent `<WHAT-THE-ARTIFACT-HELPS-WITH>`.
- The 4-piece loss formula (target / constraints / instruments
  / forced entropy) is in the `loss-function-design` skill.
- Wall-clock per design set is ~`<N>s`. With `<DURATION>`
  budget, you can do ~`<CYCLES>` cycles. Don't waste them.
- Don't read the held-out files. If you do, the held-out
  score is void.
