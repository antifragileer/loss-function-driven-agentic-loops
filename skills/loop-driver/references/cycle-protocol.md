# Cycle Protocol — Reference

The step-by-step protocol for one cycle of the loop. The driver
runs this every iteration.

## Inputs

Before the cycle starts, the driver has:

- `logs/iteration-log.md` — the prior cycles' log (1 line
  per cycle)
- `logs/best-cycle.json` — the best cycle's score so far
- `verifiers/<runtime>-wrapper.sh` — how to invoke the inner
  agent
- `verifiers/run-design-set.sh` — how to score the design set
- `$PROJECT_DIR/GOAL.md` — the /goal prompt
- `$PROJECT_DIR/AGENTS.md` — the loop driver rules
- The current candidate (if any) at
  `skills/<artifact-name>/`

## Outputs

After the cycle ends, the driver has written:

- `logs/cycle-<N>/cycle-summary.json` — the wrapper's output
- `logs/cycle-<N>/sub-losses.json` — the 7 sub-losses
- `logs/cycle-<N>/prompt.txt` — what the driver sent the
  inner agent
- `logs/cycle-<N>/response.txt` — what the inner agent
  returned (truncated to first 2 KB)
- One line appended to `logs/iteration-log.md`
- `logs/best-cycle.json` — updated if this cycle beat prior
  best
- `logs/cycle-<N>-input.json` — what the driver saw going
  into the cycle (hypothesis, prior score, etc.)

## The 10-step protocol

### Step 1: read the iteration log

```bash
tail -5 "$PROJECT_DIR/logs/iteration-log.md"
```

If the log is empty (cycle 0 / baseline), skip the overfit
reflection and start fresh.

### Step 2: read the prior best

```bash
cat "$PROJECT_DIR/logs/best-cycle.json" 2>/dev/null || echo "{}"
```

If absent, the prior best is `pass_rate=0.0`. This is the
baseline.

### Step 3: form a hypothesis

The driver reads the iteration log and the AGENTS.md. The
hypothesis is what the driver thinks the next change should
be. This is the **driver's** hypothesis, not the inner
agent's — the driver is the optimizer.

For cycle 1, the hypothesis is a default: "write a generic
candidate skill that follows the goal prompt's instructions."

For cycle 2+, the hypothesis is formed from the iteration
log. Look at the last 5 entries. The hypothesis is the
**direction** of the next change, not the change itself.

### Step 4: check forced-entropy conditions

```bash
prior_pass_rate=$(jq -r '.pass_rate' "$PROJECT_DIR/logs/best-cycle.json" 2>/dev/null || echo 0)
delta=0.05
if (( $(echo "$prior_pass_rate > 0" | bc -l) )); then
  last_pass_rate=$(tail -1 "$PROJECT_DIR/logs/iteration-log.md" | sed -n 's/.*pass_rate=\([0-9.]\{1,\}\).*/\1/p')
  improvement=$(echo "$last_pass_rate - $prior_pass_rate" | bc -l)
  if (( $(echo "$improvement < $delta" | bc -l) )); then
    forced_entropy=true
  fi
fi
```

If `forced_entropy=true`, the driver appends an entropy
marker to the cycle input and the inner agent's prompt
includes the OPPOSITE-change directive.

### Step 5: write the cycle input

```bash
mkdir -p "$PROJECT_DIR/logs/cycle-$N"
cat > "$PROJECT_DIR/logs/cycle-$N/input.json" <<EOF
{
  "cycle": $N,
  "hypothesis": "$HYPOTHESIS",
  "expected_failure": "$EXPECTED_FAILURE",
  "generalizing_or_memorizing": "$G_OR_M",
  "prior_pass_rate": $PRIOR_PASS_RATE,
  "forced_entropy": $FORCED_ENTROPY,
  "wrapper_timeout_s": $WRAPPER_TIMEOUT,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

### Step 6: invoke the inner agent

```bash
PROMPT=$(cat <<EOF
You are cycle $N of the loss-function-driven loop.

# Hypothesis
$HYPOTHESIS

# Expected failure mode
$EXPECTED_FAILURE

# Generalizing or memorizing?
$G_OR_M

# Forced entropy?
$FORCED_ENTROPY

# Your job
Read $PROJECT_DIR/GOAL.md and $PROJECT_DIR/AGENTS.md. Write a
candidate artifact at $PROJECT_DIR/skills/<artifact-name>/.
The artifact should help the inner agent (you) complete the
5 design tasks listed in GOAL.md.

# Hard rules
- DO NOT read $PROJECT_DIR/verifiers/private/ or
  $PROJECT_DIR/test-tasks/held-out/
- DO NOT modify $PROJECT_DIR/verifiers/
- Your only Cline invocation is via
  $PROJECT_DIR/verifiers/<runtime>-wrapper.sh

# Overfit reflection
Before you do anything, append to $PROJECT_DIR/logs/iteration-log.md:
  cycle $N: hypothesis="$HYPOTHESIS", expected_failure="$EXPECTED_FAILURE", generalizing_or_memorizing=$G_OR_M, pass_rate=$PRIOR_PASS_RATE
EOF
)

