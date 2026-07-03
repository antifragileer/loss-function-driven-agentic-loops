# Cline skill install contract

The `cline-driver-loop` project's main artifact is a **Cline
skill** — a directory containing a `SKILL.md` with YAML
frontmatter, installed where Cline will scan for it. This file
documents the install contract that future agents and sessions
will hit. Verified 2026-07-03 against Cline v3.0.35.

## Where Cline scans for skills

The default scan root is `~/.cline/skills/`. The `verifiers`
project ships a deterministic instrument at
`verifiers/instruments/cline-skills-dir.sh` that prints the
resolved paths (the path uses `$HOME` so it works on any
machine):

```
CLINE_DATA_DIR=$HOME/.cline
SKILLS_DIR=$CLINE_DATA_DIR/skills
```

Each skill is a subdirectory of `SKILLS_DIR` containing
`SKILL.md`. Example:

```
~/.cline/skills/
├── cline-driver/
│   └── SKILL.md
├── another-skill/
│   └── SKILL.md
```

`CLINE_DATA_DIR` can be overridden via the `--data-dir` flag
on `cline` and via the `CLINE_DATA_DIR` env var. If the loop
harness uses a non-default data dir, the agent must mirror the
skill there.

## The `SKILL.md` frontmatter contract

Required fields (verified against v3.0.35):

```yaml
---
name: <kebab-case-name>             # REQUIRED. Matches the dir name.
description: <one-paragraph pitch>  # REQUIRED. Cline uses this for trigger matching.
version: <semver>                   # OPTIONAL but recommended.
author: <string>                    # OPTIONAL but recommended.
---
```

Notes from real installs:

- `name` should be kebab-case and should match the directory
  name (`cline-driver/` → `name: cline-driver`).
- `description` is what Cline uses to decide *whether* to load
  the skill on a given user prompt. Write it as the trigger
  condition, not as a tagline. "Drives Cline on small Python
  coding tasks. Load this when a user asks Cline to create a
  small file, fix a single-function bug, or add type hints to
  a tiny module." is a good description. "A skill for coding"
  is not — Cline will skip it.
- `version` is free-form semver. There is no registry or
  signing; it's for the author and for any future
  "which version is installed?" check.
- `author` is also free-form.
- The body of `SKILL.md` is plain Markdown. Cline reads it
  top-to-bottom into the system prompt slot reserved for the
  skill, so structure it as: short summary, when-to-load,
  operating protocol, anti-patterns, optional failure
  recovery. Don't pad it — every token costs the inner loop.
- Cline does **not** currently load a `references/` directory
  automatically (verified against Cline v3.0.35 across providers).
  All content Cline sees lives in `SKILL.md`. The `references/`
  directory is for the *agent* (the human / Hermes side) building
  and debugging the skill, not for Cline itself.

## Install / uninstall

Install:

```bash
mkdir -p ~/.cline/skills/<name>
cp skills/<name>/SKILL.md ~/.cline/skills/<name>/SKILL.md
```

Uninstall:

```bash
rm -rf ~/.cline/skills/<name>
```

Cline picks up new skills on its next invocation; no daemon
restart is needed.

## A known-good starter

See `templates/cline-skill-stub.md` in this skill for a
copy-paste starter SKILL.md. It was developed against
`cline-driver` on 2026-07-03 and contains the trigger /
protocol / anti-patterns / failure-recovery skeleton that
works for small-Python-task skills.

## What the `verifiers/instruments/cline-skills-dir.sh` does NOT tell you

The instrument prints the *default* path. If a loop run uses
`--data-dir <other>`, the path changes. The `cline` binary
itself reads from `process.env.HOME` (or the data-dir flag) —
not from any global registry. So:

- For the default Hermes-spawned Cline sessions in this
  profile, `~/.cline/skills/` is correct.
- For `--worktree` or `--data-dir` invocations, mirror the
  skill into the corresponding sub-tree.
- For Docker or CI runs, set `CLINE_DATA_DIR` (or pass
  `--data-dir`) before invoking `cline`.

## The `cline` flag set that *attempts* to load skills

There is **no explicit `--skill <name>` flag** in v3.0.35.
Cline matches user prompts to skills by `description` field
text similarity. To force a skill to load for one task,
include a clear pointer in the prompt itself: "Use the
`cline-driver` skill." This works because the body of
`SKILL.md` is part of the system prompt; the prompt's mention
of the skill name gives Cline a positive trigger.

If a future Cline version adds a `--skill` flag, prefer it
over prompt-based triggers — it's deterministic.
