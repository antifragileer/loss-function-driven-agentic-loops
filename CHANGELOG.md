# Changelog

All notable changes to this bundle are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[2.0.0]: #200---2026-07-03
[1.0.0]: #100---2026-07-03
[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