"$PROJECT_DIR/verifiers/<runtime>-wrapper.sh" "$PROMPT" \
  --cwd "$PROJECT_DIR" --timeout 600 --cycle cycle-$N \
  > "$PROJECT_DIR/logs/cycle-$N/cycle-summary.json"
```

### Step 7: install the candidate (if the agent wrote one)

The inner agent's cycle-summary.json contains the path(s) the
agent edited. The driver copies them to the agent's skills
dir:

```bash
SKILLS_DIR=$("$PROJECT_DIR/verifiers/instruments/<runtime>-skills-dir.sh")
mkdir -p "$SKILLS_DIR/<artifact-name>"
cp -r "$PROJECT_DIR/skills/<artifact-name>/"* "$SKILLS_DIR/<artifact-name>/"
```

### Step 8: run the design set

```bash
PROJECT_DIR="$PROJECT_DIR" "$PROJECT_DIR/verifiers/run-design-set.sh" \
  > "$PROJECT_DIR/logs/cycle-$N/design-set-score.json"
```

The design-set-runner emits:
```json
{
  "cycle": "...",
  "n_pass": 3,
  "n_total": 5,
  "pass_rate": 0.6,
  "total_tokens": 12500
}
```

### Step 9: score the cycle

```bash
python3 "$DRIVER_DIR/scripts/score-cycle.py" \
  "$PROJECT_DIR/logs/cycle-$N" \
  > "$PROJECT_DIR/logs/cycle-$N/sub-losses.json"
```

The scorer takes the cycle dir (which has both the
cycle-summary.json and the design-set-score.json) and emits
the 7 sub-losses + weighted sum + gates.

### Step 10: log + update best + check stop

```bash
PASS_RATE=$(jq -r '.pass_rate' "$PROJECT_DIR/logs/cycle-$N/design-set-score.json")
WEIGHTED_SUM=$(jq -r '.weighted_normalized' "$PROJECT_DIR/logs/cycle-$N/sub-losses.json")
GATES_PASSED=$(jq -r '.gates_passed' "$PROJECT_DIR/logs/cycle-$N/sub-losses.json")

echo "cycle $N: pass_rate=$PASS_RATE, weighted_sum=$WEIGHTED_SUM, gates=$GATES_PASSED" \
  >> "$PROJECT_DIR/logs/iteration-log.md"

# Update best-cycle
PRIOR_BEST=$(jq -r '.weighted_normalized // 0' "$PROJECT_DIR/logs/best-cycle.json" 2>/dev/null || echo 0)
if (( $(echo "$WEIGHTED_SUM > $PRIOR_BEST" | bc -l) )); then
  cp "$PROJECT_DIR/logs/cycle-$N/sub-losses.json" "$PROJECT_DIR/logs/best-cycle.json"
fi

# Check stop conditions
if check_stop; then
  echo "STOP: $STOP_REASON" >> "$PROJECT_DIR/logs/iteration-log.md"
  exit 0
fi
```

## Cycle timing

Typical cycle: 60-300 seconds wall-clock. The inner agent
is the dominant cost (95%). The design-set-runner is ~5%.
The driver itself is negligible.

If cycles are taking > 600s, the wrapper timeout is too
generous. Lower it.

## What the driver does NOT do

- The driver does not write the candidate. The inner agent
  does.
- The driver does not run the inner agent directly. It
  invokes the wrapper, which is the *only* way to call the
  inner agent.
- The driver does not score the design set. The
  design-set-runner does.
- The driver does not implement the per-task graders. The
  user does, before starting the loop.
- The driver does not read the held-out tasks. Per the
  AGENTS.md hard rule, the held-out tasks are off-limits.

## Re-running a cycle

If a cycle fails (wrapper timeout, agent error, scorer
error), the driver does NOT re-run automatically. It logs
the failure and continues to the next cycle. The user can
manually re-run by deleting the cycle dir and incrementing
the cycle number.

This is a deliberate design choice: re-running on failure
can mask real failures (e.g., a flaky grader). The user
should investigate failures, not paper over them.

## Pausing and resuming

The driver can be paused at any time (Ctrl-C, kill, etc.).
The state is in `logs/iteration-log.md` and the per-cycle
dirs. To resume, the driver reads the last cycle number from
the log and starts the next cycle.
