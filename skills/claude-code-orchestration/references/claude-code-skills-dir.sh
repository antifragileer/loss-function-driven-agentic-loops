#!/usr/bin/env bash
# claude-code-skills-dir.sh — print the directory Claude Code
# scans for skills. Used by cycle.sh to install the candidate
# skill where the inner agent will pick it up.
#
# Claude Code reads skills from:
#   1. Project: <project>/.claude/skills/ (team-shared, git-tracked)
#   2. User: ~/.claude/skills/ (personal, global)
#
# The wrapper prefers the project dir if it exists (so the
# loop's candidate is isolated to the scaffolded project).
# Falls back to the user dir otherwise.
set -euo pipefail

PROJECT_SKILLS_DIR="${PROJECT_DIR:-.}/.claude/skills"
USER_SKILLS_DIR="${HOME}/.claude/skills"

if [[ -d "$(dirname "$PROJECT_SKILLS_DIR")" ]]; then
  echo "CLAUDE_SKILLS_DIR=$PROJECT_SKILLS_DIR"
  echo "---"
  echo "Project-level skills (git-tracked). Each skill is a directory containing SKILL.md."
else
  echo "CLAUDE_SKILLS_DIR=$USER_SKILLS_DIR"
  echo "---"
  echo "User-level skills (personal, global). Each skill is a directory containing SKILL.md."
fi
