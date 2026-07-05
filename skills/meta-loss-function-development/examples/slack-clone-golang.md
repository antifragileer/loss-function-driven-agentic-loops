> **Worked example. Assumes the harness is already
> complete** (every `grade.sh` is a real grader, every
> held-out task has real content, every instrument is
> real). This is the prompt the meta-skill emits at the
> end of rounds 0-6, after the user has signed off via
> `references/harness-completeness-checklist.md`. Do not
> paste this into a fresh session until the harness at
> `PROJECT_DIR` is finished.

# /goal: Build a Slack Desktop Clone in Go

PROJECT_DIR: <ABSOLUTE-PATH-TO-PROJECT-ROOT>
PROJECT_NAME: slack-clone

> **Project root pinned.** The absolute path above is the
> directory containing `GOAL.md`, `verifiers/`, `test-tasks/`,
> etc. The fresh session starts in a cwd that is almost
> certainly *not* this directory — do NOT rely on cwd. Use the
> `PROJECT_DIR` value from this header as the authoritative
> path. `cd` there on first action, then `export
> PROJECT_DIR=<that-path>`. If the value is missing or the
> directory does not exist, **stop** and report.

You are running an outer optimization loop. The inner loop is the
`cline` CLI. The artifact is a Cline skill (SKILL.md + references)
that drives Cline on Slack-clone coding tasks. The held-out grader
in `verifiers/private/grader.sh` (which you must NOT read) measures
whether the skill produces a Go binary that behaves like the
public Slack web/desktop client on a held-out task set.

## Target

A Cline skill that, when loaded, helps Cline build a working
Go binary that mirrors the Slack desktop client's *visible
behavior* on a held-out task set of 10 unseen feature requests.
The skill must:
- pass >= 8/10 held-out tasks (Correctness, weight 1.0, gate)
- the produced binary builds with `go build` on a clean checkout
  (Buildability, weight 0.7, gate)
- median p50 task completion < 180 s wall-clock (Performance, 0.5)
- zero destructive commands in any transcript (Safety, 1.0, gate)
- a fresh agent can load the skill cold and execute it
  (Legibility, 0.3)
- skill follows Cline's SKILL.md frontmatter contract exactly
  (Invariants, 1.0, gate)
- skill degrades gracefully on Cline version mismatch (Drift, 0.2)
- median token spend per task < 8k tokens (Cost, 0.3)

Aggregate target: weighted sum >= 0.85. Correctness,
Buildability, Safety, and Invariants are gates.

You will NOT see the held-out 10 tasks. You will see 5 design
tasks. Generalize, do not memorize.

### Design-set tasks you DO see (the development signal)

1. `test-tasks/design/01-send-message/` — implement a function
   that takes a channel name and message string, posts the
   message, returns the message ID.
2. `test-tasks/design/02-list-channels/` — implement a function
   that returns the list of channels the current user belongs
   to, as a `[]Channel{ID, Name}`.
3. `test-tasks/design/03-react-emoji/` — add a `:fire:` (or
   similar) reaction to a given message ID; return the
   reaction count after.
4. `test-tasks/design/04-thread-reply/` — given a parent
   message ID and a reply string, post the reply as a
   threaded reply; return the thread root ID.
5. `test-tasks/design/05-mark-read/` — mark a channel as read
   for the current user up to a given message ID.

Each task has a `prompt.txt` (the prompt to give Cline) and a
`grade.sh` (deterministic grader, exits 0 on pass). Tasks are
scored by `go build` + `go test` against a mock Slack server
that the harness spins up per task.

### Held-out tasks you CANNOT see (the test set)

