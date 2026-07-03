# Subagent Dispatch Gotchas

When this skill's driver dispatches a subagent (via a delegation
primitive, a `claude`/`codex`/`cline` headless run, or any
other "fire-and-forget work" mechanism) to run a long task like
a loss-function loop, the dispatch is asynchronous. The
synchronous return is a receipt — it does **not** mean the work
is happening. The worker's result will re-enter the
conversation as a separate message later. This file documents
the failure modes.

## Symptom: dispatch returns a receipt, but nothing happens

What was observed:
- `delegate_task(goal=..., context=...)` (or the equivalent)
  returned `{"status": "dispatched", "delegation_id": "..."}`
  immediately.
- The parent session continued without blocking (the
  background mode is the default).
- 7+ minutes later: no files written by the subagent, no
  session entry visible from the parent, no error message,
  no follow-up turn.
- The goal was incorrectly reported as "complete" based on
  the synchronous return alone.

Why this happens: the parent session's reply happens *before*
the subagent's first tool call. The parent must observe some
artifact of the subagent's work (a file, a session entry, a
score, or a failure message) before it can claim the dispatched
task is making progress.

## Verification rule: what counts as "the subagent is running"

Before reporting a dispatched task as live or complete, the
parent MUST observe at least one of:

- (a) **A file the subagent must have written** exists with
  the expected mtime. For a loss-function loop, that means
  the project's `skills/` and `logs/` files.
- (b) **A score artifact** — for a loop, a fresh score file
  newer than the dispatch time.
- (c) **An explicit failure message** in the conversation
  from the subagent's first turn.

A delegation id alone is *not* evidence. Neither is a session
list showing the parent session (the parent session is always
there, regardless of the subagent's state).

## Diagnostic recipe (when verification fails)

Run these in order. None of them modify state — they're
read-only.

```bash
# 1. Is there a record of the delegation?
# (the command depends on your agent runtime; the goal is
# to see whether any other session is alive)
ps auxww | grep -E "agent|worker" | grep -v grep | head -10

# 2. Did the subagent write its expected files?
ls -la <project>/skills/ 2>/dev/null
ls -la <project>/logs/ 2>/dev/null

# 3. Are any files newer than the dispatch time?
# (substitute the actual dispatch time)
find <project> -newermt "YYYY-MM-DD HH:MM:SS" -type f 2>/dev/null

# 4. Is the held-out path locked?
ls -la <project>/verifiers/private/ 2>/dev/null
```

If step 1 shows no worker process, step 2 shows the expected
files are still empty, step 3 shows no new files since
dispatch, and step 4 shows the private grader is intact,
then the subagent **never produced observable state**. Treat
the dispatch as failed.

## What to do when the dispatch is failed

1. **Re-dispatch, smaller.** Instead of a 24-hour task, give
   the subagent a 30-minute / 30k-token budget to write *one*
   candidate artifact and produce *one* score. This narrows
   the failure surface and gives you an artifact to inspect
   even if the loop doesn't converge.
2. **Set an explicit deadline.** Ask the subagent to print
   "DONE" with a final summary path at the end. Then in the
   parent, set a 5-minute poll after dispatch and check that
   file. If it's not there, treat as failed.
3. **Don't compound the failure by claiming the prior
   dispatch worked.** Re-verify from scratch each time. The
   delegation id from a prior turn is a receipt, not proof
   of work.

## Why this is class-level, not a one-off

Any subagent dispatched for loop work will hit this pattern.
The fix is in the dispatch protocol itself, not the task.
Future sessions that dispatch subagents for loop work should:

- Always treat the synchronous return as "the request was
  accepted" — not "the work has started."
- Build a verification gate into the parent's report-back: a
  subagent that produces no observable file within 5 minutes
  of dispatch is treated as failed.
- Prefer smaller, verifiable dispatches over large
  "fire-and-forget" ones. The cost of a re-dispatch is much
  less than the cost of an undetected silent failure.

## Related

- `cline-wrapper-contract.md` — the wrapper that the
  subagent invokes, the part that is verifiable.
- `verifier-script-gotchas.md` — class-level pitfalls in the
  verifier scripts the subagent depends on.
- The `cline-orchestration` SKILL.md, "Pitfalls when driving
  Cline" section, for the bullet on delegation return
  values.
