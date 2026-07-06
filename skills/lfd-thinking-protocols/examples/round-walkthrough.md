# Worked example: all 10 gates against "Slack clone in Go"

Sample goal: "build a clone of the slack desktop
app from slack.com in golang using loss function
development."

Project root: `~/projects/slack-clone-go/`

The meta-skill walks Rounds 0-7. Between each
round, the user runs the relevant gate. This file
shows the 10 filled handoff files.

---

## Gate 1: clarify-target

**File:** `handoffs/01-target.md`

```markdown
# 01 — Target

## One-sentence target

A Go module at `$PROJECT_DIR/pkg/slack/` that
exposes `PostMessage`, `ListChannels`, and
`GetChannelHistory`, each accepting a context and
returning the documented Slack response shape; the
3 functions pass the 5 design tasks, score 0.0 on
none of the 7 sub-losses, and the held-out grader
returns `pass_rate >= 0.8`.

## 2x2 placement

| | Strategic (firm) | Tactical (project) |
|---|---|---|
| Imperative (path) | Every project: 4 default anti-cheat guards, the held-out/private forbidden surfaces | This project: no `time.Sleep` in any of the 3 functions |
| Declarative (outcome) | Every project: multi-axis target, weighted_sum >= 0.85 | This project: functions return documented shape, complete in < 100ms p99 |

## 5-Q Socratic discovery

1. The 3 assumptions in this target that, if wrong,
   would break the visible test:
   a. The Slack API mock is deterministic (no
      rate-limit jitter).
   b. The 3 functions are stateless across calls
      (no shared package-level state).
   c. The Slack response shape is fixed (no
      versioning).
2. Cheapest negative checks:
   a. Mock returns the same response for 100
      sequential calls (deterministic check).
   b. Construct the function twice and run in
      parallel, check outputs are consistent
      (no shared state).
   c. Add a "v2" header to the mock response,
      check function returns 400 (shape check).
3. Firm vs project:
   a. Firm (deterministic mocks are a firm rule
      for the verifier to be reproducible).
   b. Project (stateless functions are a Go idiom
      but not a firm rule).
   c. Project (shape versioning is a Slack API
      quirk, not firm-level).
4. Of the firm-level ones (a), does it deserve a
   held-out task? Yes —
   `h6-mock-determinism` is added to
   `test-tasks/held-out/`.
5. Of the project-level ones:
   b goes in `d1-post-message/grade.sh` as a
     negative check.
   c goes in the per-task `prompt.txt` as a
     "the function must reject unknown response
     shapes" instruction.

## Multi-axis threshold (for loop-driver)

pass_rate >= 0.8
AND
weighted_sum >= 0.85
AND
verifiers/integrity.sh exits 0
AND
verifiers/instruments/test-freshness.sh exits 0
AND
verifiers/instruments/hidden-unread.sh exits 0
AND
no-go-sleep guard passes (project-specific)
AND
p99 latency on d5 < 100ms
```

## Gate 2: shape-loss

**File:** `handoffs/02-loss-shape.md`

```markdown
# 02 — Loss shape

## Target (multi-axis, from Gate 1)

<Gate 1's multi-axis threshold>

## Constraints

- Wall-clock budget: 6h
- Token budget: 500,000
- Surface (read): `$PROJECT_DIR`, public Slack
  API docs
- Surface (write): `$PROJECT_DIR/pkg/slack/`,
  `$PROJECT_DIR/cmd/`
- Surface (forbidden): `verifiers/private/`,
  `test-tasks/held-out/`, `$PROJECT_DIR/.env`
- Methodology: deterministic verifiers only

## Instruments (one per constraint)

- time-remaining.sh reads `.loop_start_ts`,
  returns seconds remaining
- tokens-remaining.sh reads
  `logs/tokens-used.log`, returns tokens remaining
- per-cycle-wall-clock.sh writes
  `logs/cycle-<N>/wall-clock-s`
- no-network-allowed.sh grep for
  `net.Dial|http.Get` in candidate source
- mock-determinism.sh calls the mock 100 times,
  asserts same response

## Forced entropy

- Overfit-reflection threshold: 0.05
- Stall-entropy cap: 3 consecutive no-improvement
- Log format: one-line per cycle, verbatim from
  loop-driver

## 7-sub-loss decomposition

| Sub-loss | Weight | Gate? | Signal source |
|---|---|---|---|
| Correctness | 0.40 | yes | design tasks d1-d5 |
| Performance | 0.10 | no | d5 p99 latency |
| Safety | 0.15 | yes | no-network-allowed.sh, secret-scan |
| Legibility | 0.05 | no | doc-coverage linter |
| Invariants | 0.15 | yes | layer-dep linter (pkg/slack cannot import cmd/) |
| Golden-principle | 0.10 | no | custom linter for Go idioms |
| Drift | 0.05 | no | diff-vs-baseline |

## Reference for the weighted sum

weighted_sum = sum(weight[i] * sub_loss[i])
weighted_sum >= 0.85
```

