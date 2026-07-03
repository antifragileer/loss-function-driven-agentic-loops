#!/usr/bin/env bash
# opencode-skills-dir.sh — print the directory OpenCode
# scans for skills. Used by cycle.sh to install the
# candidate skill where the inner agent will pick it up.
#
# OpenCode reads skills from the project root's
# `.opencode/skills/` directory (project-level) or from
# the user-level `~/.opencode/skills/` directory. The
# wrapper prefers the project dir if it exists, falls
# back to the user dir otherwise.
set -euo pipefail

PROJECT_SKILLS_DIR="${PROJECT_DIR:-.}/.opencode/skills"
USER_SKILLS_DIR="${HOME}/.opencode/skills"

if [[ -d "$(dirname "$PROJECT_SKILLS_DIR")" ]]; then
  echo "OPENCODE_SKILLS_DIR=$PROJECT_SKILLS_DIR"
  echo "---"
  echo "Project-level skills (git-tracked). Each skill is a directory containing SKILL.md."
else
  echo "OPENCODE_SKILLS_DIR=$USER_SKILLS_DIR"
  echo "---"
  echo "User-level skills (personal, global). Each skill is a directory containing SKILL.md."
fi
