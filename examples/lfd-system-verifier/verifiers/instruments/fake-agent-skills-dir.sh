#!/usr/bin/env bash
# fake-agent-skills-dir.sh — print the directory the fake
# agent scans for skills. Used by cycle.sh to install the
# candidate skill where the inner agent will pick it up.
#
# For the verifier, candidates are written to
# $PROJECT_DIR/.fake-skills/ which the loop's "install the
# candidate" step creates on demand.
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
FAKE_SKILLS_DIR="$PROJECT_DIR/.fake-skills"

echo "FAKE_SKILLS_DIR=$FAKE_SKILLS_DIR"
echo "---"
echo "Fake agent skills dir (for the LFD system verifier)."
echo "Cycle.sh creates this on demand; the cycle's candidate"
echo "skill is copied here after each wrapper run."
