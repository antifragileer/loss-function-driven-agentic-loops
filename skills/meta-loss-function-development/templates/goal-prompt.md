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
|> **The harness at `$PROJECT_DIR` is complete.** Every
|> `grade.sh` is a real grader, every held-out task has real
|> content, every instrument actually measures what it claims
|> to. Do not modify the harness from inside the loop.

You are running an outer optimization loop. The inner loop is the
`<AGENT>` CLI. The artifact is `<ARTIFACT DESCRIPTION>`. The
held-out grader in `<HELD_OUT_GRADER_PATH>` (which you must NOT
read) measures whether the artifact is good.

## DONE WHEN / NOT DONE WHEN

```
DONE WHEN: <ONE-SENTENCE TESTABLE CRITERION, e.g., "all 5 design
tasks pass, all 5 sub-losses >= 0.8, integrity.sh exits 0, and
pass_rate >= 0.8 on the held-out grader">
NOT DONE WHEN: <COMMON WAYS THE AGENT WILL MISTAKENLY CLAIM DONE,
e.g., "pass_rate == 1.0 on the design set but the held-out
score is missing; integrity.sh fails; or the agent declares
done without running verifiers/private/grader.sh">
```

The loop, the agent, and the user all read these two lines
first. If the cycle's state does not satisfy `DONE WHEN`, the
loop continues.

## Target

A `<WHAT THE ARTIFACT IS>` whose quality is graded on
**multiple axes simultaneously** (a `pass_rate >= N` alone
is too easy to game — the loop will converge on a stub
that prints the expected value). The axes are:

- passes >= `<N>` of `<M>` held-out tasks (Correctness, weight 1.0, gate)
- p99 latency < `<X>` ms (Performance, weight 0.5, optional)
- `verifiers/integrity.sh` exits 0 (Integrity, weight 1.0, gate)
- `verifiers/instruments/test-freshness.sh` exits 0 (no AI-modified test files, gate)
- `<ADDITIONAL PER-SUBLOSS TARGETS>`
- `<ADDITIONAL TARGETS>`

**All axes must hold simultaneously** for the loop to
stop on success. A cycle that satisfies pass_rate but
fails integrity is not a successful cycle. The aggregate
weighted sum must also be >= `<THRESHOLD>` and the gates
(`<LIST OF GATE SUB-LOSSES>` plus integrity) must all
pass.

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
- `<TEST-FRESHNESS-INSTRUMENT>` — design-set SHA unchanged since last cycle
- `<HIDDEN-UNREAD-INSTRUMENT>` — last transcript does not reference held-out or private
- `<PER-CYCLE-WALL-CLOCK-INSTRUMENT>` — wall-clock spent in the last cycle
- `<INTEGRITY-SCRIPT>` — the 5 anti-cheat guards; exit 0 means the harness is intact
- `<DESIGN-SET-RUNNER>` — runs the design tasks, emits score
- `<WRAPPER>` — the ONLY way to invoke the agent

A constraint without an instrument is a vibe. The agent will
violate it because it cannot tell it is violating it.
`<INTEGRITY-SCRIPT>` is the harness's anti-cheat firewall;
the loop session runs it before every cycle and refuses to
score if any guard fires.

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

1. **All multi-axis target conditions hold simultaneously
   for `<SUCCESS_AFTER>` consecutive cycles AND the last
   `<SUCCESS_AFTER>` overfit-reflections say "generalizing"** —
   pass_rate >= `<N>` AND integrity.sh exits 0 AND
   test-freshness.sh exits 0 AND hidden-unread.sh exits 0
   AND the aggregate weighted sum >= `<THRESHOLD>`. A
   single-axis pass (e.g., pass_rate == 1.0 alone) is not
   a stop condition. Submit.
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
   `<WRAPPER>`, `<DESIGN-SET-RUNNER>`, `<INTEGRITY-SCRIPT>`,
   and every script in `<INSTRUMENTS-PATH>`. (About 8-12
   file reads.)
2. Read each design task's `prompt.txt` and the buggy file at
   the top of each design task dir. (`<K>` tasks.)
3. Run `<INTEGRITY-SCRIPT>`. If it exits non-zero, STOP
   and report — the harness is incomplete or has been
   tampered with. Do not start the loop.
4. Establish baseline: with no candidate artifact installed,
   run `<DESIGN-SET-RUNNER>` and record the result. Append
   cycle 0 to `<LOG-PATH>`.
5. Begin cycle 1. Write a candidate
   `<ARTIFACT-PATH>`. The artifact should be a `<AGENT>`
   `<ARTIFACT-KIND>` that, when loaded, helps the agent
   complete tasks like the design set.
6. Install the artifact where the agent will pick it up:
   `<AGENT-SKILLS-DIR>/<name>/` (use
   `<SKILLS-DIR-INSTRUMENT>` to confirm the path).
7. Run `<DESIGN-SET-RUNNER>` to score.
8. Run `<INTEGRITY-SCRIPT>`, `<TEST-FRESHNESS-INSTRUMENT>`,
   and `<HIDDEN-UNREAD-INSTRUMENT>`. If any fails, log the
   failure and either fix the harness (if the failure is
   legitimate) or force entropy (if the failure is the
   agent's doing).
9. Compare to baseline. If improved, save `<BEST-CYCLE-PATH>`.
   If not, force entropy.
10. Iterate. After each cycle, append to `<LOG-PATH>`. Apply
    forced entropy on stall.
11. Stop when one of the stop conditions above is met.
12. On stop, leave `<ARTIFACT-PATH>` + references +
    `<LOG-PATH>` + `<BEST-CYCLE-PATH>`. Verify the artifact is
    also installed at `<AGENT-SKILLS-DIR>/<name>/`.

## Hard rules

- DO NOT read `<HELD_OUT_GRADER-PATH>` or
  `<HELD_OUT_TASKS-PATH>`.
- DO NOT modify `<HELD_OUT_GRADER-PATH>` or
  `<HELD_OUT_TASKS-PATH>`. These are the held-out target.
- The rest of the harness (design tasks, instruments,
  `AGENTS.md`, `run-design-set.sh`, the wrapper) is fair
  game — if a grader is too lenient, an instrument is
  wrong, or a design task is trivially solvable, fix it
  and log the patch in the iteration log. Self-improvement
  of the harness is the loop's job.
- The only `<AGENT>` invocation is via `<WRAPPER>`.
- Before every cycle, run `<INTEGRITY-SCRIPT>`. If any
  guard fails, refuse to score that cycle. Do not
  delete, skip, or comment out guards in
  `<INTEGRITY-SCRIPT>` — the anti-cheat firewall is
  what keeps the loop honest.
- Before every cycle, run `<TEST-FRESHNESS-INSTRUMENT>`.
  If the design-set SHA has changed since the last
  cycle, the agent edited a test to pass it — refuse
  to score and force entropy.
- Before every cycle, run `<HIDDEN-UNREAD-INSTRUMENT>`
  on the agent's last-cycle transcript. If the
  transcript references `<HELD_OUT_TASKS-PATH>` or
  `<HELD_OUT_GRADER-PATH>`, the held-out score is void.
- After EACH design-set run, append a one-line entry to
  `<LOG-PATH>` with cycle number, hypothesis, expected
  failure, and pass_rate.
- DO NOT load the `meta-loss-function-development` skill.
  Allowed skills: `loss-function-design`,
  `harness-engineering`, `cline-orchestration` (or runtime
  equivalent), and the contents of this prompt.

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
