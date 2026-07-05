# 0x278's Loss Function Driven Development Skills

A drop-in skill bundle for **loss-function-driven (LFD)
agentic loops** — turn a high-level goal into a
paste-able `/goal` prompt, scaffold a harness, and run the
outer loop until the inner agent's skill converges.

The bundle ships **11 cooperating skills** that implement
the LFD pattern, with **6 agent-adapter skills** so the same
loop works against Cline, Claude Code, Codex, Hermes Agent,
OpenCode, or the deterministic `fake-agent` stub used for
dogfood testing (see `examples/lfd-system-verifier/`).

<p align="left">
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="License: MIT" /></a>
  <a href="https://github.com/antifragileer/loss-function-driven-agentic-loops/releases"><img src="https://img.shields.io/github/v/release/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="Latest release" /></a>
  <a href="https://github.com/antifragileer/loss-function-driven-agentic-loops/stargazers"><img src="https://img.shields.io/github/stars/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="Stars" /></a>
  <a href="https://github.com/antifragileer/loss-function-driven-agentic-loops/network/members"><img src="https://img.shields.io/github/forks/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="Forks" /></a>
  <a href="https://github.com/antifragileer/loss-function-driven-agentic-loops/commits/main"><img src="https://img.shields.io/github/last-commit/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="Last commit" /></a>
  <a href="https://github.com/antifragileer/loss-function-driven-agentic-loops/issues"><img src="https://img.shields.io/github/issues/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="Open issues" /></a>
  <a href="https://github.com/antifragileer/loss-function-driven-agentic-loops/pulls"><img src="https://img.shields.io/github/issues-pr/antifragileer/loss-function-driven-agentic-loops?style=flat-square" alt="Open PRs" /></a>
</p>

- **Repository:** https://github.com/antifragileer/loss-function-driven-agentic-loops
- **License:** MIT
- **Bundle version:** 2.2.0
- **Install (Hermes, per-profile):** `./install.sh ~/.hermes/profiles/<name>`
- **Install (universal / non-Hermes agents):** `npx skills add antifragileer/loss-function-driven-agentic-loops`

---

## What is Loss Function Driven Development?

Imagine you are trying to throw a paper ball into a trash can. If you miss,
you learn *how* you missed — too far left, too short, too much spin — and
you adjust your next throw. **Loss Function Driven Development (LFD)** is the
same idea, but for building software.

A "loss function" is just a fancy score that says, "How far away from the
goal is this attempt?" The lower the score, the better. In LFD, we write
down the goal, the rules, and a clear way to measure each try. Then we
loop:

1. **Try** — let the coding agent attempt the task.
2. **Score** — check how close it got.
3. **Adjust** — use the score to guide the next attempt.
4. **Repeat** until the score is good enough.

If the agent gets stuck, we add a little "forced entropy" — a small, random
nudge, like shaking the paper ball — to break out of a rut. The whole point
is to turn fuzzy goals into a scoreboard the agent can keep trying to beat.

---

## What's in the box

| Skill | Version | Role | Required? |
|---|---|---|---|
| [`loss-function-design`](./skills/loss-function-design) | 2.0.0 | The 4-piece loss anatomy (target / constraints / instruments / forced entropy) | yes |
| [`harness-engineering`](./skills/harness-engineering) | 2.0.0 | What the agent sees: context, tools, scaffolding, observability | yes |
| [`cline-orchestration`](./skills/cline-orchestration) | 2.0.0 | **Agent adapter** — Cline v3.0.34+ | optional |
| [`claude-code-orchestration`](./skills/claude-code-orchestration) | 1.0.0 | **Agent adapter** — Claude Code v2.x (Anthropic) | optional |
| [`codex-orchestration`](./skills/codex-orchestration) | 1.0.0 | **Agent adapter** — Codex CLI v1.x (OpenAI) | optional |
| [`hermes-agent-orchestration`](./skills/hermes-agent-orchestration) | 1.0.0 | **Agent adapter** — Hermes Agent v2.x (provider-agnostic) | optional |
| [`opencode-orchestration`](./skills/opencode-orchestration) | 1.0.0 | **Agent adapter** — OpenCode v1.x (provider-agnostic) | optional |
| [`fake-agent-orchestration`](./skills/fake-agent-orchestration) | 1.0.0 | **Agent adapter** — deterministic stub for dogfood testing | optional |
| [`meta-loss-function-development`](./skills/meta-loss-function-development) | 1.1.0 | The meta-skill — builds the harness with you, then emits the `/goal` prompt | yes |
| [`harness-scaffold`](./skills/harness-scaffold) | 1.1.0 | Build tool — scaffolds the directory tree (used by the meta-skill, not the loop) | yes |
| [`loop-driver`](./skills/loop-driver) | 1.1.0 | Runtime — runs the outer loop against a finished harness until a stop condition fires | yes |

