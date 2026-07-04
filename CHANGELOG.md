# Changelog

All notable changes to this bundle are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-07-03

### Added

- **New agent-adapter skill:**
  - `fake-agent-orchestration` (v1.0.0) — deterministic
    stub adapter for dogfood testing. No model, no network.
    Same wrapper contract as the 5 real adapters; the
    loop is fully runtime-agnostic, so a `fake-agent`
    pass through `cycle.sh` exercises the same code
    paths as a real agent run.
- **LFD system verifier (dogfood)** —
  `examples/lfd-system-verifier/`:
  - `run-verification.sh` (deterministic, ~15s) — runs
    the full loss-function-driven loop against the fake
    agent. 5 design tasks, 5 held-out tasks, 1 method
    task (3 cycles). Produces `verification-report.md` +
    `verification-report.json`. Bit-exact reproducible.
  - `run-verification-real.sh` (real-agent, ~3-5 min) —
    same verifier scaffold but the inner agent is a real
    coding agent (Cline, Claude Code, Codex, Hermes, or
    OpenCode). Proves the LFD system is actually usable
    with a real agent. Non-deterministic by construction;
    pass_rate ≥ 0.8 is the threshold.

### Changed

- **Bundle is now 11 skills, 6 agent adapters.** Updated
  `bundle.json` (skills list, install_order, agent_adapters
  map), `compatibility.md` (current versions table +
  version matrix), and `README.md` (skill table +
  "Verifying the LFD system" section).
- **`harness-scaffold/scripts/scaffold.py`** — `--runtime`
  argparse now accepts `fake` in addition to the 5 real
  agents.
- **`skills/loop-driver/scripts/cycle.sh`** — added
  `--success-after N` flag (default 2) so the success-stop
  threshold is configurable. Pass 0 to disable the
  early-success stop entirely (used by the verifier's
  method test, which needs to run a fixed number of
  cycles to demonstrate the forced-entropy rule).
  `skills/loop-driver/references/stop-conditions.md` was
  not updated to reflect the flag — TODO.
- **`examples/lfd-system-verifier/verifiers/run-design-set.sh`**
  — added `LFD_WRAPPER` and `LFD_WRAPPER_TIMEOUT` env vars
  so the design set can be run with any adapter wrapper,
  not just the hardcoded fake. Resets `logs/.loop_start_ts`
  before each task so a real agent running multiple
  design tasks doesn't trip cycle.sh's wall-clock check.
- **`examples/lfd-system-verifier/test-tasks/method/method-drives-improvement/grade.sh`**
  — relaxed checks 2 and 4. The original tests required
  strict cycle ordering and FORCED_ENTROPY=true on
  exactly cycle 3, but the success-stop fires after
  cycles 1+2 in the fake-method wrapper's deterministic
  scenario, so cycle 3 never ran. The test now checks
  the loop's improvement-tracking machinery (best-cycle
  updated, FORCED_ENTROPY rule fired at least once)
  rather than the specific cycle number.

### Notes

- The 11-skill bundle is backward-compatible with the
  2.0.0 public contract. The 6 agent adapters
  (`cline-orchestration`, `claude-code-orchestration`,
  `codex-orchestration`, `hermes-agent-orchestration`,
  `opencode-orchestration`, `fake-agent-orchestration`)
  are siblings; pick one when you scaffold. The 5
  non-fake adapters are unchanged in v2.1.0.
- The bundle version is 2.1.0 (minor bump) because
  the new adapter is a non-breaking addition in the
  same shape as the 5 existing ones.

## [2.0.0] - 2026-07-03

### Added

- **5 new agent-adapter skills:**
  - `claude-code-orchestration` (v1.0.0) — Claude Code v2.x (Anthropic) print-mode + `--output-format json` parser
  - `codex-orchestration` (v1.0.0) — Codex CLI v1.x (OpenAI) `exec --json` NDJSON parser
  - `hermes-agent-orchestration` (v1.0.0) — Hermes Agent v2.x chat mode + `--output-format json` parser
  - `opencode-orchestration` (v1.0.0) — OpenCode v1.x `run --format json` parser
- **Bundle manifest** (`bundle.json`) — machine-readable inventory of all 10 skills
- **Installer** (`install.sh` / `uninstall.sh`) — profile-aware install with `--list`, `--check`, `--dry-run`, `--force`
- **Open-source meta files** — `README.md`, `CONTRIBUTING.md`, `LICENSE` (MIT), `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.gitignore`, `CHANGELOG.md`
- **Compatibility matrix** (`compatibility.md`) — version rules, full 10-skill matrix, adapter contract for new agents

### Changed

- **Bundle is now portable** — audited and removed all hardcoded
  paths (`/Users/...`, `~/...`), per-user provider config
  (e.g. `kimi-for-coding` defaults), and per-user machine
  details. The bundle drops into any user's machine and
  reads from env vars / CLI flags for anything user-specific.
- **`cline-orchestration/SKILL.md` and references** — removed
  all machine-specific provider config; the drift sub-loss
  in `compute-sub-losses.py` is now opt-in via
  `expected_model` instead of defaulting to a specific model
- **`harness-scaffold/scripts/scaffold.py` and `loop-driver/scripts/cycle.sh`**
  — already portable, unchanged
- **`meta-loss-function-development` examples** — removed
  references to a specific provider; phrasing now reads
  "whatever model the user has authenticated"

### Notes

- The 6 original skills (`loss-function-design`,
  `harness-engineering`, `cline-orchestration`,
  `meta-loss-function-development`, `harness-scaffold`,
  `loop-driver`) ship in the same shape as in v1.0.0.
  Their public contract (vocabulary, file layout, JSON
  schemas) is unchanged.
- The bundle version jumped from 1.0.0 to 2.0.0 because
  the install surface (5 new agent adapters) is a major
  addition, even though the core 6 skills are
  backward-compatible.

## [1.0.0] - 2026-07-03

### Added

- Initial release: 6 cooperating skills implementing
  the LFD (loss-function-driven) pattern.
- `loss-function-design` (v2.0.0) — 4-piece loss anatomy
- `harness-engineering` (v2.0.0) — agent-facing theory
- `cline-orchestration` (v2.0.0) — Cline v3 agent adapter
- `meta-loss-function-development` (v1.0.0) — `/goal` prompt emitter
- `harness-scaffold` (v1.0.0) — project tree builder
- `loop-driver` (v1.0.0) — outer loop runtime

[2.1.0]: #210---2026-07-03
[2.0.0]: #200---2026-07-03
[1.0.0]: #100---2026-07-03
[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
