#!/usr/bin/env bash
# hermes-agent-skills-dir.sh — print the directory Hermes
# Agent scans for skills. Used by cycle.sh to install the
# candidate skill where the inner agent will pick it up.
#
# Hermes reads skills from the *active profile's* skills/
# directory. Default profile: ~/.hermes/skills/. Named
# profiles: ~/.hermes/profiles/<name>/skills/.
set -euo pipefail

HERMES_PROFILE="${HERMES_PROFILE:-default}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

if [[ "$HERMES_PROFILE" == "default" ]]; then
  SKILLS_DIR="$HERMES_HOME/skills"
else
  SKILLS_DIR="$HERMES_HOME/profiles/$HERMES_PROFILE/skills"
fi

echo "HERMES_SKILLS_DIR=$SKILLS_DIR"
echo "---"
echo "Profile: $HERMES_PROFILE"
echo "Each skill is a directory containing SKILL.md with YAML frontmatter."
