# Contributing to loss-function-driven-agentic-loops

Thanks for your interest in contributing! This bundle is a
**distribution** — every file ships to every user. Quality
bar is high: portable, agent-legible, and verified.

## Quick links

- [Code of Conduct](./CODE_OF_CONDUCT.md)
- [Security policy](./SECURITY.md)
- [Compatibility matrix](./compatibility.md) — version
  rules + adapter contract
- [Bundle manifest](./bundle.json) — single source of
  truth for the 11-skill inventory

## What we accept

We welcome:

- **New agent adapters** (e.g. `aider-orchestration`,
  `continue-orchestration`, `goose-orchestration`) — see
  the [adapter contract](#the-agent-adapter-contract)
  below.
- **Bug fixes** to any of the 11 skills, the installer,
  the parser scripts, or the wrapper contracts.
- **Documentation improvements** — clearer
  troubleshooting recipes, more examples, sharper
  descriptions in `SKILL.md` frontmatter.
- **New `/goal` prompt examples** in
  `examples/` (or under `skills/meta-loss-function-development/examples/`).
- **Compatibility matrix updates** when a new major
  version of a coding agent ships.

We **do not** accept:

- **Hardcoded paths** (`/Users/...`, `~/...`, etc.) —
  the bundle must drop into any user's machine.
- **Per-user config** baked into scripts — use env vars
  and `$XDG_CONFIG_HOME` conventions.
- **Modifications to the shared parser shape** without a
  bundle major-version bump.
- **Skipping the smoke test** for new or modified
  parsers.

## How to contribute

### 1. Fork and branch

```bash
git clone https://github.com/YOUR_FORK/loss-function-driven-agentic-loops.git
cd loss-function-driven-agentic-loops
git checkout -b feat/your-adapter-name   # or fix/issue-N
```

### 2. Make your change

For a **new agent adapter**, see the full recipe in
[Adding a new agent adapter](#adding-a-new-agent-adapter)
below.

For a **bug fix**:

- Open or reference an issue first (use
  `gh issue create` or comment on the existing one).
- Make the smallest change that fixes the bug.
- Add a test or a smoke command that reproduces the
  failure on `main` and passes on your branch.

### 3. Verify locally

Run these checks before opening a PR:

```bash
# The bundle installer must list the right skills and --check must pass.
./install.sh --list
./install.sh --check .

# All Python parsers must compile and run on an empty file
# (this is the smoke test for new or modified parsers).
for s in skills/*/scripts/parse_*.py; do
  python3 "$s" /tmp/empty.json > /dev/null || { echo "FAIL: $s"; exit 1; }
done

# All wrapper contract scripts must run without error
# and print a SKILLS_DIR line.
for s in skills/*/references/*-skills-dir.sh; do
  bash "$s" > /dev/null || { echo "FAIL: $s"; exit 1; }
done

# All SKILL.md frontmatter must parse + name + description
# (this is the validator the Hermes skill loader uses).
python3 -c "
import re, sys, yaml, pathlib
for md in pathlib.Path('skills').rglob('SKILL.md'):
    text = md.read_text()
    assert text.startswith('---\n'), f'{md}: missing leading ---'
    m = re.search(r'\n---\n', text[3:])
    assert m, f'{md}: missing closing ---'
    fm = yaml.safe_load(text[3:m.start()+3])
    assert 'name' in fm and 'description' in fm, f'{md}: missing name/description'
    assert len(fm['description']) <= 1024, f'{md}: description too long'
    assert len(text) <= 100_000, f'{md}: file too long'
print('all SKILL.md files valid')
"

# No portability violations
grep -rE "oxenated|/Users/[A-Za-z]+|antifragileer" skills/ install.sh uninstall.sh bundle.json compatibility.md README.md && \
  { echo "FAIL: portability violation found"; exit 1; } || true
```

### 3a. Run the LFD system verifier (dogfood)

The LFD system verifies itself. The
[`examples/lfd-system-verifier/`](./examples/lfd-system-verifier/)
project exercises every bundle skill end-to-end. **Both of
the following must pass** before a contribution is mergeable:

```bash
cd examples/lfd-system-verifier

# Fast deterministic gate (~15s, no model, no network).
# Tests that the LFD *tools* work: parsers, install,
# driver, scorer shape. Bit-exact reproducible.
./run-verification.sh

# Real-agent gate (~3-5 min, requires a real coding agent
# on $PATH — Cline by default; claude-code, codex,
# hermes-agent, opencode also supported).
# Tests that the LFD *integration* works: the wrapper
# actually invokes the agent, the per-cycle outputs
# flow correctly, the per-task graders evaluate real
# agent output.
#
# pass_rate >= 0.8 is the threshold (4/5 on the 5-task
# design set is the expected norm; 5/5 is the gold
# standard). The full criteria are documented in the
# verifier's README and report.
./run-verification-real.sh
```

Why **both** are required:

- The fake-agent run is the **bit-exact CI gate** —
  fast, deterministic, catches contract drift in
  parsers, install, driver, scorer shape, sub-loss
  shape, the method test, the held-out grader. A
  failure here is a real regression in the LFD
  system.
- The real-agent run is the **integration gate** —
  proves the system is actually usable with a real
  coding agent. Catches integration bugs the
  fake-agent can't: the wrapper failing to invoke the
  binary, the parser misreading the agent's actual
  output, the per-cycle state files surviving a
  real agent's per-cycle directory creation. A
  failure here is a real integration regression.

Contributions that don't run both are **not mergeable**
— the LFD system can't be considered verified without
both gates green.

If your change touches the real-agent path (the wrapper
script, the run-design-set harness, or the per-task
graders) and you don't have a real coding agent on
$PATH, you can skip the real-agent gate for the PR
but you must note it in the PR description so the
maintainer can run it. Don't fake the gate by
tweaking the threshold.

### 4. Commit and push

Use the project's commit convention:

```
type: concise subject line

Optional body.
```

Types: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`,
`test:`.

Examples:

- `feat: add aider-orchestration adapter`
- `fix: cline-v3-invocation.md — corrected tool_call schema for v3.0.35`
- `docs: README — added /goal prompt example`

### 5. Open a PR

Open a PR against `main`. The PR description should
include:

- A one-sentence summary of the change.
- The motivation (issue link, if any).
- A smoke test or verification command the reviewer can
  run.
- For new adapters: which coding agent, which version, and
  how you verified the wrapper invocation.

PRs are reviewed for: (a) portability, (b) skill-loader
compliance, (c) agent-legibility, (d) test coverage.

## The agent-adapter contract

Every adapter skill in the bundle ships in the same shape.
A new adapter (e.g. `aider-orchestration`) is compatible
with the bundle if it ships:

1. `SKILL.md` describing the agent's CLI surface, the
   verified invocation, the JSON / NDJSON output schema,
   and the gotchas.
2. `scripts/parse_<agent>_output.py` — reads the agent's
   output and emits the shared shape on stdout.
3. `references/<agent>-wrapper-contract.md` — the wrapper
   invocation contract (positional TASK, --cwd, --timeout,
   --cycle, exit codes, JSON shape on stdout).
4. `references/<agent>-v<N>-invocation.md` — the verified
   flag combinations, the gotcha table, the provider
   matrix.
5. `references/<agent>-skills-dir.sh` — the skills-dir
   instrument `cycle.sh` uses to install the candidate.

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
Code parser) but the 8 required fields must be present.

## Adding a new agent adapter

Step-by-step recipe:

1. **Copy a sibling as a template.** `aider-orchestration`
   is closest in shape to `opencode-orchestration` (both
   one-shot `--format json` patterns); `codex-orchestration`
   is a good template if the agent requires a git repo.

   ```bash
   cp -R skills/opencode-orchestration skills/aider-orchestration
   ```

2. **Rewrite `SKILL.md`.** Describe the agent's CLI
   surface: where to install it, how to authenticate,
   which subcommand is the one-shot entry point, which
   flags control the output format. Keep the
   "What we tried and what broke" table — it captures
   real gotchas and saves the next person hours.

3. **Rewrite `scripts/parse_<agent>_output.py`.** Read the
   agent's actual output file (NDJSON, single-object JSON,
   or a transcript) and emit the shared shape on stdout.
   The script MUST be importable as a module AND runnable
   as a script (`if __name__ == "__main__"`). It MUST emit
   valid JSON to stdout on empty input (the loop's
   "no_output" path).

4. **Rewrite `references/<agent>-wrapper-contract.md` and
   `references/<agent>-v<N>-invocation.md`.** Follow the
   shape of the existing contracts: invocation form, args,
   exit codes, what the wrapper does, what it does NOT
   do, example outputs, gotcha table, provider matrix.

5. **Rewrite `references/<agent>-skills-dir.sh`.** Print
   the agent's skills directory to stdout. The script
   MUST be a valid bash script and MUST print a
   `SKILLS_DIR=` line.

6. **Update `bundle.json`.** Add a skill entry (with
   `role: "agent-adapter"`, version `1.0.0`, summary,
   load_trigger) and add the skill to `install_order`.
   Bump the bundle's `version` minor digit (1.0.0 → 1.1.0
   for a new adapter in the same shape).

7. **Update `compatibility.md`.** Add a row to the version
   matrix, an entry to the "Current versions" table, and
   a paragraph in the "What changes between major
   versions" section.

8. **Update `README.md`.** Add a bullet to the agent
   adapters list in the "What's in the box" table.

9. **Run the smoke tests** in the verification section
   above. The empty-input parser test is the most
   important — it catches "crashes on missing file"
   bugs that the loop would hit on cycle 0.

10. **Open the PR.** Reference this recipe in the PR
    description; reviewers will check the same shape.

## Coding style

- **Bash:** `set -euo pipefail` at the top. Quote
  variables. Use `[[ ]]` not `[ ]`. Resolve paths via
  `$(cd "$(dirname "$0")" && pwd)`. No shell-only
  features (no `[[ $a == b ]]` with glob literals —
  quote both sides).
- **Python:** Python 3.10+ syntax. Type hints on
  functions in `parse_*.py` parsers. Use `pathlib.Path`
  for filesystem paths. No external dependencies — the
  parsers must work on a stock Python install.
- **Markdown:** sentence-per-line is fine. Use ATX
  headers (`#`, `##`). Code blocks for commands and
  JSON.
- **YAML frontmatter:** every `SKILL.md` starts with
  `---\n`, has `name` + `description` (≤ 1024 chars),
  and ideally `version`, `author`, `license`, and
  `metadata.hermes.tags`. The
  [`hermes-agent-skill-authoring`](https://hermes-agent.nousresearch.com/docs)
  convention is the source of truth.

## Reporting issues

Use [GitHub Issues](https://github.com/antifragileer/loss-function-driven-agentic-loops/issues).
Include:

- Bundle version (`./install.sh --list`)
- Each affected skill's version (from its `SKILL.md`
  frontmatter)
- The inner agent and version
- The model the inner agent is using
- The exact command that produced the bug
- The expected vs actual behavior

For security issues, **do not** open a public issue — see
[`SECURITY.md`](./SECURITY.md).

## Community

- Be respectful. See [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
- Assume good faith. The bundle is shipped to many
  users; the cost of a regression is high.
- When in doubt, ask. Open a discussion or a draft PR
  before investing in a large change.
