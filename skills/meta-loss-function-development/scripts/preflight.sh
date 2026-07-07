#!/usr/bin/env bash
# preflight.sh — gate-enforcement check for the meta-skill.
#
# The meta-skill's Round 0 prose instructs the assistant
# to run this script as the first mutating action. If
# the script exits 0, the gate is satisfied and the
# meta-skill can proceed. If it exits non-zero, the
# gate is incomplete and the meta-skill MUST NOT scaffold,
# MUST NOT run destructive git operations, and MUST NOT
# call any tool that mutates state under the project root
# until the gate is satisfied.
#
# Usage: preflight.sh [--check] [--project-root PATH]
#
#   --check            check-only mode (default; the
#                      current behavior). Reserved for
#                      future use; --init and --verify
#                      modes are not implemented yet.
#   --project-root PATH  absolute path to the harness
#                      project root (the directory that
#                      will contain GOAL.md, verifiers/,
#                      test-tasks/, AGENTS.md, etc.).
#                      Defaults to $LFD_PROJECT_DIR or
#                      the current working directory.
#
# Exit codes:
#   0  gate is satisfied (all required handoff files
#      exist and are non-empty)
#   1  gate is incomplete (one or more required
#      handoff files missing or empty)
#   2  setup error (project root does not exist or
#      is not a directory, or --project-root argument
#      is malformed)
#
# This script is in the meta-skill's own scripts/ dir
# so it ships with the skill. It does not depend on
# any file in the LFD repo. The only external file it
# references by name is "lfd-thinking-protocols" — the
# skill the assistant must load to satisfy the gate.

set -uo pipefail

CHECK_ONLY=true
PROJECT_ROOT="${LFD_PROJECT_DIR:-$(pwd)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=true; shift ;;
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --project-root=*) PROJECT_ROOT="${1#*=}"; shift ;;
    --help|-h)
      awk 'NR>1 && /^[^#]/{exit} NR>1{sub(/^# ?/,""); print}' "$0"
      exit 0
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# ----- validate project root -----

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "FAIL: --project-root is required (or set LFD_PROJECT_DIR)" >&2
  exit 2
fi
if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "FAIL: project root does not exist or is not a directory: $PROJECT_ROOT" >&2
  exit 2
fi

# ----- check the gate handoff files -----

REQUIRED_FILES=(
  "$PROJECT_ROOT/handoffs/01-target.md"
  "$PROJECT_ROOT/handoffs/02-loss-shape.md"
)

failed=()
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    failed+=("missing: ${f#$PROJECT_ROOT/}")
  elif [[ ! -s "$f" ]]; then
    failed+=("empty:   ${f#$PROJECT_ROOT/}")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  cat >&2 <<EOF
FAIL: meta-skill gate is incomplete.

The following required handoff files are missing or empty:
EOF
  for entry in "${failed[@]}"; do
    echo "  $entry" >&2
  done
  cat >&2 <<EOF

The meta-skill's Round 0 prose says: "Without the handoff,
the rest of Round 0 does not start." The preflight enforces
that — the gate is incomplete and scaffolding MUST NOT begin.

To satisfy the gate:
  1. Load the lfd-thinking-protocols skill.
  2. Run Gate 1 (clarify-target). The user fills in the
     template; the skill writes handoffs/01-target.md.
  3. Run Gate 2 (shape-loss). The user fills in the
     template; the skill writes handoffs/02-loss-shape.md.
  4. Re-run this preflight. It will return 0.
  5. Proceed with Round 0 (scaffold the harness).

The user can also override this preflight by explicitly
running this script with LFD_PREFLIGHT_OVERRIDE=1 and
then typing the override reason, but that is a stop-the-loop
action requiring user confirmation.
EOF
  exit 1
fi

exit 0
