#!/usr/bin/env bash
# codex-skills-dir.sh — print the directory Codex scans for
# skills. Used by cycle.sh to install the candidate skill
# where the inner agent will pick it up.
#
# Codex reads skills from a `skills/` subdirectory of the
# project root (alongside the agent's own `.codex/`
# config). Per project, NOT user-global. The wrapper
# prefers the project dir if it exists, falls back to a
# user-level dir otherwise.
set -euo pipefail

PROJECT_SKILLS_DIR="${PROJECT_DIR:-.}/.codex/skills"
USER_SKILLS_DIR="${HOME}/.codex/skills"

if [[ -d "$(dirname "$PROJECT_SKILLS_DIR")" ]]; then
  echo "CODEX_SKILLS_DIR=$PROJECT_SKILLS_DIR"
  echo "---"
  echo "Project-level skills (git-tracked). Each skill is a directory containing SKILL.md."
else
  echo "CODEX_SKILLS_DIR=$USER_SKILLS_DIR"
  echo "---"
  echo "User-level skills (personal, global). Each skill is a directory containing SKILL.md."
fi
