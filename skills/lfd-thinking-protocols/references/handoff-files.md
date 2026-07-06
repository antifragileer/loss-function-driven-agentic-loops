# Handoff Files

The 10 thinking-protocol gates write to specific
files in `$PROJECT_DIR/handoffs/`. This file is
the index: who writes, who reads, and what happens
if a file is missing.

## Index

| Gate | Handoff file | Writer | Reader(s) | Missing-file behavior |
|---|---|---|---|---|
| 1 clarify-target | `handoffs/01-target.md` | user + skill | meta-skill Round 1, loop-driver stop-conditions parser, `verifiers/integrity.sh` | meta-skill refuses to start Round 1 |
| 2 shape-loss | `handoffs/02-loss-shape.md` | user + skill | meta-skill Round 1, `verifiers/compute_sub_losses.py`, `score-cycle.py` | meta-skill refuses to scaffold design tasks |
| 3 design-verifier | `handoffs/03-verifier-spec.md` + per-task `test-tasks/<id>/grade.sh` | user + skill | meta-skill Round 2, `verifiers/integrity.sh` Layer-1 guards, held-out grader | meta-skill refuses to start Round 2 |
| 4 shape-context | `handoffs/04-context-shape.md` + `AGENTS.md` + per-task `test-tasks/<id>/prompt.txt` | user + skill | inner agent, loop driver, user | meta-skill refuses to start Round 5 |
| 5 design-tools | `handoffs/05-tools-inventory.md` + `verifiers/instruments/*.sh` | user + skill | loop driver, inner agent, `verifiers/integrity.sh` | meta-skill refuses to start Round 4 |
| 6 wire-loop | `handoffs/06-loop-shape.md` | user + skill | `loop-driver/scripts/cycle.sh`, inner agent | meta-skill refuses to start Round 7 |
| 7 set-rails | `handoffs/07-rails.md` + `verifiers/integrity.sh` | user + skill | `verifiers/integrity.sh` (every cycle), held-out grader | meta-skill refuses to start Round 4 |
| 8 wire-feedback | `handoffs/08-feedback-format.md` + `verifiers/compute_sub_losses.py` | user + skill | loop driver, `score-cycle.py`, inner agent | meta-skill refuses to start Round 6 |
| 9 set-termination | `handoffs/09-termination.md` + `GOAL.md` DONE/NOT DONE | user + skill | loop driver stop-conditions parser, inner agent, user | meta-skill refuses to emit /goal prompt |
| 10 tune-search | `handoffs/10-entropy-rules.md` + `scripts/cycle.sh` FORCED_ENTROPY | user + skill | `cycle.sh`, held-out h4 task | meta-skill refuses to start Round 7 |

## Read order at loop start

When a fresh session starts the loop, it reads
these handoff files in this order (because each
one constrains the next):

1. `01-target.md` — what success looks like
2. `02-loss-shape.md` — what to score
3. `05-tools-inventory.md` — what to measure with
4. `07-rails.md` — what's forbidden
5. `08-feedback-format.md` — what the sub-losses
   look like
6. `06-loop-shape.md` — what one cycle does
7. `09-termination.md` — when to stop
8. `10-entropy-rules.md` — when to force entropy
9. `03-verifier-spec.md` — how the design set is
   graded
10. `04-context-shape.md` — what the agent reads

This order matches the
`meta-loss-function-development/templates/goal-prompt.md`
"First action" list (lines 200-233):
read `GOAL.md` first (which is filled from
`01-target.md` and `09-termination.md`), then
`AGENTS.md` (filled from `04-context-shape.md`),
then the wrapper, design-set runner, integrity
script, and every instrument.

## Handoff files are NOT in `.gitignore`

The LFD system verifier's `.gitignore` excludes
ephemeral outputs (`logs/`, `verification-report*.json`,
`.iterations/`, etc.) per
`lfd-system-verifier/SKILL.md` lines 100-145. The
`handoffs/` directory is **not** in that list.
Handoff files are part of the harness, not
runtime output.

