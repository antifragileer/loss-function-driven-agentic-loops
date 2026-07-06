# Compatibility — loss-function-driven-agentic-loops bundle

Versioned compatibility rules for the 11-12 skills in the bundle.
This file is the single source of truth for "which version of
which works with which." When you upgrade, read this first.

## Current versions

| Skill | Version | Role | Required? |
|---|---|---|---|
| `loss-function-design` | 2.0.0 | vocabulary (4-piece loss anatomy) | yes |
| `harness-engineering` | 2.0.0 | theory (what the agent sees) | yes |
| `cline-orchestration` | 2.0.0 | agent adapter (Cline v3) | optional — substitute for non-Cline agents |
| `claude-code-orchestration` | 1.0.0 | agent adapter (Claude Code v2) | optional — substitute for non-Claude agents |
| `codex-orchestration` | 1.0.0 | agent adapter (Codex v1) | optional — substitute for non-Codex agents |
| `hermes-agent-orchestration` | 1.0.0 | agent adapter (Hermes Agent v2) | optional — substitute for non-Hermes agents |
| `opencode-orchestration` | 1.0.0 | agent adapter (OpenCode v1) | optional — substitute for non-OpenCode agents |
| `fake-agent-orchestration` | 1.0.0 | agent adapter (deterministic stub) | optional — dogfood testing only |
| `meta-loss-function-development` | 1.1.0 | meta-skill (emits /goal prompt) | yes |
| `harness-scaffold` | 1.1.0 | build-tool (scaffolds project tree) | yes |
| `lfd-thinking-protocols` | 0.2.0 | gate (10 thinking protocols the meta-skill invokes between Rounds 0-7) | optional — meta-session helper, not loaded by the loop session |
| `loop-driver` | 1.1.0 | runtime (runs the outer loop) | yes |

## The version matrix

This is a *forward* matrix: row's version × column's version
is "compatible."

| | lfd 2.x | he 2.x | cline 2.x | cc 1.x | codex 1.x | hermes 1.x | opencode 1.x | fake 1.x | meta 1.x | scaffold 1.x | loop 1.x |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **loss-fn-design 2.x** | — | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| **harness-eng 2.x** | yes | — | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| **cline-orch 2.x** | yes | yes | — | yes | yes | yes | yes | yes | yes | yes | yes |
| **claude-code 1.x** | yes | yes | yes | — | yes | yes | yes | yes | yes | yes | yes |
| **codex 1.x** | yes | yes | yes | yes | — | yes | yes | yes | yes | yes | yes |
| **hermes-agent 1.x** | yes | yes | yes | yes | yes | — | yes | yes | yes | yes | yes |
| **opencode 1.x** | yes | yes | yes | yes | yes | yes | — | yes | yes | yes | yes |
| **fake-agent 1.x** | yes | yes | yes | yes | yes | yes | yes | — | yes | yes | yes |
| **meta-lfd 1.x** | yes (≥1.x) | yes (≥1.x) | optional | optional | optional | optional | optional | optional | — | yes | yes |
| **harness-scaffold 1.x** | — | — | optional | optional | optional | optional | optional | optional | n/a | — | yes (≥1.0) |
| **loop-driver 1.x** | — | — | optional | optional | optional | optional | optional | optional | n/a | yes (≥1.0) | — |

Rules:

- **loss-function-design 2.x** is API-stable. 1.x skills (meta-lfd
  1.x, harness-scaffold 1.x, loop-driver 1.x) read its
  vocabulary; they don't import code.
- **harness-engineering 2.x** is API-stable. Same as above.
- **cline-orchestration 2.x** targets **Cline v3.0.34+**. Older
  Cline versions are unsupported. The wrapper script and NDJSON
  parser may need patches for newer Cline majors.
- **claude-code-orchestration 1.x** targets **Claude Code v2.x**.
  Earlier v1.x versions had a different output schema.
- **codex-orchestration 1.x** targets **Codex CLI v1.x**. The
  wrapper `git init`s the iteration dir because Codex refuses to
  run outside a git repository.
- **hermes-agent-orchestration 1.x** targets **Hermes Agent
  v2.x**. Provider-agnostic — the user picks the model via
  `hermes model` or the active profile.
