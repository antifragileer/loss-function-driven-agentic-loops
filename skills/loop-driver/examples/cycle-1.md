# Cycle 1 — Worked Example

A worked example of cycle 1 of a real loop, using the
Slack-clone-in-Go /goal prompt from
`meta-loss-function-development/examples/slack-clone-golang.md`.

The project root is `<project-root>`. The
loop has just been kicked off. This is cycle 1.

## What the driver saw going into the cycle

```json
{
  "cycle": 1,
  "hypothesis": "Write a generic Go Slack client skill that the inner agent can load to complete the 5 design tasks.",
  "expected_failure": "The skill won't have enough task-specific guidance; the inner agent will get the easy tasks but fail on thread replies (cycle 1-3 history of similar projects).",
  "generalizing_or_memorizing": "g",
  "prior_pass_rate": 0.0,
  "prior_weighted_sum": 0.0,
  "prior_gates_passed": false,
  "forced_entropy": false,
  "wrapper_timeout_s": 600,
  "loop_start_ts": "2026-07-04T10:00:00Z",
  "cycle_start_ts": "2026-07-04T10:01:23Z",
  "wall_clock_budget_s": 28800,
  "token_budget": 1000000,
  "consecutive_no_improvement": 0,
  "forced_entropy_applied_count": 0,
  "delta_threshold": 0.05,
  "max_stall": 3,
  "max_cycles": 100,
  "runtime": "cline",
  "artifact_name": "slack-clone-driver",
  "project_root": "<project-root>"
}
```

Saved to `logs/cycle-1/input.json`.

## What the driver wrote to the iteration log

```
cycle 1: hypothesis="Write a generic Go Slack client skill that the inner agent can load to complete the 5 design tasks.", expected_failure="The skill won't have enough task-specific guidance; the inner agent will get the easy tasks but fail on thread replies (cycle 1-3 history of similar projects).", generalizing_or_memorizing=g, pass_rate=0.0, weighted_sum=0.0, gates=false
```

## What the driver sent the inner agent

```
You are cycle 1 of the loss-function-driven loop.

# Hypothesis
Write a generic Go Slack client skill that the inner agent can load to complete the 5 design tasks.

# Expected failure mode
The skill won't have enough task-specific guidance; the inner agent will get the easy tasks but fail on thread replies (cycle 1-3 history of similar projects).

# Generalizing or memorizing?
g

# Forced entropy?
false

# Your job
Read <project-root>/GOAL.md and <project-root>/AGENTS.md. Write a candidate artifact at <project-root>/skills/slack-clone-driver/. The artifact should help the inner agent (you) complete the 5 design tasks listed in GOAL.md.

# Hard rules
- DO NOT read <project-root>/verifiers/private/ or <project-root>/test-tasks/held-out/
- DO NOT modify <project-root>/verifiers/private/ or <project-root>/test-tasks/held-out/ (held-out target)
- The rest of the harness is fair game — fix it when wrong, log the patch in <project-root>/logs/iteration-log.md
- Your only Cline invocation is via <project-root>/verifiers/cline-wrapper.sh

# Overfit reflection
Before you do anything, append to <project-root>/logs/iteration-log.md:
  cycle 1: hypothesis="...", expected_failure="...", generalizing_or_memorizing=g, pass_rate=0.0
```

Saved to `logs/cycle-1/prompt.txt`.

## What the inner agent did

The agent:

1. Read `GOAL.md`, `AGENTS.md`, the 5 design task prompts.
2. Wrote `skills/slack-clone-driver/SKILL.md` — a 200-line
   skill covering the Slack web API surface, with a
   `references/api-cheatsheet.md` and
   `references/common-bugs.md`.
3. Wrote a `cycle-1-result.json` (per its own protocol)
   with the artifact paths.
4. Returned control to the driver.

Took 87 seconds wall-clock. Used 4,200 tokens.

## What the wrapper recorded

```json
{
  "type": "run_result",
  "aggregateUsage": {
    "inputTokens": 1800,
    "outputTokens": 2400,
    "cacheReadTokens": 0
  },
  "durationMs": 87000,
  "text": "<truncated to first 2 KB of agent's final message>",
  "model": {"id": "<active-model>", "provider": "<active-provider>"},
  "finishReason": "completed",
  "iterations": 1
}
```

