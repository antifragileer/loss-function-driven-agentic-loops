# Loss Function Development Skills

A drop-in skill bundle for **loss-function-driven (LFD)
agentic loops** — turn a high-level goal into a
paste-able `/goal` prompt, scaffold a harness, and run the
outer loop until the inner agent's skill converges.

The bundle ships **11 cooperating skills** that implement
the LFD pattern, with **6 agent-adapter skills** so the same
loop works against Cline, Claude Code, Codex, Hermes Agent,
OpenCode, or the deterministic `fake-agent` stub used for
dogfood testing (see `examples/lfd-system-verifier/`).

- **Repository:** https://github.com/antifragileer/loss-function-development-skills
- **License:** MIT
- **Bundle version:** 2.1.0

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
| [`meta-loss-function-development`](./skills/meta-loss-function-development) | 1.0.0 | The meta-skill that emits the `/goal` prompt | yes |
| [`harness-scaffold`](./skills/harness-scaffold) | 1.0.0 | Build tool — scaffolds the project tree from a `/goal` prompt | yes |
| [`loop-driver`](./skills/loop-driver) | 1.0.0 | Runtime — runs the outer loop until a stop condition fires | yes |

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

## Quick start

```bash
# 1. Clone
git clone https://github.com/antifragileer/loss-function-development-skills.git
cd loss-function-development-skills

# 2. List the skills
./install.sh --list

# 3. Install into a Hermes profile (e.g. your default profile)
./install.sh ~/.hermes/profiles/default

# 4. Verify
./install.sh --check ~/.hermes/profiles/default

# 5. Open a session under that profile and say
#    "use loss function development to build X"
#    — meta-loss-function-development loads and emits a /goal prompt.

# 6. Paste the /goal prompt into a fresh session; the loop
#    scaffolds and runs.
```

To uninstall:

```bash
./uninstall.sh ~/.hermes/profiles/default
```

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

---

## Repository layout

```
.
├── README.md                 # this file
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
└── examples/                 # sample /goal prompts and the LFD system verifier
    ├── lfd-system-verifier/  # dogfood verifier (run-verification.sh, run-verification-real.sh)
    └── cli-tool-rust.md      # example /goal prompt
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