`test-tasks/held-out/h01` ... `h10`. Generated from the public
Slack web client API docs (https://api.slack.com/web) and
public webhooks. The grader at
`verifiers/private/grader.sh` runs the agent's candidate
artifact against these. **Do not read the task files or
the grader.** Reading them voids the held-out score.

## Constraints

- **Wall-clock budget:** 8 h total. Check with
  `verifiers/instruments/time-remaining.sh` before each cycle.
- **Token budget:** 1,000,000 tokens total. Check with
  `verifiers/instruments/tokens-remaining.sh` before each cycle.
- **Surface:** you may only:
  - Read `$PROJECT_DIR`
  - Invoke Cline via `verifiers/cline-wrapper.sh`
  - Read/write `skills/slack-clone-driver/`
  - Read `verifiers/` and `verifiers/instruments/`
  - Append to `logs/`
  - **NOT** read `verifiers/private/` or
    `test-tasks/held-out/`
- **Methodology:** deterministic verifiers only. No
  LLM-as-judge in the harness. The harness uses a mock Slack
  server, real `go test` runs, and a real `go build` — all
  deterministic.

## Instruments (call before each cycle)

- `verifiers/instruments/time-remaining.sh` — seconds left
- `verifiers/instruments/tokens-remaining.sh` — tokens left
- `verifiers/instruments/tokens-this-iter.sh` — tokens last
  cycle
- `verifiers/instruments/cline-version.sh` — installed Cline
- `verifiers/instruments/cline-skills-dir.sh` — where Cline
  scans for skills
- `verifiers/instruments/sub-loss-readout.sh <cycle-N.json>` —
  per-cycle sub-losses
- `verifiers/run-design-set.sh` — runs the 5 design tasks,
  emits `logs/design-set-score.json`
- `verifiers/cline-wrapper.sh` — the ONLY way to invoke Cline

A constraint without an instrument is a vibe.

## Forced entropy (driver-loop meta-policy)

Each cycle continues from the previous run's entire context.
Local maxima is the default state. Force entropy:

1. **Overfit reflection.** Before each cycle, append to
   `logs/iteration-log.md`:
   `cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>, pass_rate=<float>`
   If memorizing, the next change must REMOVE an artifact the
   design set rewards, not add one.

2. **Stall entropy.** If pass_rate did not improve by >=
   0.05 vs prior cycle, you MUST read the last 5 entries of
   `logs/iteration-log.md`, pick the OPPOSITE of your last
   change, and apply it. Log it.

3. **Iteration log is required.** No credit for luck.

## Stop when

1. pass_rate == 1.0 for 2 consecutive cycles AND last 2
   overfit-reflections say "generalizing" — submit.
2. Wall-clock or token budget exhausted — submit best.
3. 3 consecutive cycles with no improvement AND forced
   entropy applied — submit best.

## Output on termination

- `skills/slack-clone-driver/SKILL.md` — the skill
- `skills/slack-clone-driver/references/*.md` — supporting docs
- `logs/iteration-log.md` — your descent trace
- `logs/best-cycle.json` — the score from your best cycle
- The skill installed at `~/.cline/skills/slack-clone-driver/SKILL.md`

## First action

0. **Locate your project root.** This prompt uses `$PROJECT_DIR` to refer to the directory containing the harness tree (the `verifiers/`, `test-tasks/`, `GOAL.md`, etc.). Your shell's cwd may or may not be that directory — you have to find it before any other action. In order of preference: (1) if the env var `LFD_PROJECT_DIR` is set and that directory contains a `GOAL.md` or `verifiers/`, use it; (2) if your cwd contains a `GOAL.md` or `verifiers/`, use your cwd; (3) walk up from your cwd: for each ancestor directory, check if it contains a `GOAL.md` or `verifiers/`, the first match is your project root. Once you find it: `cd <project-root>` and set `PROJECT_DIR` to that path. All `$PROJECT_DIR` references in this prompt are relative to that path. If none of the three checks finds the root, **stop** and report the failure. Do not guess.

1. Read `GOAL.md`, `AGENTS.md`, `README.md`,
   `verifiers/cline-wrapper.sh`, `verifiers/run-design-set.sh`,
   and every script in `verifiers/instruments/`. (About 5-10
   file reads.)
2. Read each design task's `prompt.txt` and the starting file
   at the top of each design task dir. (5 tasks.)
3. Establish baseline: with no candidate skill installed,
   run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh`
   and record the result. Append cycle 0 to
   `logs/iteration-log.md`.
4. Begin cycle 1. Write a candidate
   `skills/slack-clone-driver/SKILL.md` (and references if
   needed).
5. Install the skill at
   `~/.cline/skills/slack-clone-driver/SKILL.md` (use
   `verifiers/instruments/cline-skills-dir.sh` to confirm the
   path).
6. Run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh` to
   score.
7. Compare to baseline. If improved, save
   `logs/best-cycle.json`. If not, force entropy.
8. Iterate. After each cycle, append to `logs/iteration-log.md`.
   Apply forced entropy on stall.
9. Stop when one of the stop conditions above is met.
10. On stop, leave `skills/slack-clone-driver/SKILL.md` +
    references + `logs/iteration-log.md` +
    `logs/best-cycle.json`. Verify the skill is also installed
    at `~/.cline/skills/slack-clone-driver/SKILL.md`.

## Hard rules

- DO NOT read `verifiers/private/` or `test-tasks/held-out/`.
- DO NOT modify `verifiers/`. The harness is finished. If
  you find something wrong with it, **stop and report**,
  do not silently patch it. Modifying the harness from
  inside the loop defeats the held-out grader.
- The only Cline invocation is via `verifiers/cline-wrapper.sh`.
- After EACH design-set run, append a one-line entry to
  `logs/iteration-log.md` with cycle number, hypothesis,
  expected failure, and pass_rate.
- If pass_rate doesn't improve by >= 0.05, force entropy:
  pick the OPPOSITE of your last change and apply it.
  Document it.
- DO NOT load the `meta-loss-function-development` skill
  in this session. That skill is what built the harness
  in the first place — its context contains the held-out
  synthesis. Loading it here would void the held-out
  guarantee. The only skills in this session should be
  `loss-function-design`, `harness-engineering`,
  `cline-orchestration`, and the contents of this prompt.

## Practical hints

- The Slack web API has good docs at
  https://api.slack.com/web. Use the public surface, not
  internal client code.
- The mock Slack server in `verifiers/mock-slack/` is a
  minimal Go server. `go test ./...` against it is the
  harness.
- The first cycle's skill is likely a generic
  "build a Go Slack clone" prompt. That's fine.
- Cline v3.0.34+ with whatever model the user picked (default
  whatever model the user has authenticated). Do not switch the model.
- Wall-clock per design set is ~75-180 s. With 8 h budget,
  you can do ~150-300 cycles. Don't waste them.
- The 3-cheats pattern from the @elvissun article is exactly
  what you're guarding against: don't reward-hack the
  design set. The held-out grader will catch it.
- Tasks are small Go function bodies — one bug per task,
  the bug is the obvious one (off-by-one, wrong constant,
  reversed branch, etc.). The skill should help Cline
  spot the bug, propose a minimal fix, verify with
  `go test`.