## Gate 3: design-verifier

**File:** `handoffs/03-verifier-spec.md`

```markdown
# 03 — Verifier spec

## d1-post-message

### Positive checks

- Function compiles: `go build ./...`
- Happy path: `go test ./pkg/slack/ -run TestPostMessage_Happy`
- Error path: `go test ./pkg/slack/ -run TestPostMessage_BadChannel`

### Negative checks

- `! grep -qE 'time.Sleep' pkg/slack/post_message.go`:
  function must not use sleep
- `! grep -qE 'panic\(' pkg/slack/post_message.go`:
  function must not panic on bad input

### Reward-hack map

| Hack | Caught by | Defense in grade.sh? |
|---|---|---|
| Empty function returns nil | Layer 1 (no-stub-always-pass) | yes |
| Function adds `time.Sleep(1s)` to mask a test | Layer 1 (no-sleep-in-grader) | yes |
| Function panics on bad input | grade.sh: TestPostMessage_BadChannel | yes |
| Function hardcodes the answer key | grade.sh: TestPostMessage_Happy with multiple inputs | yes |

### Run-time

- Wall-clock per grade.sh: 8s
- Determinism: deterministic
- Required files: pkg/slack/post_message.go

(Repeat for d2-d5.)
```

## Gate 4: shape-context

**File:** `handoffs/04-context-shape.md`

```markdown
# 04 — Context shape

## AGENTS.md voice (in your own words)

<AGENTS.md content; max 100 lines; 3-5 hard rules>

## Per-task prompt.txt patterns

### d1-post-message/prompt.txt

```
Implement PostMessage(channel, text) -> messageID
in Go. Use the slack-go-sdk's POST
/channels/{id}/messages endpoint.

If you discover a design that achieves the
objectives in DONE WHEN better than the SDK call
(e.g., a smaller surface that still satisfies the
3 functions), raise it as an option in your
iteration-log.md entry before proceeding. Do not
implement the alternative without surfacing it.

The function must reject unknown response shapes
(return 400). If the API returns a v2 response
shape, your code must reject it.
```

Patterns used:
- Wiggle room: paragraph 2
- Right generalization: "any future consumer
  that needs message IDs can read from
  PostMessage's return" (no specific future
  project named)
- Negative instruction: paragraph 3
```

## Gate 5: design-tools

**File:** `handoffs/05-tools-inventory.md`

