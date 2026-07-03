#!/usr/bin/env bash
# uninstall.sh — remove the loss-function-driven-agentic-loops bundle
# from a Hermes profile's skills/ directory.
#
# Usage:
#   uninstall.sh <profile-dir>             # remove
#   uninstall.sh <profile-dir> --dry-run   # show what would happen
#   uninstall.sh -h | --help
#
# Exit codes:
#   0: success (or nothing to remove)
#   1: usage error
#   3: profile-dir missing
#
# Only removes the 6 skills that this bundle installed plus the
# lfd-bundle.json / lfd-install.sh / lfd-uninstall.sh marker files.
# Does NOT remove any other skills in the profile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  awk '/^#!/{next} /^[^#]/{exit} {gsub(/^# ?/, ""); print}' "$0" | head -40
  exit 1
}

PROFILE_DIR=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown flag: $1" >&2; exit 1 ;;
    *)
      [[ -z "$PROFILE_DIR" ]] || { echo "error: unexpected positional arg: $1" >&2; exit 1; }
      PROFILE_DIR="$1"
      shift
      ;;
  esac
done

[[ -z "$PROFILE_DIR" ]] && usage

if [[ ! -d "$PROFILE_DIR" ]]; then
  echo "error: profile-dir does not exist: $PROFILE_DIR" >&2
  exit 3
fi

# Resolve bundle manifest. Prefer the one in the profile (the
# install.sh wrote it there), fall back to the script's dir.
BUNDLE_JSON=""
if [[ -f "$PROFILE_DIR/lfd-bundle.json" ]]; then
  BUNDLE_JSON="$PROFILE_DIR/lfd-bundle.json"
elif [[ -f "$SCRIPT_DIR/../bundle.json" ]]; then
  BUNDLE_JSON="$(cd "$SCRIPT_DIR/.." && pwd)/bundle.json"
else
  echo "error: cannot find bundle.json (looked in $PROFILE_DIR and $SCRIPT_DIR/..)" >&2
  exit 1
fi

# Get the list of skills from the manifest
SKILL_NAMES=$(python3 -c "
import json
d = json.load(open('$BUNDLE_JSON'))
print('\n'.join(d['install_order']))
")

SKILLS_TARGET="$PROFILE_DIR/skills"
MARKER_FILES=(
  "$PROFILE_DIR/lfd-bundle.json"
  "$PROFILE_DIR/bundle.json"
  "$PROFILE_DIR/lfd-install.sh"
  "$PROFILE_DIR/lfd-uninstall.sh"
)

echo "[uninstall] bundle: $BUNDLE_JSON" >&2
echo "[uninstall] target: $PROFILE_DIR" >&2
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[uninstall] DRY-RUN — no files will be removed" >&2
fi
echo "" >&2

# Remove each skill
n_removed=0
for name in $SKILL_NAMES; do
  dst="$SKILLS_TARGET/$name"
  if [[ -d "$dst" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "  would remove: $dst" >&2
    else
      rm -rf "$dst"
      echo "  removed: $dst" >&2
    fi
    n_removed=$((n_removed + 1))
  fi
done

# Remove marker files
for f in "${MARKER_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "  would remove: $f" >&2
    else
      rm -f "$f"
      echo "  removed: $f" >&2
    fi
  fi
done

echo "" >&2
echo "[uninstall] done. $n_removed skills $( [[ "$DRY_RUN" == "true" ]] && echo "would be " )removed." >&2
