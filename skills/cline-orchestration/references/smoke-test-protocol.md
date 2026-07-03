# Smoke-Test Protocol

Before claiming a loss-function loop cycle is "good", run
this 5-minute smoke test. The full loop burns hours and
tokens; a failed smoke test saves you a 200k-token debug
session.

## The smoke test

1. **Pick the cheapest design task** (typically the one with
   the smallest input file and the simplest grader).
2. **Run the wrapper once** on that task, no candidate
   skill installed, baseline pass.
3. **Read the wrapper's emitted JSON.** Confirm every field
   you expect is present: `cycle`, `exit_code`,
   `elapsed_seconds`, `cline_duration_ms`, `tokens`, `model`,
   `provider`, `candidate_text`, `tool_calls`,
   `finish_reason`, `iterations`, `raw_output_path`. A missing
   field is a schema drift that will silently break the
   sub-loss readout later.
4. **Run the per-task grader** on the wrapper's
   `raw_output_path` (the iter dir). Confirm it
   accept/rejects correctly. Read the grader's stdout/stderr
   — the reason it fails is more important than the failure
   itself.
5. **Run the design-set script** with the same task only
   (temporarily edit the TASKS list to include just the
   smoke-test task). Confirm `logs/design-set-score.json`
   has the right shape: `cycle`, `n_pass`, `n_total`,
   `pass_rate`, `total_tokens`, `total_seconds`,
   `per_task[]`.
6. **Run the sub-loss readout** on the cycle's
   `cycle-summary.json`. Confirm it returns a JSON object
   with `sub_losses`, `weights`, `gates`, `weighted_sum`,
   `weighted_total`, `weighted_normalized`, `gates_passed`.

If any of those six checks fail, the harness is broken. Fix
the harness before dispatching the loop. **Do not dispatch
with a broken harness** — the subagent will burn 200k
tokens discovering the bug.

## What "passes" looks like

```
$ cline-wrapper.sh "create hello.txt" --cwd /tmp/smoke --cycle smoke
{
  "cycle": "smoke",
  "exit_code": 0,
  "elapsed_seconds": 12,
  "cline_duration_ms": 11432,
  "tokens": 28943,
  "model": "<active-model>",
  "provider": "<active-provider>",
  "candidate_text": "Created /tmp/smoke/.iterations/smoke/hello.txt with content 'hello world'.",
  "tool_calls": [],
  "finish_reason": "completed",
  "iterations": 3,
  "raw_output_path": "/tmp/smoke/.iterations/smoke/cline.json"
}
$ cat /tmp/smoke/hello.txt
hello world
$ ./verifiers/instruments/sub-loss-readout.sh /tmp/smoke/.iterations/smoke/cycle-summary.json | jq .weighted_normalized
0.93
$ ./verifiers/instruments/sub-loss-readout.sh /tmp/smoke/.iterations/smoke/cycle-summary.json | jq .gates_passed
true
```

## What "broken" looks like

| Symptom                                         | Likely cause                                    | Fix                                                      |
|-------------------------------------------------|-------------------------------------------------|----------------------------------------------------------|
| `tokens: 0` despite long wall-clock            | parser undercounts; `run_result.aggregateUsage` shape changed | patch `scripts/parse_cline_output.py` |
| `finish_reason: "error"` and empty `candidate_text` | upstream rejected the request (provider, `--thinking`) | change `--thinking` level; re-verify provider config |
| `gates_passed: false` but every sub-loss is 1.0 | `int(field or 1)` falsy-zero bug                  | use `is None` default, not `or 1`                       |
| Grader says PASS on the *parent* dir, not the iter dir | grader `find`-walks up to a previous cycle | grader uses `$ITER_DIR/<file>` exact path              |
| Wrapper exits 0 but `run_result.text` is `"Invalid request Error"` | request shape rejected upstream | inspect `cline.stderr`; re-verify provider matrix |

## When the smoke test fails

1. **Read the table above.** Most harness bugs match one of
   those rows.
2. **Patch the harness, not the smoke test.** The smoke
   test is the spec.
3. **Re-run the smoke test after every patch.** A patch that
   fixes one field often breaks another (e.g., switching
   from `or 1` to `is None` defaults also changes the
   `int()` call signature).
4. **Re-dispatch the loop only after the smoke test passes
   three times in a row.** Variance is real; the smoke test
   needs to be reproducible.

## Why this matters

A failed smoke test is a 5-minute problem. A failed
subagent dispatch against a broken harness is a 30-minute
problem at best, a 6-hour problem at worst. The cost ratio
is 1:36 minimum. Always smoke-test before dispatch.
