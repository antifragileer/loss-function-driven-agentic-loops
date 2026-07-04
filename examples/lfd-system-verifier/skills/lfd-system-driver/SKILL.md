---
name: lfd-system-driver
description: |
  The candidate skill the LFD system verifier expects the
  inner agent to produce. This file is intentionally
  minimal — the verifier tests the loop, not the agent's
  ability to write sophisticated skills. The fake-agent
  wrapper writes a stub `candidate.md` to the iteration
  dir; the loop's "install the candidate" step copies it
  to `skills/lfd-system-driver/SKILL.md` (this file).
version: 1.0.0
author: open source
license: MIT
metadata:
  hermes:
    tags: [lfd, system-verifier, candidate, dogfood]
---

# LFD System Driver (candidate skill)

This is the candidate skill the LFD system verifier
expects the inner agent to produce. The verifier tests
the loop, not the agent's ability to write sophisticated
skills — the fake-agent wrapper writes a stub
`candidate.md` to the iteration dir, and the loop's
"install the candidate" step copies it here.

## What the loop does with this file

1. `cycle.sh` invokes `fake-wrapper.sh` which writes
   a stub `candidate.md` to the iteration dir.
2. `cycle.sh` invokes `run-design-set.sh` which runs the
   5 design tasks; each task's wrapper also writes a
   `candidate.md` to its per-task dir.
3. `cycle.sh` calls the "install the candidate" step,
   which uses the `<runtime>-skills-dir.sh` instrument to
   find the agent's skills dir, then copies the
   cycle-level `candidate.md` to that dir as
   `<artifact-name>/SKILL.md` (this file).
4. The next cycle's design tasks can then read this file
   from the agent's skills dir.

## Why the verifier doesn't need a real candidate

The verifier uses the **fake-agent** adapter, which has
no model and no network. The "candidate" the wrapper
writes is a fixed 10-line stub. The loop's sub-loss
scorer grades the cycle's overall fitness (correctness,
performance, safety, legibility, invariants, drift, cost)
based on the cycle's JSON output, not on the candidate's
content.

For the LFD system verifier, the candidate exists to
satisfy the loop's contract (every cycle must produce
a candidate that the next cycle can read). The agent's
ability to produce a *good* candidate is not under test.

## See also

- `verifiers/fake-wrapper.sh` — the deterministic
  stub
- `verifiers/run-design-set.sh` — the per-task driver
- `verifiers/compute_sub_losses.py` — the per-cycle
  scorer
- `../run-verification.sh` — the orchestrator
