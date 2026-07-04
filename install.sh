#!/usr/bin/env bash
# install.sh — install the loss-function-driven-agentic-loops bundle
# into a Hermes profile's skills/ directory.
#
# Usage:
#   install.sh <profile-dir>            # install
#   install.sh <profile-dir> --dry-run  # show what would happen
#   install.sh <profile-dir> --force    # overwrite existing skills
#   install.sh --list                   # list the 11 skills in this bundle
#   install.sh --check <profile-dir>    # verify a profile is installed
#   install.sh -h | --help              # this help
#
# Exit codes:
#   0: success (or already installed with no changes)
#   1: usage error
#   2: bundle manifest missing or invalid
#   3: profile-dir missing or not writable
#   4: collision (a skill already exists; use --force to overwrite)
#   5: install verified missing files
#
# This script is portable — no hard paths to the user's machine.
# It works on macOS, Linux, WSL. No external dependencies beyond
# bash 4+ and a JSON-aware python3 (or jq).

set -euo pipefail

# ----- locate the bundle root (the dir this script lives in) -----

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

if [[ ! -f "$BUNDLE_ROOT/bundle.json" ]]; then
  echo "error: bundle.json not found in $BUNDLE_ROOT" >&2
  echo "  this script must be run from the bundle's root directory" >&2
  exit 2
fi

# ----- helpers -----

# Parse bundle.json with python (no jq dependency). Usage: bget KEY
# If KEY resolves to a list, prints one element per line.
# If KEY resolves to a dict or scalar, prints JSON.
bget() {
  python3 -c "
import json, sys
d = json.load(open('$BUNDLE_ROOT/bundle.json'))
keys = sys.argv[1].split('.')
for k in keys:
    if k.isdigit(): d = d[int(k)]
    else: d = d[k]
if isinstance(d, list):
    for item in d:
        if isinstance(item, dict): print(json.dumps(item))
        else: print(item)
elif isinstance(d, dict):
    print(json.dumps(d))
else:
    print(d)
" "$1"
}

usage() {
  awk '/^#!/{next} /^[^#]/{exit} {gsub(/^# ?/, ""); print}' "$0" | head -40
  exit 1
}

# ----- argument parsing -----

PROFILE_DIR=""
DRY_RUN="false"
FORCE="false"
LIST_ONLY="false"
CHECK_ONLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --force) FORCE="true"; shift ;;
    --list) LIST_ONLY="true"; shift ;;
    --check)
      CHECK_ONLY="true"
      shift
      [[ $# -gt 0 ]] || { echo "error: --check requires a <profile-dir>" >&2; exit 1; }
      PROFILE_DIR="$1"
      shift
      ;;
    -h|--help) usage ;;
    -*) echo "unknown flag: $1" >&2; exit 1 ;;
    *)
      [[ -z "$PROFILE_DIR" ]] || { echo "error: unexpected positional arg: $1" >&2; exit 1; }
      PROFILE_DIR="$1"
      shift
      ;;
  esac
done

# ----- --list -----

if [[ "$LIST_ONLY" == "true" ]]; then
  echo "Bundle: $(bget bundle) v$(bget version)"
  echo ""
  echo "Skills (install_order):"
  python3 -c "