- **opencode-orchestration 1.x** targets **OpenCode v1.x**.
  Provider-agnostic — the model comes from `$OPENCODE_MODEL`.
- **fake-agent-orchestration 1.x** is the deterministic stub
  used by the LFD system verifier (`examples/lfd-system-verifier/`)
  to dogfood the LFD system end-to-end. No model, no network.
  The wrapper contract matches the 5 real adapters exactly, so
  a `fake-agent` cycle.sh invocation exercises the same code
  paths as a real agent run.
- **meta-loss-function-development 1.x** is the meta-loop. It
  produces a /goal prompt that the next 3 skills (harness-scaffold,
  loop-driver) consume. The /goal prompt format is the contract;
  changing the format is a breaking change for both consumers.
- **harness-scaffold 1.x** and **loop-driver 1.x** are tightly
  coupled. They share the file layout (verifiers/, instruments/,
  test-tasks/, logs/), the iteration-log.md format, and the
  sub-losses.json schema. **Always upgrade both together.**
- **loop-driver 1.x**'s success stop condition is configurable
  via the `--success-after N` flag (default 2). The verifier's
  method test uses `--success-after 99` to disable the
  early-success stop so all 3 cycles run.

## What changes between major versions

- **loss-function-design 1.x → 2.x**: frontmatter description
  rewrite for narrower auto-trigger; SKILL.md structure changed
  to 4-piece anatomy. The 4-piece vocabulary itself is stable.
- **harness-engineering 1.x → 2.x**: rebalanced to be
  agent-agnostic (no more "the Cline team" references). Added
  observability section.
- **cline-orchestration 1.x → 2.x**: targets Cline v3 (was v2).
  NDJSON parser rewritten. Wrapper script moved from
  `verifiers/cline-wrapper.sh` to a Cline-specific dir.
- **claude-code-orchestration, codex-orchestration,
  hermes-agent-orchestration, opencode-orchestration 1.x**:
  first release in v2.0.0 of the bundle.
- **fake-agent-orchestration 1.x**: first release in
  v2.1.0 of the bundle. Used by the LFD system verifier
  to dogfood the loop end-to-end.
- **meta-loss-function-development 1.x**: first release.
- **harness-scaffold 1.x**: first release.
- **loop-driver 1.x**: first release. **1.0.x → 1.1.x
  (shipped in 2.2.0)**: `--success-after` flag is
  implemented in `cycle.sh` and documented in
  `references/stop-conditions.md` (default 2, pass 0
  to disable the early-success stop — used by the
  verifier's method test).

## When the inner agent changes (drop-in substitution)

The six agent-adapter skills in the bundle —
`cline-orchestration`, `claude-code-orchestration`,
`codex-orchestration`, `hermes-agent-orchestration`,
`opencode-orchestration`, `fake-agent-orchestration` —
all bind to a specific inner agent. They are siblings:
pick one when you scaffold, and the loop runs against it.

The user passes
`--runtime {cline,claude-code,codex,hermes-agent,opencode,fake}`
to `harness-scaffold` to generate the correct wrapper, and the
loop-driver picks up the right `parse_<agent>_output.py` from
the matching adapter skill.

The harness-scaffold and loop-driver skills are
**runtime-agnostic**. They invoke whatever wrapper is at
`verifiers/<runtime>-wrapper.sh`.

### Compatibility rules for new agent adapters

A new agent adapter skill (e.g., `aider-orchestration`) is
compatible with the bundle if it ships in the same shape as
the 6 included adapters:

1. `SKILL.md` describing the agent's CLI surface
2. `scripts/parse_<agent>_output.py` — NDJSON / JSON parser
3. `references/<agent>-wrapper-contract.md` — the wrapper
   invocation contract
4. `references/<agent>-v<N>-invocation.md` — the verified flags
5. `references/<agent>-skills-dir.sh` — the skills-dir
   instrument the cycle uses to install the candidate

The parser must emit JSON in this shape:
`{"tokens": int, "duration_ms": int, "candidate_text": str,
"model": str, "provider": str, "finish_reason": str,
"iterations": int, "tool_calls": list}`. Adapters may add
extra fields (e.g. `cost_usd` in the Claude Code parser) but
the 8 required fields must be present.

The wrapper script must accept a positional TASK arg plus
`--cwd PATH`, `--timeout N`, `--cycle NAME` and write the
parsed JSON to stdout.

The `<agent>-skills-dir.sh` instrument must print the
agent's skills directory to stdout (used by `cycle.sh` to
install the candidate).

