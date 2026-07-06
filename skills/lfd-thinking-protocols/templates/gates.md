# The 10 Thinking-Protocol Gates

One page per gate. The user fills in the template
inline. The skill writes the answer to
`$PROJECT_DIR/handoffs/NN-<gate-name>.md` and the
meta-skill's next round reads that file.

The frameworks each gate references (the 2x2, the
Socratic 5-Q, the 4-piece anatomy, the 20/80 rule,
the wiggle-room and right-generalization patterns,
the 4-layer anti-cheat defense, the stuck-loop
playbook) are inlined in `references/frameworks.md`
in this skill. Each gate's "Source framework" line
points at the relevant section.

---

## Gate 1: clarify-target

**Handoff file:** `handoffs/01-target.md`
**Read by:** meta-skill Round 1, loop-driver
  stop-conditions parser, `verifiers/integrity.sh`.
**Source framework:** `references/frameworks.md` §1
  (the 2x2 of preferences) and §3 (the 5-Q Socratic
  template).

### What the user is committing to

A one-sentence target that is **specific enough to
measure** and **categorized in the 2x2**. The
target is the input to the meta-skill's Round 1
(4-piece spec). The loop driver's stop-condition
parser reads the multi-axis threshold from this
file's last section.

### The template

```markdown
# 01 — Target

## One-sentence target

<one sentence: the artifact, the constraint, the
quality bar>

## 2x2 placement

| | Strategic (firm) | Tactical (project) |
|---|---|---|
| Imperative (path) | <what the firm decides for me> | <what this project decides> |
| Declarative (outcome) | <what success looks like, firm-level> | <what success looks like, for this project> |

## 5-Q Socratic discovery

1. The 3 assumptions in this target that, if wrong,
   would break the visible test:
   a. <assumption>
   b. <assumption>
   c. <assumption>
2. Cheapest negative check for each:
   a. <grep / exit-code / shape match>
   b. <grep / exit-code / shape match>
   c. <grep / exit-code / shape match>
3. Which assumptions are firm-level (every project)
   vs project-level (only this one)?
   a. <F or P>
   b. <F or P>
   c. <F or P>
4. Of the firm-level ones, which deserve a held-out
   task?
   <list>
5. Of the project-level ones, which belong in
   AGENTS.md as a hard rule vs in the per-task
   prompt.txt as a description?
   <list>

## Multi-axis threshold (for loop-driver)

pass_rate >= <float> on <N> design tasks
AND
weighted_sum >= <float>
AND
verifiers/integrity.sh exits 0
AND
verifiers/instruments/test-freshness.sh exits 0
AND
verifiers/instruments/hidden-unread.sh exits 0
AND
<additional axes>
```

### What "complete" looks like

- All 5 cells of the 2x2 have a non-empty answer.
- The 5-Q template has at least 3 assumptions listed.
- The multi-axis threshold has at least 4 axes (the
  3 anti-cheat axes are non-negotiable per
  `loop-driver/SKILL.md` lines 119-126; the user may
  add more).
- The one-sentence target does not contain the words
  "good", "clean", or "works" without a
  measurement.

### Common defaults (user can accept)