When the verifier copies the harness to a temp
profile, `handoffs/` is included. When the loop
session reads the harness, it reads `handoffs/`.
When the user changes a gate, the new handoff
file replaces the old one; the loop session picks
up the change on the next cycle.

## Handoff files and the held-out guarantee

`handoffs/` is NOT `chmod 700`. The loop session
**can** read it. This is by design: the loop
session needs the target, the loss shape, the
stop conditions, the forced-entropy rules. It
does not need to read the design tasks (it has
its own) and it does not need to read the
held-out tasks (those are off-limits per the
Hard Rules section of the /goal prompt).

The split:

- `handoffs/` — readable by the loop session.
  These are the *contract* the user wrote.
- `test-tasks/design/` — readable by the loop
  session. These are the practice exam.
- `test-tasks/held-out/` — `chmod 700`, NOT
  readable. This is the real exam.
- `verifiers/private/` — `chmod 600`, NOT
  readable. This is the held-out grader.

## Schema for `01-target.md`

The loop driver's stop-conditions parser reads
the YAML block at the end of `01-target.md`:

```yaml
stop_conditions:
  pass_rate: >= <float>
  weighted_sum: >= <float>
  integrity_required: true
  test_freshness_required: true
  hidden_unread_required: true
  # additional axes
```

The 3 anti-cheat axes are non-negotiable. The
parser refuses to start the loop if any of them
is `false`. Per `loop-driver/SKILL.md` lines
119-126, the user can disable them in `GOAL.md`
by setting `integrity_required = false`, but the
default is `true` and the held-out grader does
not honor the disable.

## Schema for `02-loss-shape.md`

`verifiers/compute_sub_losses.py` reads the
sub-loss table at the end of `02-loss-shape.md`:

```yaml
sub_losses:
  - name: correctness
    weight: <float>
    gate: <bool>
    signal_source: <path or tool>
  - name: performance
    weight: <float>
    gate: <bool>
    signal_source: <path or tool>
  # ... 5 more
```

Weights must sum to 1.0. At least 3 sub-losses
must have `gate: true`. The 3 default gates are
correctness, safety, and invariants.

## Schema for `07-rails.md`

`verifiers/integrity.sh` reads the project-specific
guards from `07-rails.md`. Each guard has a
verbatim bash function following the template
in `BUILDING-A-GREAT-HARNESS.md` lines 553-563:

```bash
# ----- guard: <short name> -----
# <one-line description of the cheat this prevents>
check_<short_name>() {
  local project_root="$1"
  # <bash/python check — return 0 if clean, 1 if violation>
}
```

The skill `patch`es `verifiers/integrity.sh` to
add each `check_<short_name>` to the main check
loop, and to add the failure handler:

```bash
check_<short_name> "$project_root" || FAILED+=("<short_name>")
```

## Schema for `09-termination.md`

The `DONE WHEN` / `NOT DONE WHEN` block is
copied verbatim to the top of `GOAL.md`. The
format is fixed (per
`meta-loss-function-development/SKILL.md` lines
317-323):

```
DONE WHEN: <one-sentence testable criterion>
NOT DONE WHEN: <list of common wrong claims>
```

Both lines are required. The block is the first
thing the inner agent reads.

## Schema for `10-entropy-rules.md`

`scripts/cycle.sh` reads the 3 forced-entropy
rules and the per-cycle budget. The schema:

```yaml
forced_entropy:
  delta: <float>           # default 0.05
  max_stall: <int>         # default 3
  success_after: <int>     # default 2
per_cycle_wall_clock_s: <int>  # default 600
```

The held-out h4 task verifies the rules are
wired by running a 3-cycle loop with a no-op
candidate and asserting that a
`FORCED_ENTROPY=true` entry appears in
`iteration-log.md` on the second stall.