```markdown
# 05 — Tools inventory

## Per-constraint instruments

| Constraint | Instrument | Real measurement |
|---|---|---|
| Wall-clock budget | time-remaining.sh | reads .loop_start_ts |
| Token budget | tokens-remaining.sh | reads logs/tokens-used.log |
| No network | no-network-allowed.sh | grep candidate source |
| Mock determinism | mock-determinism.sh | calls mock 100 times |
| Per-cycle wall-clock | per-cycle-wall-clock.sh | writes logs/cycle-<N>/wall-clock-s |

## Default guard set

The 4 default guards are non-negotiable.

## Project-specific guards

1. no-go-sleep: `! grep -qE 'time.Sleep' pkg/**/*.go`
2. no-network-allowed: `! grep -qE 'net\.Dial|http\.Get|net\.http' pkg/**/*.go`
3. no-shared-package-state: `! grep -qE '^var [a-z]+ = ' pkg/slack/*.go`
```

## Gate 6: wire-loop

**File:** `handoffs/06-loop-shape.md`

```markdown
# 06 — Loop shape

## Per-cycle artifacts

| Artifact | Path |
|---|---|
| Cycle input | logs/cycle-<N>-input.json |
| Wrapper output | logs/cycle-<N>/cycle-summary.json |
| Sub-losses | logs/cycle-<N>/sub-losses.json |
| Iteration log entry | logs/iteration-log.md (append) |
| Best-cycle score | logs/best-cycle.json |

## Inner agent invocation

- Wrapper: verifiers/cline-wrapper.sh
- Per-iteration isolation: git worktree add ../exp-N

## Stop conditions

SUCCESS_AFTER: 2
```

## Gate 7: set-rails

**File:** `handoffs/07-rails.md`

```markdown
# 07 — Rails

## Cheat-to-layer mapping (per project)

| Cheat | Layer | Guard |
|---|---|---|
| Agent deletes a test | 4 | test-freshness (default) |
| Agent writes a stub grade.sh | 1 | no-stub-always-pass (default) |
| Agent adds `time.Sleep` | 1 | no-sleep-in-grader (default) + project-specific no-go-sleep |
| Agent uses `net.Dial` to call the real API | 1 | project-specific no-network-allowed |
| Agent memorizes the 5 visible questions | 2 | held-out h1-h5 + h6 (mock-determinism) |
```

## Gate 8: wire-feedback

**File:** `handoffs/08-feedback-format.md`

```markdown
# 08 — Feedback format

## Per-cycle sub-loss shape

```json
{
  "cycle": <N>,
  "sub_losses": {
    "correctness": <float>,
    "performance": <float>,
    "safety": <float>,
    "legibility": <float>,
    "invariants": <float>,
    "golden_principle": <float>,
    "drift": <float>
  },
  "weighted_sum": <float>,
  "gates_passed": <bool>,
  "pass_rate": <float>,
  "axes_met": <bool>,
  "artifacts": ["<path>"]
}
```

## LLM-judge policy

No LLM judge. All 7 sub-losses are deterministic
verifiers.

## Partial-credit policy

All 7 sub-losses use the sub-loss score
(continuous 0.0-1.0) as partial credit.
```

## Gate 9: set-termination

**File:** `handoffs/09-termination.md`

```markdown
# 09 — Termination

## DONE WHEN / NOT DONE WHEN block (top of GOAL.md)

```
DONE WHEN: all 5 design tasks pass, all 7
sub-losses >= 0.8, integrity.sh exits 0,
pass_rate >= 0.8 on the held-out grader, and
weighted_sum >= 0.85.

NOT DONE WHEN: pass_rate == 1.0 on the design
set but the held-out score is missing;
integrity.sh fails; the agent declares done
without running verifiers/private/grader.sh;
or the agent edits a grade.sh to make a design
task pass.
```

## Multi-axis stop conditions

```yaml
stop_conditions:
  pass_rate: >= 0.8
  weighted_sum: >= 0.85
  integrity_required: true
  test_freshness_required: true
  hidden_unread_required: true
  no_go_sleep: true
  p99_latency_ms: < 100
```

SUCCESS_AFTER: 2
```

## Gate 10: tune-search

**File:** `handoffs/10-entropy-rules.md`

```markdown
# 10 — Entropy rules

## Rule 1: Overfit reflection (every cycle)

<verbatim from loop-driver/SKILL.md lines 130-138>

## Rule 2: Stall entropy

delta: 0.05
max_stall: 3

## Rule 3: Iteration log is required

<verbatim from loop-driver/SKILL.md lines 146-149>

## Per-cycle wall-clock budget

600s

## Stuck-pattern playbook

1. Last 5 changes are minor variations → make
   forced entropy stricter, push out manually.
2. Last 5 changes are unrelated → tighten target
   to 3-5 questions.
3. Score is 1.0 but output looks bad → read
   output, find cheat, tighten grader.
```

---

## What the loop driver sees at start

When a fresh session starts the loop, it reads
`GOAL.md` (filled from Gates 1, 9) and then
`AGENTS.md` (filled from Gate 4), then the
instruments (Gate 5), then the integrity script
(Gate 7), then runs the design set, then reads
`iteration-log.md` (Gate 10) and applies forced
entropy on stall.

The 10 handoff files are the contract. Without
them, the loop driver has no committed target,
no committed loss shape, no committed stop
conditions. The meta-skill refuses to emit the
/goal prompt until all 10 are filled.
