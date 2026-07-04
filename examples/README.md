# Examples

Three reading paths into the LFD bundle, depending on what
you want to do next.

| You want to… | Read this | Then this |
|---|---|---|
| **See what an LFD project looks like end-to-end** | [`lfd-system-verifier/`](./lfd-system-verifier/) (full scaffolded project) | — |
| **See a `/goal` prompt the meta-skill emits** | [`goal-prompts/slack-clone-golang.md`](./goal-prompts/slack-clone-golang.md), [`goal-prompts/cli-tool-rust.md`](./goal-prompts/cli-tool-rust.md), [`goal-prompts/algorithm-from-paper.md`](./goal-prompts/algorithm-from-paper.md) | [`goal-prompts/README.md`](./goal-prompts/README.md) for the prompt anatomy |
| **Run the LFD system against itself to prove it works** | [`lfd-system-verifier/`](./lfd-system-verifier/) | — |
| **Add your own `/goal` prompt example** | [`goal-prompts/`](./goal-prompts/) (mirror the existing three) | [`CONTRIBUTING.md` § "What we accept"](../CONTRIBUTING.md) |

## The three reading paths in one paragraph

**Path 1 — "I just want to see a working LFD project."** Jump
to [`lfd-system-verifier/`](./lfd-system-verifier/). It's a
real, runnable project: `GOAL.md` + `AGENTS.md` + `verifiers/`
+ `test-tasks/` + `skills/` + the orchestrator. Run
`./run-verification.sh` (deterministic, ~15s) and
`./run-verification-real.sh` (real agent, ~3-5 min). Both
must pass for the LFD system to be considered verified.

**Path 2 — "I want to see what `/goal` looks like before I
write one."** Read the three prompts in
[`goal-prompts/`](./goal-prompts/). Each is a complete,
paste-able `/goal` block the meta-skill would emit for a
real user goal ("build a slack clone in go", "port a CLI
from Python to Rust", "implement FlashAttention-2 from the
paper"). The README in that dir explains the prompt
anatomy so you can write your own.

**Path 3 — "I want to use LFD on my own project."** Skip the
examples. Just install the bundle (see the root README
[Quick start](../README.md#quick-start)) and tell your
agent: *"use loss function development to build X in Y
with constraints Z"*. The meta-skill loads, asks 1-3
clarifying questions, and emits a paste-able `/goal` block.
You paste it into a fresh session; the harness-scaffold
skill builds the project tree; the loop-driver runs the
loop.

## What's *not* in this directory

- **The `/goal` prompt anatomy itself.** That lives at
  `skills/meta-loss-function-development/templates/goal-prompt.md`
  — it's the template the meta-skill fills in. The three
  prompts in `goal-prompts/` are worked examples of that
  template, not the template itself.
- **The four-piece loss anatomy.** That lives at
  `skills/loss-function-design/SKILL.md` — every `/goal`
  prompt references its vocabulary (target, constraints,
  instruments, forced entropy).
- **The agent-adapter inventory.** That's at the root
  [`README.md`](../README.md#whats-in-the-box) and
  [`compatibility.md`](../compatibility.md).

## File layout

```
examples/
├── README.md                    # this file
├── lfd-system-verifier/         # the full scaffolded project (path 1 + 3)
│   ├── README.md
│   ├── GOAL.md
│   ├── AGENTS.md
│   ├── run-verification.sh
│   ├── run-verification-real.sh
│   ├── verifiers/
│   ├── test-tasks/
│   ├── skills/
│   └── logs/
└── goal-prompts/                # the three worked /goal examples (path 2)
    ├── README.md                # the prompt anatomy
    ├── slack-clone-golang.md
    ├── cli-tool-rust.md
    └── algorithm-from-paper.md
```