import json
d = json.load(open('$BUNDLE_ROOT/bundle.json'))
for name in d['install_order']:
    s = next(s for s in d['skills'] if s['name'] == name)
    req = 'required' if s.get('required', True) else 'optional'
    print(f\"  {s['name']:36s}  v{s['version']:8s}  [{req:8s}]  {s['role']:14s}  {s['summary'][:60]}\")
"
  exit 0
fi

# ----- --check -----

if [[ "$CHECK_ONLY" == "true" ]]; then
  if [[ -z "$PROFILE_DIR" ]]; then
    echo "error: --check requires a <profile-dir>" >&2
    exit 1
  fi
  if [[ ! -d "$PROFILE_DIR" ]]; then
    echo "FAIL: profile-dir does not exist: $PROFILE_DIR" >&2
    exit 3
  fi
  skills_target="$PROFILE_DIR/skills"
  if [[ ! -d "$skills_target" ]]; then
    echo "FAIL: no skills/ directory at $PROFILE_DIR" >&2
    exit 3
  fi
  missing=()
  for name in $(bget install_order); do
    if [[ ! -d "$skills_target/$name" ]]; then
      missing+=("$name")
    elif [[ ! -f "$skills_target/$name/SKILL.md" ]]; then
      missing+=("$name (no SKILL.md)")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    n=$(ls -1 "$skills_target" | wc -l | tr -d ' ')
    echo "OK: all $(bget install_order | wc -l | tr -d ' ') LFD bundle skills present in $skills_target (total: $n skill dirs)"
    exit 0
  else
    echo "FAIL: missing skills in $skills_target:" >&2
    for m in "${missing[@]}"; do
      echo "  - $m" >&2
    done
    exit 5
  fi
fi

# ----- normal install -----

if [[ -z "$PROFILE_DIR" ]]; then
  usage
fi

if [[ ! -d "$PROFILE_DIR" ]]; then
  echo "error: profile-dir does not exist: $PROFILE_DIR" >&2
  echo "  create it first, or pass the full path to an existing profile" >&2
  exit 3
fi

# Check writability
if [[ ! -w "$PROFILE_DIR" ]]; then
  echo "error: profile-dir is not writable: $PROFILE_DIR" >&2
  exit 3
fi

SKILLS_TARGET="$PROFILE_DIR/skills"
mkdir -p "$SKILLS_TARGET"

# Check for collisions
collisions=()
for name in $(bget install_order); do
  if [[ -d "$SKILLS_TARGET/$name" && "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
    collisions+=("$name")
  fi
done

if [[ ${#collisions[@]} -gt 0 ]]; then
  echo "error: these skills already exist in $SKILLS_TARGET:" >&2
  for c in "${collisions[@]}"; do
    echo "  - $c" >&2
  done
  echo "use --force to overwrite (you'll lose any local edits to those skill dirs)" >&2
  exit 4
fi

# Copy each skill
echo "[install] bundle: $(bget bundle) v$(bget version)" >&2
echo "[install] target: $SKILLS_TARGET" >&2
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[install] DRY-RUN — no files will be written" >&2
fi
echo "" >&2

n_installed=0
for name in $(bget install_order); do
  src="$BUNDLE_ROOT/skills/$name"
  dst="$SKILLS_TARGET/$name"
  if [[ ! -d "$src" ]]; then
    echo "  SKIP: $name (source not found in bundle)" >&2
    continue
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -d "$dst" ]]; then
      echo "  would overwrite: $dst" >&2
    else
      echo "  would install:   $dst" >&2
    fi
  else
    # Remove existing if --force
    [[ -d "$dst" && "$FORCE" == "true" ]] && rm -rf "$dst"
    cp -R "$src" "$dst"
    # Make scripts executable
    if [[ -d "$dst/scripts" ]]; then
      find "$dst/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
    fi
    echo "  install: $dst" >&2
  fi
  n_installed=$((n_installed + 1))
done

# Copy the bundle.json itself so the user can verify what was installed
if [[ "$DRY_RUN" != "true" ]]; then
  cp "$BUNDLE_ROOT/bundle.json" "$PROFILE_DIR/lfd-bundle.json"
  echo "  install: $PROFILE_DIR/lfd-bundle.json" >&2
  cp "$BUNDLE_ROOT/install.sh" "$PROFILE_DIR/lfd-install.sh"
  cp "$BUNDLE_ROOT/uninstall.sh" "$PROFILE_DIR/lfd-uninstall.sh"
  # Copy bundle.json next to the lfd-install.sh copy too,
  # so the copied script can find it via its own SCRIPT_DIR.
  cp "$BUNDLE_ROOT/bundle.json" "$PROFILE_DIR/bundle.json"
  chmod +x "$PROFILE_DIR/lfd-install.sh" "$PROFILE_DIR/lfd-uninstall.sh"
  echo "  install: $PROFILE_DIR/lfd-install.sh" >&2
  echo "  install: $PROFILE_DIR/lfd-uninstall.sh" >&2
  echo "  install: $PROFILE_DIR/bundle.json" >&2
fi

echo "" >&2
echo "[install] done. $n_installed skills $( [[ "$DRY_RUN" == "true" ]] && echo "would be " )installed." >&2
echo "" >&2
echo "Next steps:" >&2
echo "  1. Open a session under the profile at $PROFILE_DIR" >&2
echo "  2. Ask for a /goal prompt. The meta-skill triggers" >&2
echo "     on spec-shaped phrases only, e.g.:" >&2
echo "       'Create a /goal prompt that builds X in Y with Z.'" >&2
echo "       'Produce a /goal prompt for /path/to/spec.md.'" >&2
echo "     DO NOT say 'use LFD to build X' — that loads" >&2
echo "     harness-scaffold + loop-driver and starts the loop" >&2
echo "     in the current session without a /goal block." >&2
echo "  3. The meta-skill emits a paste-able /goal block." >&2
echo "  4. Paste it into a FRESH session; the loop scaffolds" >&2
echo "     the project tree and runs the design cycles." >&2
echo "" >&2
echo "To verify the install later:  $0 --check $PROFILE_DIR" >&2
echo "To uninstall:                $PROFILE_DIR/lfd-uninstall.sh $PROFILE_DIR" >&2
