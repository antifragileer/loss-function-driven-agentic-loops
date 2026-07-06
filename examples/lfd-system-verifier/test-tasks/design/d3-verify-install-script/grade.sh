#!/usr/bin/env bash
# d3-verify-install-script grader
# Runs install.sh --check against a fresh profile and asserts
# the bundle installs cleanly.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
TEST_PROFILE="$(mktemp -d -t lfd-verify-d3-XXXXXX)"
CHECK_LOG="$(mktemp -t lfd-verify-d3-check-XXXXXX.log)"

score=0.0
cleanup() {
  rm -rf "$TEST_PROFILE"
  rm -f "$CHECK_LOG"
}
trap cleanup EXIT

if [[ ! -x "$INSTALL_SH" ]]; then
  echo "FAIL: install.sh not found or not executable" >&2
  echo "score=$score"
  exit 1
fi

# First install (without --check), then check
mkdir -p "$TEST_PROFILE/skills"
if ! "$INSTALL_SH" "$TEST_PROFILE" --force >/dev/null 2>&1; then
  echo "FAIL: install.sh --force failed" >&2
  echo "score=$score"
  exit 1
fi

# Now run --check
if ! "$INSTALL_SH" --check "$TEST_PROFILE" > "$CHECK_LOG" 2>&1; then
  echo "FAIL: install.sh --check exited non-zero" >&2
  cat "$CHECK_LOG" >&2
  echo "score=$score"
  exit 1
fi

# Verify the report mentions the right number of skills
# (11 in 2.1.0/2.2.0; 12 in 2.3.0+ with lfd-thinking-protocols added)
if ! grep -qE "(11|12) LFD bundle skills" "$CHECK_LOG"; then
  echo "FAIL: check report does not mention 11 or 12 skills" >&2
  cat "$CHECK_LOG" >&2
  echo "score=$score"
  exit 1
fi

# Count actual skill dirs (must be 11 or 12)
n_skills=$(ls -1 "$TEST_PROFILE/skills" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$n_skills" -ne 11 && "$n_skills" -ne 12 ]]; then
  echo "FAIL: profile has $n_skills skill dirs, expected 11 or 12" >&2
  echo "score=$score"
  exit 1
fi

# d3 negative check: the install script must NOT have been replaced
# with a no-op shim. (Anti-cheat: the agent might "fix" install.sh
# by making it a trivial success-only stub.) Verify the script has
# the structural pieces of a real installer.
NEG_FAIL=""
if ! grep -q 'install_order' "$INSTALL_SH" 2>/dev/null; then
  NEG_FAIL="install.sh does not reference install_order — likely a stub"
fi
if ! grep -qE '\.md|copy|chmod' "$INSTALL_SH" 2>/dev/null; then
  NEG_FAIL="install.sh has no install operations (no .md/copy/chmod)"
fi
if [[ -n "$NEG_FAIL" ]]; then
  echo "FAIL: $NEG_FAIL" >&2
  exit 1
fi

score=1.0
echo "score=$score"
exit 0
