#!/usr/bin/env bash
# tokens-this-iter.sh — print tokens used in the last cycle.
# The fake agent uses 0 tokens per cycle.
set -euo pipefail

F="${PROJECT_DIR:-.}/logs/tokens_last_cycle.txt"
[[ -s "$F" ]] && cat "$F" || echo 0
