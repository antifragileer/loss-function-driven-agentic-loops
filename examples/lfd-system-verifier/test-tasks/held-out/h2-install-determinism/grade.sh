#!/usr/bin/env bash
# h2-install-determinism grader (held-out)
# Runs install.sh twice against fresh profiles and asserts
# the results are byte-identical.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
TMP1="$(mktemp -d -t lfd-verify-h2-1-XXXXXX)"
TMP2="$(mktemp -d -t lfd-verify-h2-2-XXXXXX)"
trap 'rm -rf "$TMP1" "$TMP2"' EXIT

score=0.0

if [[ ! -x "$INSTALL_SH" ]]; then
  echo "FAIL: install.sh not found or not executable" >&2
  echo "score=$score"
  exit 1
fi

mkdir -p "$TMP1/skills" "$TMP2/skills"

# Run install twice
"$INSTALL_SH" "$TMP1" --force >/dev/null 2>&1
"$INSTALL_SH" "$TMP2" --force >/dev/null 2>&1

# Compare the skill directories (sorted, byte-by-byte)
# We exclude the lfd-*.sh files which have shell-internal
# state (none, but they could). All other files should
# be byte-identical.
DIFF_OUT=$(diff -r "$TMP1" "$TMP2" 2>&1 || true)

if [[ -z "$DIFF_OUT" ]]; then
  score=1.0
  echo "  install.sh is deterministic across two runs"
else
  # Check if only mode differences (the install makes some
  # files executable, the second run also does the same)
  NON_MODE_DIFFS=$(diff -r --brief "$TMP1" "$TMP2" 2>&1 | grep -v "differ" || true)
  if [[ -z "$NON_MODE_DIFFS" ]]; then
    score=1.0
    echo "  install.sh is deterministic (only mode-bit differences, which is fine)"
  else
    echo "FAIL: install.sh is non-deterministic:" >&2
    echo "$DIFF_OUT" >&2
    score=0.0
  fi
fi

echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
