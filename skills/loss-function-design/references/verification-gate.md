# Verification Gate — diagnostic recipe

When you have dispatched async work (a subagent, a background
shell, a CI run) and need to verify it is making progress, run
these checks in order. None modify state.

This is the cross-reference from `loss-function-design`'s
"User-style preferences" section. The full skill is
`async-dispatch-verification`; this is the diagnostic recipe
extracted.

## Step 1 — Is the worker process actually running?

```bash
ps auxww | grep -E "agent|worker|<worker binary>" | grep -v grep | head -10
```

If empty: the worker never started or it crashed. Dispatch
failed.

## Step 2 — Did the worker write its expected files?

```bash
ls -la <project>/<expected-artifact-dir>/ 2>/dev/null
```

If empty or files missing: worker crashed mid-task.

## Step 3 — Are any files newer than the dispatch time?

```bash
find <project> -newermt "YYYY-MM-DD HH:MM:SS" -type f 2>/dev/null
```

**The only check that catches "worker is running but spinning
on a bad prompt."** If no files touched since dispatch, the
worker is alive but unproductive.

## Step 4 — Is there a session/queue entry?

```bash
hermes sessions list 2>&1 | tail -20
```

If empty: the worker never produced observable state. Treat
the dispatch as failed.

## Decision tree

```
Worker process? (1) ─ No  → Dispatch failed. Re-dispatch, smaller.
              Yes
                  │
New files since dispatch? (3) ─ No  → Worker stuck. Kill, re-dispatch.
                          Yes
                              │
Expected artifacts present? (2) ─ No  → Worker progressing on
                              │        something else. Inspect.
                              Yes
                                  │
                                  Artifacts have right shape?
                                  ├── No  → Schema drift. Patch, re-dispatch.
                                  └── Yes → Worker is live. Report.
```

## How long to wait

Set the polling interval to 1-2× the worker's work-unit
time:

| Work unit     | Polling interval |
|---------------|------------------|
| <1 min        | 1-2 min          |
| 1-10 min      | 5-10 min         |
| 10-60 min     | 15-30 min        |
| 1-6 hours     | 30-60 min        |
| 6+ hours      | 1-2 hours        |

## The receipt is not proof

A `delegation_id`, a background PID, a session list entry — none
of these prove the work is happening. The receipt is generated
*before* the work. Only an observable side effect (a file, a
score, a log line) is proof. Default to "still working" not
"complete" until the artifact exists.