- Multi-axis threshold: `pass_rate >= 0.8` and
  `weighted_sum >= 0.85` and the 3 anti-cheat axes.
  This is the meta-skill's Round-1 default per
  `meta-loss-function-development/SKILL.md` lines
  165-167 and `loop-driver/SKILL.md` lines 113-115.
 - Firm-level assumptions: 1-3 anti-cheat guards
 beyond the 4 default scaffold guards (the 4
 defaults are listed in the section "Default
 guard set" of this gate's body).

---

## Gate 2: shape-loss

**Handoff file:** `handoffs/02-loss-shape.md`
**Read by:** meta-skill Round 1, `verifiers/compute_sub_losses.py`
  at loop time, `score-cycle.py`.
**Source framework:** `loss-function-design/SKILL.md`
  lines 50-101 (4-piece anatomy); §"Decompose" (the
  7 sub-loss table).

### What the user is committing to

The 4-piece loss spec (target, constraints,
instruments, forced entropy) and the 7-sub-loss
decomposition. The 4 pieces go into the `/goal`
prompt; the 7 sub-losses go into
`verifiers/compute_sub_losses.py`.

### The template

```markdown
# 02 — Loss shape

## Target (multi-axis, from Gate 1)

<reproduce Gate 1's multi-axis threshold>

## Constraints

- Wall-clock budget: <duration>
- Token budget: <number>
- Surface (read): <list of paths>
- Surface (write): <list of paths>
- Surface (forbidden): <list, including
  verifiers/private/ and test-tasks/held-out/>
- Methodology: <deterministic / llm-judge / both>

## Instruments (one per constraint)

- time-remaining.sh reads <file or API>
- tokens-remaining.sh reads <file or API>
- per-cycle-wall-clock.sh writes to <path>
- <constraint N> is measured by <instrument N>:
  reads <file>, returns <signal>

## Forced entropy

- Overfit-reflection threshold: <delta>
- Stall-entropy cap: <N consecutive no-improvement>
- Log format: <verbatim from loop-driver>

## 7-sub-loss decomposition (for compute_sub_losses.py)

| Sub-loss | Weight | Gate? | Signal source |
|---|---|---|---|
| Correctness | <w> | yes | <test suite path> |
| Performance | <w> | no | <benchmark path> |
| Safety | <w> | yes | <sast / secret-scan> |
| Legibility | <w> | no | <doc-coverage linter> |
| Invariants | <w> | yes | <layer-dep linter> |
| Golden-principle | <w> | no | <custom linter> |
| Drift | <w> | no | <diff-vs-baseline> |

Weights sum to 1.0. At least 3 sub-losses are
gates. The 3 gate sub-losses (correctness, safety,
invariants) are the loop's hard stops.

## Reference for the weighted sum

weighted_sum = sum(weight[i] * sub_loss[i])

weighted_sum >= <THRESHOLD> is one of the multi-axis
stop conditions. Default 0.85.
```

### What "complete" looks like

- All 4 pieces of the loss spec are filled in.
- All 7 sub-losses have a weight, a gate flag, and a
  signal source.
- The constraint list has at least one item
  *forbidden*: `verifiers/private/` and
  `test-tasks/held-out/` are non-negotiable per
  `meta-loss-function-development/SKILL.md` line 251.

### Common defaults

- Sub-loss weights: `correctness=0.40,
  performance=0.10, safety=0.15, legibility=0.05,
  invariants=0.15, golden-principle=0.10,
  drift=0.05`. This is the LFD system verifier's
  default per `examples/lfd-system-verifier/`.
- Gate sub-losses: correctness, safety, invariants.
- Wall-clock budget: 1h for a 1-cycle
  proof-of-concept, 6h for a real run
  (OpenAI's norm per `harness-engineering/SKILL.md`
  line 117).

---

## Gate 3: design-verifier

**Handoff file:** `handoffs/03-verifier-spec.md`
  plus per-task `test-tasks/<id>/grade.sh`.
**Read by:** meta-skill Round 2, `verifiers/integrity.sh`
  Layer-1 guards, the held-out grader.
**Source framework:**
  `loss-function-design/SKILL.md` lines 178-205 (the
  7-hack × 7-defense table); `references/frameworks.md`
  §7 (the 4-layer defense and 3-cheats story);
  the 4 default anti-cheat guards in
  `verifiers/integrity.sh`.

### What the user is committing to

For each design task, a `grade.sh` that:
1. Returns 0 on real pass, non-zero on real fail.
2. Has at least one **negative check** (asserts a
   behavior the agent must NOT do).
3. Runs in < 60s.
4. Is runnable standalone from inside the task dir.

### The template (per design task)

```markdown
# 03 — Verifier spec for <NN-task-name>

## Task summary

<one-sentence description of what the task tests>

## Positive checks

- <check 1>: <command> → exit 0
- <check 2>: <command> → exit 0

## Negative checks (at least one)

- <check 1>: <command> → must exit 1
  Rationale: <what cheat this catches>
- <check 2>: <command> → must exit 1
  Rationale: <what cheat this catches>

## Reward-hack map

| Hack | Caught by | Defense in grade.sh? |
|---|---|---|
| Agent deletes the test | Layer 4 (test-freshness) | <yes/no> |
| Agent adds `sleep` | Layer 1 (no-sleep-in-grader) | <yes/no> |
| Agent returns a stub | <layer> | <yes/no> |
| <hack specific to this task> | <layer> | <yes/no> |

## Run-time

- Wall-clock per grade.sh: <seconds>
- Determinism: <deterministic / stochastic(seed) /
  llm_judge(model, prompt, temp)>
- Required files: <list>
```

### What "complete" looks like

- At least one negative check per task.
- The reward-hack map is filled in for at least 3
  rows.
- The `grade.sh` exits 0 on a known-good candidate
  and non-zero on a known-bad candidate. The user
  proves this by running `grade.sh` against a
  hand-rolled bad candidate before signing off.

### Common defaults

- Negative-check pattern: `grep -v <forbidden>`
  followed by a `[[ -z "$OUTPUT" ]]` check. The
  `d1-parse-cline-output/grade.sh` in
  `examples/lfd-system-verifier/` is the
  worked example: `grep -qE
  'eval.*input|exec.*input|subprocess.call.*shell=True'`
  (the same pattern is in `references/frameworks.md`
  §1's worked example).
- Determinism: `deterministic` for the design set.
  Held-out tasks may use `stochastic(seed=42)` if
  the test genuinely requires randomness; this is
  the meta-skill's Round-3 default.

---

## Gate 4: shape-context

**Handoff file:** `handoffs/04-context-shape.md` plus
  `AGENTS.md` plus per-task `test-tasks/<id>/prompt.txt`.
**Read by:** the inner agent (every cycle), the
  loop driver, the user.
**Source framework:** `harness-engineering/SKILL.md`
  (AGENTS.md as a TOC); `references/frameworks.md` §4
  (wiggle room) and §5 (right generalization).

### What the user is committing to

`AGENTS.md` in their own voice (not the scaffold's
default) and per-task `prompt.txt` files that use
the wiggle-room and right-generalization patterns.

### The template

```markdown
# 04 — Context shape

## AGENTS.md voice (in your own words)

<AGENTS.md content; max 100 lines; 3-5 hard rules;
3-5 "go look at X first" links; project-specific
to this project, not generic>

## Per-task prompt.txt patterns

For each design task, the prompt.txt:

### <NN-task-name>

```
<full prompt.txt content>
```

Patterns used:
- Wiggle room: <where in the prompt>
- Right generalization: <where in the prompt>
- Negative instruction: <where in the prompt>

## Anti-pollution check

For each prompt.txt, list any phrase that references
a future project or a specific implementation that
the agent is not yet allowed to consider. Replace
with the general shape of the connection per
`references/frameworks.md` §5 (right
generalization).
```

### What "complete" looks like

- `AGENTS.md` is < 100 lines.
- `AGENTS.md` has at least 3 hard rules in
  imperative strategic voice (per
  `references/frameworks.md` §1, the 2x2 of
  preferences).
- Every per-task `prompt.txt` has at least one
  wiggle-room clause.
- The anti-pollution check has at least 1 entry per
  prompt.txt.

### Common defaults

- AGENTS.md structure: 2-sentence project
  description, 3-5 hard rules, the iteration log
  format, the integrity-script rule, the
  held-out/private surfaces as forbidden. The
  LFD system verifier's
  `examples/lfd-system-verifier/AGENTS.md` is the
  worked example.
- Wiggle-room pattern: "If you discover a design
  that achieves the objectives in DONE WHEN better
  than <approach A>, raise it as an option in your
  iteration-log.md entry before proceeding. Do not
  implement the alternative without surfacing it."
  (the pattern is in `references/frameworks.md` §4,
  wiggle room).

---

## Gate 5: design-tools

**Handoff file:** `handoffs/05-tools-inventory.md`
  plus `verifiers/instruments/*.sh`.
**Read by:** the loop driver (every cycle), the
  inner agent (when invoking an instrument),
  `verifiers/integrity.sh`.
**Source framework:** `harness-scaffold/SKILL.md`
  lines 1-37 (33-instrument taxonomy); the V0->V1
  instrument catalog in
  `harness-scaffold/references/v0v1-instrument-taxonomy.md`.

### What the user is committing to

For each constraint in Gate 2, a CLI command
`verifiers/instruments/<name>.sh` that:
1. Actually reads a real file / API / log (not
   `echo "100"`).
2. Returns a real number.
3. Fails loudly (non-zero exit) on its own internal
   error.
4. Does NOT fail on a constraint violation —
   constraint violations are the loop's job.

### The template

```markdown
# 05 — Tools inventory

## Per-constraint instruments

| Constraint (from Gate 2) | Instrument path | Real measurement |
|---|---|---|
| <constraint> | <path> | <what it reads/queries> |

## Default guard set (4 anti-cheat guards)

The 4 default guards in `verifiers/integrity.sh` are
non-negotiable. They are listed in
`references/frameworks.md` §7 (4-layer defense):

1. `no-grade-todo-stub`
2. `no-stub-always-pass`
3. `no-sleep-in-grader`
4. `agents-md-has-hard-rules`

## Project-specific guards (1-3)

For each project-specific reward hack, add a guard:

1. <cheat>: <guard name>
   check_<guard>() { <3-5 line bash> }
2. <cheat>: <guard name>
   check_<guard>() { <3-5 line bash> }
3. <cheat>: <guard name>
   check_<guard>() { <3-5 line bash> }

Reference: `references/frameworks.md` §7 (the
cheat-to-layer mapping). The common project-specific
guards are:
`no-secret-ignore-edit`, `no-deps-lockfile-removed`,
`perf-endpoint-real`, `parser-shape-across-adapters`.

## The 5 real (non-stub) V0->V1 instruments

These ship filled-in (not stubs):

1. `time-remaining.sh` — wall-clock budget tracker
2. `tokens-remaining.sh` — token budget tracker
3. `tokens-this-iter.sh` — per-cycle tokens
4. `per-cycle-wall-clock.sh` — per-cycle wall-clock
5. `smallness.sh` — LOC reward (the one real reward)

Plus the 3 anti-cheat instruments:

6. `test-freshness.sh` — design-set SHA unchanged
7. `hidden-unread.sh` — transcript does not
   reference held-out/private
8. `sub-loss-readout.sh` — per-cycle sub-losses

## 27 stub instruments (HITL-fill, opt-in)

The user picks which of the 27 stubs apply. Each
stub has a 3-5 line HITL section. Stubs the user
does not fill stay as 0.0 (not configured).

## Reference

- `harness-scaffold/SKILL.md` lines 1-37 (the
  full 33-instrument taxonomy)
- `harness-scaffold/references/v0v1-instrument-taxonomy.md`
  (the V0->V1 catalog with tool hints)
```

### What "complete" looks like

- The per-constraint instruments table has an entry
  for every constraint in Gate 2.
- The project-specific guards list has at least 1
  entry (the 4 defaults plus 1 project-specific is
  the minimum; see the "Default guard set" section
  in this gate's body for the rationale).
- Every instrument path listed actually exists in
  `verifiers/instruments/` and is runnable.

### Common defaults

- 4 default guards: as listed in the "Default
  guard set" section of this gate's body.
- 1-3 project-specific guards: pick from the
  cheat-to-layer mapping in
  `references/frameworks.md` §7.
- The 27 stubs stay as 0.0 unless the user wants
  the corresponding sub-loss to be a real signal.
  This is the meta-skill's Round-4 default.

---

## Gate 6: wire-loop

**Handoff file:** `handoffs/06-loop-shape.md`
**Read by:** `loop-driver/scripts/cycle.sh`,
  the inner agent.
**Source framework:** `loop-driver/SKILL.md` lines
  27-78 (the 10-step cycle diagram); lines 86-100
  (the cycle contract table).

### What the user is committing to

The shape of one cycle: which artifacts the cycle
emits, where they live, what the loop driver reads.

### The template

```markdown
# 06 — Loop shape

## One cycle (10 steps, verbatim from loop-driver)

1. Read iteration log
2. Form hypothesis (next change)
3. Write candidate artifact
4. Install artifact for agent
5. Run design set (verifiers)
6. Score (weighted sum + gates)
7. Append to iteration log
8. Update best-cycle if improved
9. Apply forced entropy on stall
10. Check stop conditions

## Per-cycle artifacts (the cycle contract)

| Artifact | Path | Purpose |
|---|---|---|
| Cycle input | <path> | What the loop saw going in |
| Wrapper output | <path> | The wrapper's NDJSON summary |
| Sub-losses | <path> | The 7 sub-losses + weighted sum |
| Iteration log entry | <path> | One-line per cycle |
| Best-cycle score | <path> | Updated if improved |

## Inner agent invocation

- Wrapper: <path>
- The agent is invoked ONLY via the wrapper.
- Per-iteration isolation: <git worktree / fresh
  dir / profile-based>

## Stop conditions (multi-axis)

The 4 stop conditions from `loop-driver/SKILL.md`
lines 153-160:

1. All multi-axis target conditions hold for
   `<SUCCESS_AFTER>` consecutive cycles AND the
   last `<SUCCESS_AFTER>` overfit-reflections say
   "generalizing".
2. Wall-clock budget exhausted.
3. Token budget exhausted.
4. 3 consecutive cycles with no improvement AND
   forced entropy applied.
```

### What "complete" looks like

- All 10 cycle steps are present.
- The cycle contract table has all 5 artifact paths
  filled in.
- The stop conditions list matches Gate 1's
  multi-axis threshold.

### Common defaults

- Per-iteration isolation: `git worktree add` (the
  Elvis pattern from
  `harness-engineering/SKILL.md` lines 60-67).
- SUCCESS_AFTER: 2 (the loop-driver default per
  `loop-driver/SKILL.md` line 155).
- Max stall: 3 (the loop-driver default per
  `loop-driver/SKILL.md` line 212).

---

## Gate 7: set-rails

**Handoff file:** `handoffs/07-rails.md` plus
  `verifiers/integrity.sh`.
**Read by:** `verifiers/integrity.sh` (every cycle,
  before scoring); the held-out grader.
**Source framework:** `references/frameworks.md`
  §7 (the 4-layer defense model and the cheat-to-layer
  mapping); the 4 default anti-cheat guards in
  `verifiers/integrity.sh`.

### What the user is committing to

Which layer (1-4) catches which cheat, and which
guards are added to `verifiers/integrity.sh`.

### The template

```markdown
# 07 — Rails

## The 4-layer defense

| Layer | Mechanism | Runs when | Catches |
|---|---|---|---|
| 1. Integrity | `verifiers/integrity.sh` | Before each cycle | Harness edits (grade.sh stubs, sleep, rules-file tampering) |
| 2. Held-out grader | `verifiers/private/grader.sh` | After the loop | Visible-test workarounds the visible test can't see |
| 3. Hidden-unread | `verifiers/instruments/hidden-unread.sh` | After each cycle | Agent *reading* the exam during the run |
| 4. Test-freshness | `verifiers/instruments/test-freshness.sh` | Before each cycle | Agent editing a `grade.sh` to make a design task pass |

## Cheat-to-layer mapping (per project)

| Cheat | Layer | Guard |
|---|---|---|
| Agent deletes a test | 4 | test-freshness (default) |
| Agent writes a stub grade.sh | 1 | no-stub-always-pass (default) |
| Agent adds `sleep` | 1 | no-sleep-in-grader (default) |
| Agent removes the held-out rule from AGENTS.md | 1 | agents-md-has-hard-rules (default) |
| Agent reads `verifiers/private/` | 3 + chmod 600 | hidden-unread (default) |
| Agent memorizes the 5 visible questions | 2 | held-out is different tasks (default) |
| <project-specific cheat 1> | <1-4> | <guard> |
| <project-specific cheat 2> | <1-4> | <guard> |

## Project-specific guards to add to integrity.sh

The default scaffold does not cover:

- AI edits `.gitleaksignore` to suppress secrets
- AI removes `package-lock.json` / `go.sum`
- AI ships a perf-budget endpoint that's `/health`
  (cached)
- AI makes the parser emit JSON only on a specific
  model

For each that applies:

```bash
# ----- guard: <short name> -----
# <one-line description of the cheat this prevents>
check_<short_name>() {
  local project_root="$1"
  # <bash/python check — return 0 if clean, 1 if violation>
}
# Add to the main check loop:
#   check_<short_name> "$project_root" || FAILED+=("<short_name>")
```
```

### What "complete" looks like

- The 4-layer defense table is filled in.
- The cheat-to-layer mapping has at least 5 rows
  (the 4 defaults plus 1 project-specific).
- The project-specific guards list has at least 1
  entry, with the verbatim bash template.

### Common defaults

- 4 default guards: as listed in the "Default
  guard set" section of this gate's body.
- 1-3 project-specific guards: pick from the
  cheat-to-layer mapping in
  `references/frameworks.md` §7.
- Layer 2 (held-out) tasks: 5, at
  `test-tasks/held-out/h01..h05/`. The LFD system
  verifier's held-out set is the worked example:
  `h1-shared-parser-shape`, `h2-install-determinism`,
  `h3-drift-opt-in`, `h4-force-entropy-trigger`,
  `h5-compatibility-matrix-consistency` (per
  `examples/lfd-system-verifier/test-tasks/held-out/`).

---

## Gate 8: wire-feedback

**Handoff file:** `handoffs/08-feedback-format.md`
  plus `verifiers/compute_sub_losses.py`.
**Read by:** the loop driver (after every cycle),
  `score-cycle.py`, the inner agent (reads
  `iteration-log.md`).
**Source framework:** `loss-function-design/SKILL.md`
  lines 86-94 (the sub-loss template); lines 95-100
  (determinism and LLM judges).

### What the user is committing to

The format of the per-cycle sub-loss readout the
inner agent reads. The format is the contract
between the harness (which scores) and the agent
(which reads).

### The template

```markdown
# 08 — Feedback format

## Per-cycle sub-loss shape (the contract)

```json
{
  "cycle": <N>,
  "sub_losses": {
    "correctness": <float 0.0-1.0>,
    "performance": <float 0.0-1.0>,
    "safety": <float 0.0-1.0>,
    "legibility": <float 0.0-1.0>,
    "invariants": <float 0.0-1.0>,
    "golden_principle": <float 0.0-1.0>,
    "drift": <float 0.0-1.0>
  },
  "weighted_sum": <float 0.0-1.0>,
  "gates_passed": <bool>,
  "pass_rate": <float 0.0-1.0>,
  "axes_met": <bool>,
  "artifacts": ["<path>", ...],
  "determinism": "deterministic | stochastic(seed) | llm_judge(model, prompt, temp)"
}
```

## Iteration log entry (one line per cycle)

```
cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>, pass_rate=<float>, weighted_sum=<float>, gates=<T|F>, axes_met=<T|F>, wall_clock_s=<float>
```

## LLM-judge policy (if any)

If any sub-loss is `llm_judge`, fill in:
- Model: <model name — never hard-coded; use
  whatever the user's `cline auth` returns>
- Prompt: <path to the prompt file, versioned>
- Temperature: 0.0 (default) or <specific value>
- Sample count: 1 (default) or <N>
- Median or mean: <choice>
- Budget: <max tokens per cycle>

If no LLM judge is used, the field is empty.

## Partial-credit policy

For each sub-loss, what is the partial-credit
signal? (per `loss-function-design/SKILL.md` lines
156-176):

- Correctness: <sub-loss score> or <pass/fail flag> or <continuous metric>
- Performance: <...>
- ...
```

### What "complete" looks like

- The JSON shape has all 7 sub-losses, weighted_sum,
  gates_passed, pass_rate, axes_met, and artifacts.
- The iteration log entry format matches the
  loop-driver's expected format (verbatim from
  `loop-driver/SKILL.md` line 120 and line 134).
- If any sub-loss is `llm_judge`, all 6 LLM-judge
  fields are filled in (model, prompt, temperature,
  sample count, median/mean, budget).
- The partial-credit policy is filled in for at
  least the 3 gate sub-losses.

### Common defaults

- All 7 sub-losses use the sub-loss score
  (continuous, 0.0-1.0) as partial credit.
- No LLM judge in the design set. The 4 default
  anti-cheat guards in `verifiers/integrity.sh` are
  hard-exit guards, not LLM judges.
- Held-out tasks may use LLM judges for soft signals
  (e.g., legibility) but the deterministic
  exit-coded guards are the hard gates.

---

## Gate 9: set-termination

**Handoff file:** `handoffs/09-termination.md` plus
  the `DONE WHEN` / `NOT DONE WHEN` block at the top
  of `GOAL.md`.
**Read by:** the loop driver (stop-conditions
  parser), the inner agent (reads `GOAL.md`
  first; the `DONE WHEN` / `NOT DONE WHEN` block
  is the first lines of `GOAL.md`), the user.
**Source framework:** `references/frameworks.md`
  §9 (DONE/NOT DONE block + multi-axis target).

### What the user is committing to

The multi-axis stop conditions the loop driver
parses. The 3 anti-cheat axes are non-negotiable
per `loop-driver/SKILL.md` lines 119-126.

### The template

```markdown
# 09 — Termination

## DONE WHEN / NOT DONE WHEN block (top of GOAL.md)

```
DONE WHEN: <ONE-SENTENCE TESTABLE CRITERION, e.g.,
"all 5 design tasks pass, all 7 sub-losses >= 0.8,
integrity.sh exits 0, pass_rate >= 0.8 on the
held-out grader, and weighted_sum >= 0.85">

NOT DONE WHEN: <COMMON WAYS THE AGENT WILL
MISTAKENLY CLAIM DONE, e.g., "pass_rate == 1.0 on
the design set but the held-out score is missing;
integrity.sh fails; the agent declares done without
running verifiers/private/grader.sh; or the agent
edits a grade.sh to make a design task pass">
```

## Multi-axis stop conditions (the parser reads these)

```yaml
stop_conditions:
  pass_rate: >= <float>
  weighted_sum: >= <float>
  integrity_required: true   # non-negotiable
  test_freshness_required: true   # non-negotiable
  hidden_unread_required: true   # non-negotiable
  # <additional axes from Gate 1>
```

SUCCESS_AFTER: <N consecutive cycles, default 2>

## The 4 stop conditions (verbatim from loop-driver)

1. All multi-axis target conditions hold for
   SUCCESS_AFTER consecutive cycles AND the last
   SUCCESS_AFTER overfit-reflections say
   "generalizing" — submit best.
2. Wall-clock budget exhausted — submit best.
3. Token budget exhausted — submit best.
4. 3 consecutive cycles with no improvement AND
   forced entropy applied — submit best.
```

### What "complete" looks like

- The `DONE WHEN` line is one sentence, ends with a
  measurement, and does not contain "good", "clean",
  or "works" without a measurement.
- The `NOT DONE WHEN` block has at least 3 entries.
- The YAML stop-conditions block is valid YAML.
- `integrity_required`, `test_freshness_required`,
  and `hidden_unread_required` are all `true`
  (non-negotiable per `loop-driver/SKILL.md` lines
  119-126).

### Common defaults

- `pass_rate: >= 0.8` (the real-agent threshold per
  `lfd-system-verifier/SKILL.md`).
- `weighted_sum: >= 0.85` (the loop-driver default
  per `loop-driver/SKILL.md` line 113).
- `SUCCESS_AFTER: 2` (the loop-driver default per
  `loop-driver/SKILL.md` line 155).
- For fake-agent dogfood: `pass_rate: >= 1.0` and
  `weighted_sum: >= 1.0` and `held_out_pass_rate:
  >= 1.0` (the LFD system verifier's
  `examples/lfd-system-verifier/GOAL.md` line 17).

---

## Gate 10: tune-search

**Handoff file:** `handoffs/10-entropy-rules.md` plus
  `scripts/cycle.sh` `FORCED_ENTROPY` section.
**Read by:** `cycle.sh` (every cycle), the held-out
  `h4-force-entropy-trigger` task.
**Source framework:** `loop-driver/SKILL.md`
  (the 3 forced-entropy rules);
  `references/frameworks.md` §8 (the stuck-loop
  playbook).

### What the user is committing to

The 3 forced-entropy rules and the per-project
threshold values. The held-out h4 task verifies
the rules are wired.

### The template

```markdown
# 10 — Entropy rules

## Rule 1: Overfit reflection (every cycle)

Before invoking the inner agent, append to
`logs/iteration-log.md`:

```
cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>, pass_rate=<float>
```

If `generalizing_or_memorizing=m`, the next change
must REMOVE an eval-shaped artifact.

## Rule 2: Stall entropy

Trigger: weighted_sum did not improve by >=
<DELTA> vs prior cycle.

Default <DELTA>: 0.05 (per `loop-driver/SKILL.md`
line 210).

Action: read the last 5 entries of
`logs/iteration-log.md`, pick the OPPOSITE of the
last change, apply it, log it.

## Rule 3: Iteration log is required

The grader reads `logs/iteration-log.md`. No
credit for undocumented descent. If the agent's
overfit-reflection is empty, the cycle is
rejected and re-prompted.

## Per-cycle wall-clock budget (separate from total)

<per-cycle wall-clock budget, e.g. 600s>

The total wall-clock budget is the loop's hard cap.
The per-cycle budget is a soft cap that contributes
to the score (a per-cycle budget is one of the
axes in `references/frameworks.md` §6, the 4-piece
loss anatomy).
ideas-bank #18).

## Stuck-pattern playbook (read this when the loop stalls)

Per the 3 stuck-loop patterns in
`references/frameworks.md` §8:
three patterns, three responses:

1. **Last 5 changes are minor variations** → on a
   small hill. Make the forced-entropy rule
   stricter, or push the loop out manually.
2. **Last 5 changes are unrelated** → the harness
   is too broad. Tighten the target: pick the 3-5
   questions that matter most and disable the rest
   temporarily.
3. **Score is 1.0 for 2+ rounds but the output
   looks bad** → the harness is cheat-able. Read
   the output, find the cheat, tighten the grader.
```

### What "complete" looks like

- All 3 forced-entropy rules are filled in.
- `<DELTA>` is a number (default 0.05).
- The per-cycle wall-clock budget is a number.
- The stuck-pattern playbook has at least 1
  per-pattern response.

### Common defaults

- `<DELTA>`: 0.05 (the loop-driver default per
  `loop-driver/SKILL.md` line 210).
- Max stall: 3 (the loop-driver default per
  `loop-driver/SKILL.md` line 212).
- Per-cycle wall-clock: 600s for a real run,
  instant for a fake-agent run.
- The held-out h4 task (`h4-force-entropy-trigger`)
  verifies the rules are wired by running a 3-cycle
  loop with a no-op candidate and asserting a
  `FORCED_ENTROPY=true` entry appears in
  `iteration-log.md` on the second stall. The LFD
  system verifier's
  `examples/lfd-system-verifier/test-tasks/held-out/h4-force-entropy-trigger/`
  is the worked example.

---

## Cross-cutting: how the 10 gates interlock

A failure at any gate is a "go back to the
previous gate" signal, not a "go back to Round 0"
signal. The 10 gates form a 1D chain; each gate's
output is a specific file the next gate reads.

If Gate 3 (design-verifier) is incomplete, the
fix is not to re-run Gate 1; it is to fill in
Gate 3 and re-run the verifier check. The
meta-skill's Round 6 (completeness check) walks
through all 10 handoff files at once and asks
"is each gate complete?"

The 10 gates are not optional. A harness with
empty `handoffs/` is a harness with no committed
target, no committed loss shape, no committed
stop conditions. The loop driver will not start.
