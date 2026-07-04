#!/usr/bin/env bash
# fake-agent-skills-dir.sh — print the directory the fake
# agent scans for skills. Used by cycle.sh to install the
# candidate skill where the inner agent will pick it up.
#
# The fake agent has no real skills directory. Candidates
# are written to <cwd>/.fake-skills/ which the wrapper
# creates on demand. The cycle.sh script uses this
# instrument to learn where to copy the candidate.
set -euo pipefail

PROJECT_CWD="${PROJECT_DIR:-.}"
FAKE_SKILLS_DIR="$PROJECT_CWD/.fake-skills"

echo "FAKE_SKILLS_DIR=$FAKE_SKILLS_DIR"
echo "---"
echo "Fake agent has no real skills directory. Candidates are"
echo "written to $FAKE_SKILLS_DIR which the wrapper creates on demand."
