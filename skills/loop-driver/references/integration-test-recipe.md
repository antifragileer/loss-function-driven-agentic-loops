# Integration Test Recipe — Reference

End-to-end verification of `cycle.sh` + `run-loop.sh`
without invoking a real LLM. Useful when:

- You just modified `cycle.sh` and want to confirm the
  fix didn't break the loop semantics.
- You want to demo the system to a new user.
- A user reports "the loop exits silently" and you need
  to reproduce on a clean machine.

The recipe takes ~30 seconds and produces a populated
`logs/iteration-log.md` and `logs/best-cycle.json` you
can diff against expected output.

## The recipe

### Step 1: set up a fake cline

```bash
mkdir -p /tmp/fake-cline-bin
cp templates/fake-cline.sh /tmp/fake-cline-bin/cline
chmod +x /tmp/fake-cline-bin/cline
```

`templates/fake-cline.sh` is a 40-line shell script
that emulates the Cline CLI's NDJSON output. It writes
a fake `cline.json` to the dir passed via `--cwd` and
exits 0. It also varies the candidate text by the task
slug in the dir path, so the 5 design tasks in the
scaffolded project can pass/fail independently.

Customize via env vars:
- `FAKE_CLINE_FAIL_ALL=1` — every task fails (for negative
  testing of the loop's response to 0% pass rate).
- `FAKE_CLINE_INPUT_TOKENS=N` / `FAKE_CLINE_OUTPUT_TOKENS=N` /
  `FAKE_CLINE_DURATION_MS=N` — control the per-cycle cost
  sub-loss.

### Step 2: scaffold a test project

```bash
mkdir -p /tmp/test-loop
cp path/to/slack-clone-golang-prompt.txt /tmp/test-loop/GOAL.md
python3 path/to/harness-scaffold/scripts/scaffold.py \
    --project-root /tmp/test-loop \
    --goal-prompt /tmp/test-loop/GOAL.md
```

This writes the harness tree (5 design tasks, 10 held-out
tasks, 11 verifiers, AGENTS.md, GOAL.md, README.md).

### Step 3: fill in one real grade.sh

The scaffold writes `grade.sh` as a stub that always
exits 1. Replace at least one with a real grader so the
loop has something to score against. The default fake
cline emits a "send-message" answer for task 01, so a
matching grade.sh is:

```bash
cat > /tmp/test-loop/test-tasks/design/01-implement-a-function-that-takes-a/grade.sh <<'GRADER'
#!/usr/bin/env bash
set -euo pipefail
ITER="${1:-}"
[[ -z "$ITER" ]] && exit 2
TEXT=$(python3 -c "import json; print(json.load(open('$ITER/cline.json')).get('text',''))" 2>/dev/null || echo "")
echo "$TEXT" | grep -qiE "send|message" && exit 0 || exit 1
GRADER
chmod +x /tmp/test-loop/test-tasks/design/01-implement-a-function-that-takes-a/grade.sh
```

### Step 4: run the loop

```bash
PATH=/tmp/fake-cline-bin:$PATH \
    bash path/to/loop-driver/scripts/run-loop.sh \
    --project-root /tmp/test-loop \
    --wrapper-timeout 30
```

Expected output (with the default fake cline + 1 real
grade.sh):

```
[cycle] SUCCESS_COUNT=0
[cycle 1] invoking wrapper...
[cycle 1] wrapper exited 0
[cycle 1] running design set...
[cycle 1] scoring...
[cycle 1] new best: weighted_sum=0.5116, pass_rate=0.2
{
  "cycle": 1,
  "pass_rate": 0.2,
  "weighted_sum": 0.5116,
  "gates_passed": false,
  "forced_entropy": false,
  "improved": true,
  "cycle_dir": "/tmp/test-loop/logs/cycle-1",
  "best_file": "/tmp/test-loop/logs/best-cycle.json"
}
[loop] === cycle 2 ===
[cycle 2] invoking wrapper...
...
[cycle 4] === cycle 4 ===
[cycle] SUCCESS_COUNT=0
{"stop": "stall", "reason": "max-stall reached with forced entropy applied"}
[loop] stopped: stall (after 4 cycles)
```

4 cycles total. Cycles 2-4 all score 0.2 (same as cycle
1) because the fake cline is deterministic. Stall-stop
fires at cycle 4 because 3 consecutive stalls with 1
forced-entropy cycle satisfy the spec.

### Step 5: inspect the result

```bash
cat /tmp/test-loop/logs/iteration-log.md
# 3 cycle lines + 1 STOP line
# Each cycle line: hypothesis="...", pass_rate=0.2, weighted_sum=0.5116, gates=false
# Cycle 2 line: includes FORCED_ENTROPY=true
# STOP line: "STOP: stall. After 4 cycles. Best weighted_sum=0.5116. Best pass_rate=0.2."

cat /tmp/test-loop/logs/best-cycle.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'weighted_sum: {d[\"weighted_sum\"]}')
print(f'weighted_normalized: {d[\"weighted_normalized\"]}')
print(f'gates_passed: {d[\"gates_passed\"]}')
print(f'sub_losses: {list(d[\"sub_losses\"].keys())}')"
# weighted_sum: 2.2
# weighted_normalized: 0.5116
# gates_passed: False
# sub_losses: ['correctness', 'performance', 'safety', 'legibility', 'invariants', 'drift', 'cost']

ls /tmp/test-loop/logs/cycle-1/
# cycle-summary.json  design-set-score.json  design-set.stderr
# input.json  prompt.txt  score.stderr  sub-losses.json  wrapper.stderr
```

## Variations

### Negative test: every task fails

```bash
FAKE_CLINE_FAIL_ALL=1 \
PATH=/tmp/fake-cline-bin:$PATH \
    bash run-loop.sh --project-root /tmp/test-loop --wrapper-timeout 30
```

Expected: pass_rate=0.0 every cycle, weighted_sum≈0.27
(only performance/safety/invariants/drift/cost contribute
1.0; correctness=0.0 and legibility=0.8). Stall fires
after 3 cycles.

### High-cost test: cost sub-loss should drop

```bash
FAKE_CLINE_INPUT_TOKENS=20000 FAKE_CLINE_OUTPUT_TOKENS=20000 \
PATH=/tmp/fake-cline-bin:$PATH \
    bash run-loop.sh --project-root /tmp/test-loop --wrapper-timeout 30
```

Expected: cost sub-loss=0.0 (over 32k threshold), so
weighted_sum drops by ~0.3. Other sub-losses unchanged.

### Custom stop threshold

```bash
PATH=/tmp/fake-cline-bin:$PATH \
    bash run-loop.sh --project-root /tmp/test-loop \
                     --delta 0.20 \
                     --max-stall 2 \
                     --wrapper-timeout 30
```

`--delta 0.20` means the loop needs a 20% weighted_sum
improvement per cycle (vs the default 5%). With a
deterministic fake cline, no cycle ever improves, so
`--max-stall 2` causes a stop after 2 stalls.

## What the recipe does NOT test

- **Real inner-agent behavior.** The fake cline is
  deterministic and doesn't read code, write files, or
  make tool calls. A real run is needed to verify the
  inner agent respects `AGENTS.md` hard rules
  (don't read private/).
- **Wrapper flag interactions.** The fake cline ignores
  every flag except `--cwd`. Real Cline uses
  `--auto-approve true --thinking none --json`; if those
  flags are wrong, the real run will fail differently
  than the fake.
- **Held-out grading.** The held-out grader is in
  `verifiers/private/` and is intentionally hidden. The
  fake cline doesn't exercise it.

For those, you need a real Cline run. See
`harness-scaffold/SKILL.md` for the production workflow.