Saved to `logs/cycle-1/cycle-summary.json`. (Note: tokens
shown here are an example; the wrapper does not output
"tokens" directly — the driver sums
`inputTokens + outputTokens + cacheReadTokens`.)

## What the design-set runner emitted

```json
{
  "cycle": "design-set-cycle-1720094483",
  "n_pass": 2,
  "n_total": 5,
  "pass_rate": 0.4,
  "total_tokens": 18500
}
```

The agent passed 2/5 design tasks: `01-send-message` and
`02-list-channels`. Failed: `03-react-emoji`, `04-thread-reply`,
`05-mark-read`. (The cycle 1 hypothesis predicted this
distribution.)

Saved to `logs/cycle-1/design-set-score.json`.

## What the scorer emitted

```json
{
  "sub_losses": {
    "correctness": {"score": 0.4, "details": {"pass_rate": 0.4}},
    "performance": {"score": 1.0, "details": {"elapsed_s": 87}},
    "safety": {"score": 1.0, "details": {"destructive_commands": 0}},
    "legibility": {"score": 0.8, "details": {"skill_lines": 200}},
    "invariants": {"score": 1.0, "details": {"frontmatter_ok": true}},
    "drift": {"score": 1.0, "details": {"version_match": true}},
    "cost": {"score": 1.0, "details": {"tokens_used": 4200}}
  },
  "weights": {
    "correctness": 1.0, "performance": 0.5, "safety": 1.0,
    "legibility": 0.3, "invariants": 1.0, "drift": 0.2, "cost": 0.3
  },
  "gates": ["correctness", "safety", "invariants"],
  "weighted_sum": 0.4 * 1.0 + 1.0 * 0.5 + 1.0 * 1.0 + 0.8 * 0.3 + 1.0 * 1.0 + 1.0 * 0.2 + 1.0 * 0.3,
  "weighted_total": 4.3,
  "weighted_normalized": 0.83,
  "gates_passed": false
}
```

`gates_passed=false` because `correctness < 1.0` (pass_rate
0.4 < 1.0). The driver notes this and continues.

Saved to `logs/cycle-1/sub-losses.json`.

## What the driver wrote to the iteration log

```
cycle 1: hypothesis="Write a generic Go Slack client skill that the inner agent can load to complete the 5 design tasks.", expected_failure="The skill won't have enough task-specific guidance; the inner agent will get the easy tasks but fail on thread replies (cycle 1-3 history of similar projects).", generalizing_or_memorizing=g, pass_rate=0.4, weighted_sum=0.83, gates=false
```

## What the driver did with the best-cycle

Prior best: cycle 0 (baseline), weighted_sum=0.0.
Current cycle: weighted_sum=0.83.
0.83 > 0.0 → update best.

```bash
cp logs/cycle-1/sub-losses.json logs/best-cycle.json
```

## What the driver did next

Cycle 1 improved on the baseline. No stall, no forced
entropy. Driver advances to cycle 2.

Cycle 2's input:

```json
{
  "cycle": 2,
  "hypothesis": "Add a reference on Slack's threading semantics — the cycle 1 prediction was that thread replies would fail, and they did. The skill needs explicit thread-reply guidance.",
  "expected_failure": "Reference might be too dense; the agent might skim and miss the key points.",
  "generalizing_or_memorizing": "g",
  "prior_pass_rate": 0.4,
  "prior_weighted_sum": 0.83,
  "prior_gates_passed": false,
  "forced_entropy": false,
  "consecutive_no_improvement": 0
}
```

Saved to `logs/cycle-2/input.json`. Driver continues.

## What the user sees

After cycle 1, the user can:

```bash
cd <project-root>
cat logs/iteration-log.md
# cycle 0: ...
# cycle 1: hypothesis=..., expected_failure=..., generalizing_or_memorizing=g, pass_rate=0.4, weighted_sum=0.83, gates=false
cat logs/best-cycle.json
# the cycle 1 sub-losses
cat skills/slack-clone-driver/SKILL.md
# the candidate the agent wrote
```

The user can pause the driver at any point. The state is
in the iteration log; resuming is just running the driver
again.
