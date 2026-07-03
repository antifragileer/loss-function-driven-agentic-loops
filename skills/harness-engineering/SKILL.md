---
name: harness-engineering
description: |
  The "harness engineering" playbook, distilled from Ryan Lopopolo's
  OpenAI post ("Harness engineering: leveraging Codex in an agent-first
  world", 2026-02-11) and from the @elvissun X post + diagram about
  the turbo cache loop. Load this skill whenever designing, reviewing,
  or critiquing the *harness* (context, tools, scaffolding, feedback
  loops) that an agentic development loop runs inside. The
  loss-function designer's job is to *co-design* with this — see the
  loss-function-design skill.
version: 2.0.0
author: open source
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [harness, agentic, codex, feedback-loops, loss-functions]
    related_skills: [loss-function-design, cline-orchestration]
---

# Harness Engineering — Playbook

This is the *harness* side of the loop. It is what the agent
sees: the context it gets, the tools it can call, the verifiers
it has to satisfy, the scaffolding it lives in. The companion
`loss-function-design` skill is what the *driver* of the loop
sees: the objective the agent is optimizing against. The two
are designed together; this skill is the half that the loss
function calls into.

The image at `references/turbo-cache-loop-diagram.png` is the
canonical worked example.

## Core principles

1. **Humans steer. Agents execute.** The engineer's job becomes
   designing environments, specifying intent, and building
   feedback loops. Coding is what the agent does.
2. **Give the agent a map, not a 1,000-page instruction manual.**
   A short top-level context file (`AGENTS.md` / `.hermes.md` /
   `CLAUDE.md`, ~100 lines) that points to a structured `docs/`
   tree.
3. **Application legibility is the goal.** Anything the agent
   can't access in-context while running effectively doesn't
   exist. Push tribal knowledge into the repo.
4. **Enforce invariants, not implementations.** Strict layered
   architecture, validated dependency directions, custom
   linters with remediation-injecting error messages.
5. **The harness and the loss are co-designed.** A new loss
   component needs a new tool, a new context pointer, or a new
   verifier script — treat those as the same change set.
6. **The loop is the product, not the candidate.** The harness
   enables long autonomous runs (6+ hours is the OpenAI norm).
   The loss function is what gives those runs gradient.

## What "good" looks like — the Elvis turbo cache loop (the worked example)

The image at `references/turbo-cache-loop-diagram.png` is the
canonical example. Decomposed:

### Step 1 — Give the agent eyes

Two side-by-side surfaces, both with mechanical access:

- **Local:** `turbo dry-run --filter=web`, `turbo build
  --summarize`, `turbo build --output-logs`, `git worktree add
  ../exp-N`.
- **Cloud:** `vercel inspect <id> --logs`, `vercel ls --scope
  press-pulse`, `vercel env pull`.

The crucial detail: **each experiment is an isolated branch,
with a clean `node_modules` and no cross-contamination**. The
agent can run N hypotheses in parallel without any of them
seeing each other's mutation. This is the legibility *of the
experiment space*, not just the codebase.

For the loss-function-developer: when designing a loss, the
*inputs* the loss reads must come from a per-experiment
isolated surface. If the agent's hypothesis and the verifier's
measurement share global state, the loss will be a function of
cross-contamination, not of hypothesis quality.

### Step 2 — Drop it in a loop

Single box: `hypothesis` → `test` → `result` → loops back to
`hypothesis`. Sub-text: "agent drives the loop / i watch from
telegram". The human is a *passive observer* on a chat surface.

For the loss-function-developer: the loss is the *transition
function* from `(hypothesis, test)` to `result`. A loss that is
too noisy on the transition will cause the loop to spiral. A
loss that is too permissive will cause mode collapse. The shape
of the loss is what makes the loop converge.

### Step 3 — What the agent actually did (3-column trace)

| Hypothesis                                  | Test                                              | Result                                                    |
|---------------------------------------------|---------------------------------------------------|-----------------------------------------------------------|
| globalEnv is poisoning hashes               | change VERCEL_URL alone, dry-run both worktrees   | formula hash changed. confirmed. ✓                        |
| removing it fixes all packages              | remove from globalEnv, dry-run again              | upstream fixed. web still changes. X                      |
| framework inference is re-injecting it      | dry-run with `--framework-inference=false`        | hash stable. second root cause found. ✓                   |
| deterministic build commands fix cloud too  | push branch, deploy preview x2, compare logs      | cache hit. done. ✓                                        |

Note: hypothesis 2 *fails* and the loop continues. The loss
function is the thing that *generated* the "X" in hypothesis 2
and the "✓" in hypotheses 1, 3, 4. A binary pass/fail is enough
here; in a more complex loss, the partial credit is the
gradient that drives the hypothesis refinement.

### Step 4 — Result

Before: 0 cached / 5 total, 3m 22s/deploy. After: 1 cached / 2
total, 34s/deploy. The 6× speedup is the *outcome* the loss
function is ultimately graded against. The two root causes
(`NEXT_PUBLIC_VERCEL_URL in globalEnv`, `Next.js framework
inference`) are the *discoveries* the loss function made
possible.

## The OpenAI playbook (the longer pattern)

### Repository as the system of record

The "empty repo, 1.5K PRs, ~1M LOC, 5 months, 3 (now 7) engineers,
3.5 PRs/engineer/day" is the throughput the harness is
supposed to enable. It is reachable only if the repo *itself*
is the agent's universe.

```
AGENTS.md                # short — the table of contents
ARCHITECTURE.md          # top-level map of domains + package layering
docs/
├── design-docs/
│   ├── index.md
│   ├── core-beliefs.md
│   └── ...
├── exec-plans/
│   ├── active/
│   ├── completed/
│   └── tech-debt-tracker.md
├── generated/
│   └── db-schema.md
├── product-specs/
│   ├── index.md
│   ├── new-user-onboarding.md
│   └── ...
├── references/          # llms.txt-style external system specs
│   ├── design-system-reference-llms.txt
│   ├── nixpacks-llms.txt
│   ├── uv-llms.txt
│   └── ...
├── DESIGN.md
├── FRONTEND.md
├── PLANS.md
├── PRODUCT_SENSE.md
├── QUALITY_SCORE.md
├── RELIABILITY.md
└── SECURITY.md
```

The loss-function-developer should expect — and require — the
project this profile works in to have a layout like this. If
it doesn't, that is the first thing to suggest adding.

### AGENTS.md as a table of contents, not an encyclopedia

> "Context is a scarce resource. A giant instruction file
> crowds out the task, the code, and the relevant docs — so
> the agent either misses key constraints or starts optimizing
> for the wrong ones. Too much guidance becomes non-guidance.
> It rots instantly. It's hard to verify."

Concretely:

- 100-ish lines.
- Pointers into `docs/` and into the layer-architecture
  diagram.
- Mechanical linters + CI jobs that check freshness,
  cross-links, and structure. A "doc-gardening" agent that
  opens fix-up PRs.

### Application legibility (UI / observability)

- **Per-worktree bootable app.** One app instance per worktree.
  Each lives, breaks, gets fixed, and is torn down with the
  worktree.
- **Chrome DevTools Protocol wired into the agent runtime.**
  Skills for DOM snapshots, screenshots, navigation. The agent
  can reproduce a bug by clicking through the app.
- **Ephemeral local observability stack per worktree.** Vector
  → Victoria Logs/Metrics/Traces, queryable via LogQL / PromQL
  / TraceQL. Prompts like "ensure service startup completes in
  under 800ms" become tractable.

For the loss-function-developer: each of these is a *signal
source* the loss can read. UI snapshots → correctness loss.
P50/P99 spans → performance loss. Browser console errors →
reliability loss. The *legibility* of the system is what
bounds the *expressiveness* of the loss.

### Enforce invariants, not implementations

> "By enforcing invariants, not micromanaging implementations,
> we let agents ship fast without undermining the foundation."

Per-domain layered architecture (Types → Config → Repo → Service
→ Runtime → UI), validated dependency directions, a single
explicit interface for cross-cutting concerns (Providers).
Custom linters whose error messages inject remediation
instructions into agent context.

> "In a human-first workflow, these rules might feel pedantic or
> constraining. With agents, they become multipliers: once
> encoded, they apply everywhere at once."

The loss-function-developer reads this as: the loss should
grade *invariant satisfaction* (does the candidate respect the
architecture?) not *implementation style* (does it use Zod
vs. io-ts?). Style losses are mode-collapse bait.

### Entropy and garbage collection

> "Codex replicates patterns that already exist in the
> repository — even uneven or suboptimal ones. Over time, this
> inevitably leads to drift."

Background tasks (Codex or another agent) that scan for
deviations, update quality grades, open targeted refactoring
PRs. "Most of these can be reviewed in under a minute and
automerge."

For the loss-function-developer: this is the *negative loss* —
the component that penalizes drift from the golden principles.
It needs its own verifier (a deviation scanner) and its own
reward (a "this PR reduced deviation count by N" signal).

### End-to-end autonomy (recently crossed)

The OpenAI post notes the agent can now, given one prompt:

1. Validate the current state of the codebase
2. Reproduce a reported bug
3. **Record a video demonstrating the failure**
4. Implement a fix
5. Validate the fix by driving the application
6. **Record a video demonstrating the resolution**
7. Open a PR
8. Respond to agent and human feedback
9. Detect and remediate build failures
10. Escalate to a human only when judgment is required
11. Merge the change

The "record a video" steps are not decoration. They are a
*loss function input* — visual diff between failure and
resolution is one of the cleanest correctness signals
available. The loss-function-developer should treat video /
DOM / log artifacts as first-class loss inputs.

## The Ralph Wiggum Loop

> "Review its own changes locally, request additional specific
> agent reviews both locally and in the cloud, respond to any
> human or agent given feedback, and iterate in a loop until
> all agent reviewers are satisfied."

The agent's reviewer pool is itself a small ensemble of agents
with different loss components. The agent's "satisfied" state
is a conjunction of those sub-losses all passing. The
loss-function developer designs the sub-losses and the
conjunction operator.

## Anti-patterns (avoid)

- **One big AGENTS.md.** (See above.)
- **Reward hacking via probe-style scoring.** "Does the JSON
  parse?" instead of "does the data shape match the boundary
  contract?" The agent will learn to emit JSON that parses but
  is wrong.
- **Style losses.** Penalize implementation choice, not
  invariant violation. The agent will converge on a bland but
  valid style that maximizes the style loss.
- **Hidden state in the verifier.** If the verifier reads from
  a global cache the agent can mutate, the loss is a function
  of cache contents, not candidate quality. (The Elvis loop's
  "isolated worktree" rule is the defense.)
- **Slow verifiers.** A 30-minute verifier on a 6-hour loop is
  a single point of failure. The verifier budget must fit
  inside the loop budget with margin.
- **Non-deterministic verifiers.** If the same candidate
  scores differently on two runs, the loop is not a function
  — it's a random walk. LLM judges are non-deterministic;
  treat them as a last resort and version them.
- **Single monolithic loss.** A 0–1 number that hides which
  sub-loss is failing is undebuggable. Decompose.
- **Human in the active loop.** The Elvis post is explicit:
  "i watch from telegram". The human is a *passive observer*,
  not a step in the loop. If the loop blocks on a human, it is
  not a loop, it is a meeting.

## User-style preferences (load these into every reply)

This skill is often loaded for short Q&A or work that the
user wants to direct. When the user is in the loop:

- **Default to code, not prose.** When the user asks "what
  would happen" or "give me the prompt," they want a runnable
  artifact they can paste. Lead with the code, follow with
  one paragraph of context if needed.
- **Don't burn a turn on three setup questions.** When a
  project is greenfield or under-specified, pick reasonable
  defaults and just start. State the defaults in
  `README.md` so they're easy to change later. The user
  has explicitly stated this preference.
- **Match the answer format to the question format.** A
  one-sentence question gets a one-sentence answer. A
  "show me the code" request gets code. The format the
  user asks for is a binding contract.
- **Verify before claiming live.** An async-dispatch return
  value (e.g. a `delegate_task` receipt) is a *receipt*, not
  proof of work. Before reporting a dispatched loop as live,
  observe a file artifact, a score, or an explicit failure
  message. See `references/verification-gate.md` for the
  diagnostic recipe.

## How this skill is used

This skill is loaded:

- When the user asks for a harness review.
- When the user asks the loss-function-developer to *co-design*
  with the harness side.
- When the user wants to know what the agent will and won't
  see.
- Whenever the working project has (or should have) an
  `AGENTS.md` / `docs/` / `exec-plans/` layout.

The companion `loss-function-design` skill loads the other half
of the playbook. The `cline-orchestration` skill is the
surface for driving a Cline-based loop (Hermes → Cline →
model); for other agent runtimes, the same pattern applies
with that agent's CLI flags substituted.

## References in this skill

- `references/turbo-cache-loop-diagram.png` — the canonical
  worked example diagram.

## Related skills (install separately)

- `loss-function-design` — the loss-function side: target,
  constraints, instruments, forced entropy.
- `cline-orchestration` — driving a Cline-based loop
  (substitute your own agent orchestration if not using
  Cline).
