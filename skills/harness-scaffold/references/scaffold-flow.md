# Scaffold Flow — Reference

The end-to-end flow that `scripts/scaffold.py` runs. Read this if
the scaffold is misbehaving and you need to know what step is
producing the wrong output.

## Inputs

| Flag | Default | Meaning |
|---|---|---|
| `--project-root PATH` | (required) | The directory the scaffold writes into. Created if it doesn't exist. |
| `--goal-prompt PATH` | `$PROJECT_ROOT/GOAL.md` | The /goal prompt to parse. The meta-loss-function-development skill emits this. |
| `--runtime {cline,codex,aider}` | parsed from prompt, default `cline` | Which agent the wrapper script targets. |
| `--no-private` | false | Skip writing the held-out grader scaffold. Use for projects without held-out evaluation. |

## Step 1 — parse the goal prompt

The scaffold reads the goal prompt and extracts five sections via
regex (see `references/regex-extract.md`):

1. **Runtime** — `inner loop is the \`cline\` CLI` → `cline`.
2. **Design tasks** — the `Design-set tasks` numbered list.
3. **Held-out tasks** — the `Held-out tasks` named list (`h01..h10`).
4. **Project name** — the `# /goal: <TITLE>` first line, slugified.
5. **Cycle budget** — wall-clock + token budgets from `Constraints`.

If any section fails to parse, the scaffold emits a default and a
`# TODO: user-fill` comment at the top of the affected file. The
scaffold does **not** fail on parse errors — it falls back.

## Step 2 — write the project root files

| File | Source | Notes |
|---|---|---|
| `AGENTS.md` | `AGENTS_MD` template | Loop driver rules. Includes the "DO NOT read private/" hard rules. |
| `GOAL.md` | copy of input prompt | The /goal prompt itself, untouched. |
| `README.md` | `README_MD` template | Run instructions. References all generated files. |

These three are written with the `# auto-generated` header.

## Step 3 — write `verifiers/`

| File | Purpose |
|---|---|
| `verifiers/cline-wrapper.sh` | The only way to invoke the agent. Resolves `$CLINE_BIN` from env then `command -v cline`. Bash, exits 2 on bad args, 3 on missing binary. |
| `verifiers/run-design-set.sh` | Loops over the design tasks, runs wrapper per task, runs `grade.sh` per task, aggregates score. Emits `logs/design-set-score.json`. |
| `verifiers/compute_sub_losses.py` | 7 sub-losses, deterministic. Takes a cycle JSON, prints sub-losses + weighted sum + gates. |
| `verifiers/parse_cline_output.py` | NDJSON parser for the wrapper's output. Stubs to 0-tokens no-op if file is empty. |
| `verifiers/instruments/time-remaining.sh` | Seconds left in the loop budget. Uses `LOOP_START_TS` env or `stat -f %m` on a marker file. |
| `verifiers/instruments/tokens-remaining.sh` | Tokens left. Reads from a JSON sidecar the wrapper writes per cycle. |
| `verifiers/instruments/tokens-this-iter.sh` | Tokens used last cycle. |
| `verifiers/instruments/cline-version.sh` | Installed agent version. `cline --version` for Cline. |
| `verifiers/instruments/cline-skills-dir.sh` | Where the agent scans for skills. Echoes the platform default. |
| `verifiers/instruments/sub-loss-readout.sh` | Thin wrapper that calls `compute_sub_losses.py`. |
| `verifiers/private/grader.sh` | **HELD-OUT — chmod 700.** Stub the user fills in with the real grader. |

All shell scripts are `set -euo pipefail` and `chmod +x`. All Python
scripts are executable and have a `if __name__ == "__main__"` block.

## Step 4 — write `test-tasks/design/`

One directory per design task, slug from the description:

```
test-tasks/design/<NN-slug>/
├── prompt.txt       # the prompt the agent receives
├── README.md        # the task description (1-2 sentences)
└── grade.sh         # the deterministic grader (chmod +x)
```

The `prompt.txt` and `README.md` are auto-generated from the
/goal prompt's design task entry. The `grade.sh` is a stub
(`exit 1` with a TODO). The fresh session's job is to fill in
real graders.

## Step 5 — write `test-tasks/held-out/`

One directory per held-out task:

```
test-tasks/held-out/h01/README.md
test-tasks/held-out/h02/README.md
...
test-tasks/held-out/h10/README.md
```

Each `README.md` is a placeholder. The user fills in the actual
held-out task files. The directories are `chmod 700` so the
agent cannot read them.

## Step 6 — write `logs/` and `skills/`

Both empty (with a `.gitkeep`). The loop's running trace lands in
`logs/`. The agent's candidate skill lands in
`skills/<artifact-name>/`.

## Idempotency

The scaffold is **safe to re-run**. Files with the
`# auto-generated` header are overwritten. Files with the
`# agent-edited: yes` marker (the agent's first 5 lines) are
skipped with a `skip (user-edited): PATH` message on stderr.

This means:

- The user can edit `grade.sh`, add `# agent-edited: yes`, and the
  scaffold won't clobber it on the next run.
- A fresh scaffold of a brand-new directory works.
- A re-scaffold after the loop has run (e.g., to add a 6th
  design task) preserves the agent's work.

## Common scaffold-flow pitfalls

- **The /goal prompt is missing the em-dash separator** between
  task path and description. The scaffold falls back to
  `task-NN` slugs. Use the meta-loss-function-development
  template, not free-form.
- **The /goal prompt is missing the held-out range marker.**
  The scaffold falls back to `h01..h10`. If your held-out set
  is `h01..h05`, edit the prompt to say
  `` `h01` ... `h05` ``.
- **`$CLINE_BIN` is not set and `cline` is not on PATH.**
  The wrapper exits 3. The scaffold can't detect this — it
  writes the wrapper anyway. Verify with
  `verifiers/instruments/cline-version.sh` after the scaffold.
- **Modifying a generated `*.sh` and hitting "exits silently".**
  All scaffold-emitted shell scripts use `set -euo pipefail`.
  That setting surfaces bugs early but has three common
  silent-exit modes (unbound variable, subshell non-zero,
  `wc -l` trailing newline). The `loop-driver` skill
  documents them in
  `references/set-euo-pipefail-pitfalls.md` — read that if
  you modify `cline-wrapper.sh` or `run-design-set.sh` and
  the modified script dies with no error message.

## Verifying a fresh scaffold

After the scaffold runs:

```bash
cd $PROJECT_DIR
PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh
# Expected: pass_rate=0.0 (no candidate skill installed yet)
# All design task grades should be FAIL (grade.sh is a stub).
cat logs/design-set-score.json
```

The baseline `pass_rate=0.0` is the loop's starting point. Cycle
1's first run should beat it.