The wrapper must exit non-zero on missing binary / bad args,
exit 0 on successful agent run, and never block longer than
the `--timeout` value.

If those 4 invariants hold, the new adapter drops in
without changing harness-scaffold, loop-driver, or any of
the other 9 skills.

## Upgrading the bundle

To upgrade an installed bundle:

```bash
# Pull the new bundle
git pull  # or download the new tarball

# Re-run the installer with --force
./install.sh <profile-dir> --force

# Verify
./install.sh --check <profile-dir>
```

The installer overwrites the 11-12 skill directories but does
**not** touch any other skills in the profile.

## Downgrading

The bundle is versioned as a whole. Downgrading requires
re-installing an older tarball. There is no partial
downgrade — the 3 runtime skills (harness-scaffold,
loop-driver) are version-coupled and must match.

## What is NOT in this bundle

The 11-12-skill bundle is the *minimum* for a loss-function-driven
loop. Optional additions that work with the bundle but are
not included:

- **Observability stack** (LogQL / PromQL / TraceQL). The
  `harness-engineering` skill describes how to wire one in;
  the actual exporter setup is per-project.
- **Additional inner-agent skills** (Aider, Continue,
  Goose, etc.). The 6 included adapters are
  Cline, Claude Code, Codex, Hermes Agent, OpenCode, and
  fake-agent. See the "drop-in substitution" section above
  for the adapter contract.
- **CI integration** (run the loop in GitHub Actions).
  `loop-driver/scripts/run-loop.sh` exits 0/3 — wrap it in
  your CI's shell step.
- **Held-out grader authoring**. The scaffold writes a
  stub. Filling in real graders is the user's job (or a
  future `grader-author` skill).

## Reporting issues

When reporting a compatibility issue, include:

- `bundle version` (from `bundle.json`)
- Each skill's version (from its `SKILL.md` frontmatter)
- The inner agent and version (e.g., Cline v3.0.34)
- The model the inner agent is using
- The /goal prompt that triggered the issue (if relevant)
- The exact error or unexpected behavior

Without the versions, the issue is un-actionable.

## Verified end-to-end combinations

A combination is "verified end-to-end" when the real-agent
integration gate (`examples/lfd-system-verifier/run-verification-real.sh`)
has been run against it and produced a passing
`verification-report-real.json` (overall=PASS,
design_pass_rate=1.0). The committed report is the
evidence; the matrix below records what has been checked.

| Outer loop | Inner agent | Model | Provider | Bundle version | Evidence |
|---|---|---|---|---|---|
| Hermes Agent v2 (orchestrator: `minimax/minimax-m3`, Nous) | Cline v3.0.35 | `kimi-for-coding` | `openai-compatible` | 2.1.0 | [`examples/lfd-system-verifier/verification-report-real.json`](./examples/lfd-system-verifier/verification-report-real.json) |

> **What the report captures vs. what it doesn't.** The
> JSON records the *inner-agent* model (`kimi-for-coding`) —
> the one the coding agent called when it generated the
> candidate. It does **not** capture the *orchestrator*
> model — the one Hermes used to *drive* the loop
> (orchestration decisions, scoring, forced-entropy
> choices, stop-condition evaluation). The orchestrator
> model in the table above is recorded as a runtime fact
> from the verification session, not from the JSON. To
> make this fully reproducible from artifacts, extend
> `run-verification-real.sh` to capture the orchestrator
> model into the report.

The other five adapter combinations
(`hermes-agent`/`claude-code`, `hermes-agent`/`codex`,
`hermes-agent`/`opencode`, `claude-code`/`claude-code`,
etc.) are **supported by the adapter contract** — every
adapter must ship the same parser shape, the same wrapper
invocation, the same per-iteration file layout. They are
*expected* to work but are *not verified* as of v2.3.1.

To add a row to this table: run
`./run-verification-real.sh "" "" <runtime>` from
`examples/lfd-system-verifier/`, commit the resulting
`verification-report-real.json` (rename if the existing
one is for a different runtime), and open a PR. See
[`CONTRIBUTING.md`](./CONTRIBUTING.md).
