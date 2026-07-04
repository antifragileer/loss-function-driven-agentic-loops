#!/usr/bin/env bash
# tokens-remaining.sh — print tokens remaining out of
# TOKEN_BUDGET. The fake agent uses 0 tokens, so this is
# always TOKEN_BUDGET.
set -euo pipefail

USED_FILE="${PROJECT_DIR:-.}/logs/tokens_used.txt"
# Default to a very large budget for the verifier; the fake
# agent uses 0 tokens, so this never exhausts. The real loop
# would use TOKEN_BUDGET=<actual-budget>.
BUDGET="${TOKEN_BUDGET:-1000000}"
USED=0
[[ -s "$USED_FILE" ]] && USED=$(cat "$USED_FILE")
echo $(( BUDGET - USED ))