The 6 required skills (3 core: `loss-function-design`,
`harness-engineering`, `meta-loss-function-development`; 2
runtime: `harness-scaffold`, `loop-driver`) implement
the LFD pattern. The 6 agent-adapter skills are
siblings — pick one when you scaffold a project, and the
loop runs against it. The `harness-scaffold` and
`loop-driver` skills are runtime-agnostic; they call
whatever wrapper `verifiers/<runtime>-wrapper.sh`
points to.

See [`compatibility.md`](./compatibility.md) for the
version matrix and the adapter contract for new coding
agents.

---

## Install

There are two install paths. Pick by how you use the
bundle:

| Use case | Install path | Where it lands |
|---|---|---|
| **Multiple Hermes profiles, want per-profile isolation** (the bundle's primary design) | `./install.sh <profile-dir>` | `~/.hermes/profiles/<name>/skills/` (only that profile) |
| **One Hermes profile, or you also use Claude Code / Cline / Codex / Cursor / etc.** | `npx skills add antifragileer/loss-function-driven-agentic-loops` | `~/.agents/skills/` (universal store, all profiles see it; symlinks also created in `~/.claude/skills/`) |

### Option A: per-Hermes-profile (recommended for multi-profile users)

The bundle's primary design is profile-scoped: each
Hermes profile (`~/.hermes/profiles/<name>/`) has its
own `skills/` directory, and the bundle's skills only
load for the profile that has them. `./install.sh`
writes to *one* profile at a time, which is the safe
default for users running more than one profile.

```bash
git clone https://github.com/antifragileer/loss-function-driven-agentic-loops.git
cd loss-function-driven-agentic-loops
./install.sh ~/.hermes/profiles/<your-profile>     # install
./install.sh --check ~/.hermes/profiles/<your-profile>   # verify
./uninstall.sh ~/.hermes/profiles/<your-profile>   # remove
```

For full per-profile operations (listing skills, the
held-out grader format, the verifier scripts), see the
[Quick start](#quick-start) below.

### Option B: universal store via `npx skills` (for single-profile or non-Hermes agents)

The bundle is also published to **[skills.sh](https://skills.sh/)**.
The `npx skills` CLI installs all 11 skills into the
universal store, which Hermes reads *in addition* to
the per-profile `skills/` directory (Hermes walks both
paths at load time), and which Claude Code, Cline,
Codex, Cursor, GitHub Copilot, Windsurf, Gemini, and
OpenCode all read natively. The universal store is
**shared across all Hermes profiles** — if you have
more than one, every profile will see these skills.

```bash
# One-shot install of all 11 skills
npx skills add antifragileer/loss-function-driven-agentic-loops -y -g

# Install only specific skills (repeat -s for each)
npx skills add antifragileer/loss-function-driven-agentic-loops \
  -s loss-function-design -s loop-driver -y -g

# List what's available in the bundle without installing
npx skills add antifragileer/loss-function-driven-agentic-loops --list
```

After install, the skills are at `~/.agents/skills/`
(universal store, with symlinks in `~/.claude/skills/`
for Claude Code). To remove:

```bash
npx skills remove -y -g loss-function-design loop-driver \
  meta-loss-function-development harness-scaffold \
  harness-engineering cline-orchestration \
  claude-code-orchestration codex-orchestration \
  hermes-agent-orchestration opencode-orchestration \
  fake-agent-orchestration
```

There is **no per-profile removal** for the npx path —
removing from the universal store removes from every
profile. If you need per-profile control, use Option A.

A skill page also appears on
<https://www.skills.sh/antifragileer/loss-function-driven-agentic-loops>.

### Which option should I pick?

- **One Hermes profile, or you also use Claude Code /
  Cline / Codex / Cursor / etc.** → Option B
  (`npx`). Less to copy-paste, works for every
  agent at once.
- **Multiple Hermes profiles and you want the LFD
  skills in *some* profiles but not *others*** →
  Option A (`./install.sh`). The npx path can't
  distinguish between profiles.
- **You want to bump to a new bundle version
  surgically** → Option A. `./install.sh --force`
  overwrites the 11 skills in one profile; the
  universal store update happens on the next
  `npx skills add` with `--upgrade`.
- **CI / headless** → Option A. `install.sh` is
  pure bash, no Node, no network on every run
  (after clone).

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/antifragileer/loss-function-driven-agentic-loops.git
cd loss-function-driven-agentic-loops

# 2. List the skills
./install.sh --list

# 3. Install into a Hermes profile (e.g. your default profile)
./install.sh ~/.hermes/profiles/default

# 4. Verify
./install.sh --check ~/.hermes/profiles/default

# 5. Open a session under that profile and ask for a /goal
#    prompt. The phrase the meta-skill triggers on is a
#    spec-shaped request, not an execution-shaped one:
#
#      "Create a /goal prompt that builds X in Y with Z."
#      "Produce a /goal prompt for the spec in
#       /path/to/implementation.md."
#      "Turn /path/to/spec.md into a /goal prompt."
#
#    The meta-skill loads, asks 1-3 clarifying questions
#    (target / constraints / runtime), and emits a
#    paste-able /goal block.
#
#    DO NOT say "use LFD to build X" or "use loss function
#    development to build X" — those phrases are
#    execution-shaped. The meta-skill's auto-trigger
#    description is intentionally narrow: it loads on
#    spec-shaped phrases only. An execution-shaped phrase
#    loads harness-scaffold + loop-driver instead, which
#    start the loop in the current session and you never
#    get a /goal block to paste.
#
# 6. Paste the /goal prompt into a fresh session; the loop
#    scaffolds and runs.
```

To uninstall:

```bash
./uninstall.sh ~/.hermes/profiles/default
```

---

## New here? Read this first

Before installing, decide what you want out of the bundle:

- **"Show me what a working LFD project looks like."** →
  [`examples/lfd-system-verifier/`](./examples/lfd-system-verifier/)
  is a complete scaffolded project. Run its
  `run-verification.sh` (15s, deterministic) and
  `run-verification-real.sh` (3-5 min, real agent) to see
  the LFD loop in action.
- **"Show me a `/goal` prompt the meta-skill would emit."**
  → [`examples/goal-prompts/`](./examples/goal-prompts/)
  has three worked examples (slack clone in Go, Python-to-
  Rust port, FlashAttention-2 from the paper) plus the
  prompt anatomy so you can write your own.
- **"How do I make a great harness (not just a working
  one)?"** → [`BUILDING-A-GREAT-HARNESS.md`](./BUILDING-A-GREAT-HARNESS.md)
  is the manual for the human-in-the-loop at V0→V1
  (expanding the AI's first draft) and V1→V2+ (iterating
  on the harness while the loop runs).
- **"Just install it, I'll figure it out."** → skip to
  [Quick start](#quick-start) below.

The full on-ramp (all three reading paths) is at
[`examples/README.md`](./examples/README.md).

---

## How it works

The LFD pattern turns a high-level goal into an iterated
search over a candidate skill:

1. **Goal → /goal prompt.** `meta-loss-function-development`
   takes your plain-language goal and emits a paste-able
   `/goal` prompt that contains: target, constraints,
   runtime, instruments, held-out task source, and stop
   conditions.

2. **/goal prompt → project tree.** `harness-scaffold` reads
   the `/goal` prompt and scaffolds a complete project:
   `verifiers/`, `instruments/`, `test-tasks/`, `AGENTS.md`,
   `GOAL.md`, the per-iteration directory, and a wrapper
   script for the chosen coding agent.

3. **Per-iteration loop.** `loop-driver` reads the
   iteration log, forms a hypothesis, invokes the inner
   agent via the wrapper, runs the design set, scores the
   cycle with a 7-sub-loss scorer, applies forced entropy
   on stall, and stops on success / wall-clock / tokens /
   plateau. The success threshold (2 consecutive
   pass_rate=1.0 cycles by default) is configurable
   via the `--success-after` flag.

The driver layer is **runtime-agnostic**. The 6 agent
adapters are siblings; pick one when you scaffold, and the
loop runs against it. To add a new coding agent, write a
new adapter skill with the same shape and the loop
supports it.

The quality of the result is a near-direct function of
the quality of the harness. A plain `/goal` prompt gives
you one shot. A great harness gives the loop a measurable
loss function and a held-out grader the agent can't game.
For a manual on what makes a harness great — including
the V0→V1 expansion checklist and the V1→V2+ iteration
playbook — see
[`BUILDING-A-GREAT-HARNESS.md`](./BUILDING-A-GREAT-HARNESS.md).

---

## Why use this

LFD is a discipline, not a magic wand. The bundle gives
you:

- **A vocabulary** (loss-function-design) so the loop is
  shaped the same way across projects.
- **A harness** (harness-engineering) that the agent
  actually sees — context, tools, scaffolding,
  observability.
- **An outer driver** (loop-driver) that runs the
  hypothesis → candidate → score → forced-entropy cycle
  until the inner agent's skill converges.
- **A pluggable inner agent** (6 adapters) so the same
  loop works against the coding agent you already use.
- **A meta-skill** (meta-loss-function-development) that
  turns "build X" into a `/goal` prompt you can paste.
- **A dogfood verifier** (`examples/lfd-system-verifier/`)
  that proves the LFD system itself works — see
  "Verifying the LFD system" below.

The 4-piece loss anatomy — **target / constraints /
instruments / forced entropy** — is the design contract.
Every project you scaffold has the same shape, so the
loop is reusable across them.

---

## Verifying the LFD system (dogfood)

The LFD system verifies itself. The
[`examples/lfd-system-verifier/`](./examples/lfd-system-verifier/)
project scaffolds a complete loss-function-driven loop
that exercises every bundle skill end-to-end, runs in
under 5 minutes, and produces a verification report
(`verification-report.md` + `verification-report.json`).

It runs **two gates** — both must pass for the LFD
system to be considered verified:

| Gate | Script | Adapter | Time | What it proves |
|---|---|---|---|---|
| Tools | `run-verification.sh` | `fake-agent` (deterministic stub) | ~15s | LFD *tools* work: parsers, install, driver, scorer shape, sub-loss shape, the method test, the held-out grader. Bit-exact reproducible. |
| Integration | `run-verification-real.sh` | a real coding agent (Cline by default; `claude-code`, `codex`, `hermes-agent`, `opencode` also supported) | ~3-5 min | LFD *integration* works: the wrapper actually invokes the agent, the per-cycle outputs flow correctly, the per-task graders evaluate real agent output. Non-deterministic; pass_rate ≥ 0.8 is the threshold. |

To run both gates:

```bash
cd examples/lfd-system-verifier

./run-verification.sh        # fast deterministic gate
./run-verification-real.sh   # real-agent integration gate
```

The fake-agent gate is the **CI gate**: fast, deterministic,
catches contract drift. The real-agent gate is the
**integration gate**: proves the system is actually usable
with a real coding agent. See the
[verifier's README](./examples/lfd-system-verifier/README.md)
for full details on what each gate exercises, the per-task
graders, and the report format. **Contributions must pass
both gates** — see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

If this verifier passes (both gates), the LFD system is
operational. If either gate fails, the report tells you
which component regressed.

### What has been verified end-to-end (and what hasn't)

Out of the six agent-adapter combinations the bundle
ships, **only one has been run end-to-end with a real
coding agent**:

| Outer loop | Inner agent | Model | Provider | Result | Evidence |
|---|---|---|---|---|---|
| **Hermes Agent v2** (orchestrator model: `minimax/minimax-m3`, Nous provider) | **Cline v3.0.35** | `kimi-for-coding` | `openai-compatible` | **PASS** — all 5 design tasks, design_pass_rate=1.0, 721k tokens, 189s of Cline execution | [`examples/lfd-system-verifier/verification-report-real.json`](./examples/lfd-system-verifier/verification-report-real.json) (committed) |

> **About the "Outer loop" column.** The report records the
> *inner-agent* model (`kimi-for-coding`) — the one Cline
> called when it generated the candidate. The
> *orchestrator* model — the one Hermes used to *drive*
> the loop (read the iteration log, write the candidate
> prompt, run the design set, score, decide whether to
> refine) — is recorded here as a runtime fact, not as a
> captured artifact. The verifier script does not record
> it in the JSON. The combination "Hermes outer +
> Minimax M3 + Cline inner" is what was actually run;
> it is not bit-exact reproducible from the JSON alone.

The other five adapters — `claude-code-orchestration`,
`codex-orchestration`, `hermes-agent-orchestration`,
`opencode-orchestration`, and the `claude-code` /
`hermes-agent` / `codex` / `opencode` real-agent
integrations — are **supported by the adapter contract**
(the same parser shape, the same wrapper invocation, the
same per-iteration file layout; see
[`compatibility.md`](./compatibility.md)) but have **not
been run end-to-end**. They are expected to work because
the contract is uniform across adapters, but "expected
to work" is not "verified."

**Contributions are welcome.** If you run the integration
gate with another adapter and want to add a row to the
table above:

```bash
cd examples/lfd-system-verifier
./run-verification-real.sh "" "" <runtime>   # e.g. claude-code, codex, opencode
# If overall=PASS, commit verification-report-real.json
# alongside the existing one and open a PR.
```

A passing run with a new adapter is a high-value
contribution: it both grows the matrix and gives the next
user confidence in that combination. See
[`CONTRIBUTING.md`](./CONTRIBUTING.md) for the PR
process.

---

## Repository layout

```
.
├── README.md                 # this file
├── BUILDING-A-GREAT-HARNESS.md # HITL manual: V0→V1 expansion + V1→V2+ iteration
├── LICENSE                   # MIT
├── CONTRIBUTING.md           # how to add a new adapter / fix a bug
├── CHANGELOG.md              # version history
├── CODE_OF_CONDUCT.md        # community standards
├── SECURITY.md               # how to report vulnerabilities
├── .gitignore                # excludes the usual scratch files
├── install.sh                # bundle installer (profile-aware)
├── uninstall.sh              # bundle uninstaller
├── bundle.json               # machine-readable bundle manifest
├── compatibility.md          # version matrix + adapter contract
├── skills/
│   ├── loss-function-design/
│   ├── harness-engineering/
│   ├── cline-orchestration/
│   ├── claude-code-orchestration/
│   ├── codex-orchestration/
│   ├── hermes-agent-orchestration/
│   ├── opencode-orchestration/
│   ├── meta-loss-function-development/
│   ├── harness-scaffold/
│   └── loop-driver/
└── examples/                 # on-ramp for new users (3 reading paths)
    ├── README.md             # the on-ramp — start here
    ├── lfd-system-verifier/  # dogfood verifier (run-verification.sh, run-verification-real.sh)
    └── goal-prompts/         # three worked /goal prompt examples + anatomy
        ├── README.md
        ├── slack-clone-golang.md
        ├── cli-tool-rust.md
        └── algorithm-from-paper.md
```

---

## The agent-adapter contract

Every adapter skill in the bundle ships in the same shape.
A new adapter (e.g. `aider-orchestration`) is compatible
with the bundle if it ships:

1. `SKILL.md` describing the agent's CLI surface
2. `scripts/parse_<agent>_output.py` — NDJSON / JSON parser
3. `references/<agent>-wrapper-contract.md` — the wrapper
   invocation contract
4. `references/<agent>-v<N>-invocation.md` — the verified
   flags
5. `references/<agent>-skills-dir.sh` — the skills-dir
   instrument the cycle uses to install the candidate

The parser must emit JSON in this shape:

```json
{
  "tokens": 0,
  "duration_ms": 0,
  "candidate_text": "",
  "model": "",
  "provider": "",
  "finish_reason": "unknown",
  "iterations": 0,
  "tool_calls": []
}
```

Adapters may add extra fields (`cost_usd` is in the Claude
Code parser) but the 8 required fields must be present. The
wrapper must accept a positional `TASK` arg plus
`--cwd PATH`, `--timeout N`, `--cycle NAME` and write the
parsed JSON to stdout. Full contract:
[`compatibility.md`](./compatibility.md#compatibility-rules-for-new-agent-adapters).

---

## Adding a new agent adapter

The bundle currently supports Cline, Claude Code, Codex,
Hermes Agent, and OpenCode. To add support for another
coding agent (Aider, Continue, Goose, Cursor's CLI, etc.):

1. Copy any existing adapter skill as a template (e.g.
   `cp -R skills/opencode-orchestration skills/aider-orchestration`).
2. Rewrite `SKILL.md` to describe the new agent's CLI
   surface, working invocation, and gotchas.
3. Rewrite `scripts/parse_<agent>_output.py` to read the
   agent's actual output and emit the shared shape.
4. Rewrite `references/<agent>-wrapper-contract.md` and
   `references/<agent>-v<N>-invocation.md`.
5. Add an entry to `bundle.json` (skills list +
   install_order) — bump the bundle version's minor digit.
6. Add a row to the version matrix in `compatibility.md`.
7. Add a smoke test: see `CONTRIBUTING.md` for the recipe.
8. Open a PR. See `CONTRIBUTING.md` for the full
   checklist.

---

## Contributing

Contributions are welcome — new agent adapters,
fixes to the existing skills, additional examples, and
documentation improvements. See
[`CONTRIBUTING.md`](./CONTRIBUTING.md) for the workflow
and [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md) for
community standards.

---

## Security

Found a security issue? **Do not open a public GitHub
issue.** See [`SECURITY.md`](./SECURITY.md) for the
private reporting channel.

---

## License

MIT — see [`LICENSE`](./LICENSE).
