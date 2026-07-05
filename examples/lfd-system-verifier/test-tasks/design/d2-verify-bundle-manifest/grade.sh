#!/usr/bin/env bash
# d2-verify-bundle-manifest grader
# Verifies the LFD bundle.json manifest is correct.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
BUNDLE_JSON="$REPO_ROOT/bundle.json"

score=0.0

if [[ ! -f "$BUNDLE_JSON" ]]; then
  echo "FAIL: bundle.json not found at $BUNDLE_JSON" >&2
  echo "score=$score"
  exit 1
fi

python3 - "$BUNDLE_JSON" <<'PYEOF'
import json, sys
b = json.load(open(sys.argv[1]))
if b["version"] not in ("2.1.0", "2.2.0"):
    print(f"FAIL: version {b['version']!r} != 2.1.0", file=sys.stderr); sys.exit(1)
if len(b["skills"]) != 11:
    print(f"FAIL: {len(b['skills'])} skills != 11", file=sys.stderr); sys.exit(1)
if len(b["install_order"]) != 11:
    print(f"FAIL: {len(b['install_order'])} install_order != 11", file=sys.stderr); sys.exit(1)
if {s["name"] for s in b["skills"]} != set(b["install_order"]):
    print("FAIL: skills != install_order", file=sys.stderr); sys.exit(1)
if b["license"] != "MIT":
    print(f"FAIL: license {b['license']!r} != MIT", file=sys.stderr); sys.exit(1)
if not b.get("repository", "").startswith("https://github.com/antifragileer"):
    print(f"FAIL: repository {b.get('repository')!r}", file=sys.stderr); sys.exit(1)
expected_adapters = {"cline-orchestration", "claude-code-orchestration",
                     "codex-orchestration", "hermes-agent-orchestration",
                     "opencode-orchestration", "fake-agent-orchestration"}
actual_adapters = {s["name"] for s in b["skills"] if s["role"] == "agent-adapter"}
if actual_adapters != expected_adapters:
    print(f"FAIL: adapters {actual_adapters} != {expected_adapters}", file=sys.stderr)
    sys.exit(1)
# d2 negative check: bundle.json must NOT be a minimal stub
# (catches the cheat where the agent replaces bundle.json with
# a tiny file that satisfies the structure check above).
PYEOF
RC=$?

# Negative check: bundle.json must contain real skill descriptions,
# not just empty placeholders. If the agent replaced it with a
# 5-line stub, this catches it.
NEG_FAIL=""
bundle_size=$(wc -c < "$BUNDLE_JSON" 2>/dev/null | tr -d ' ')
if [[ "${bundle_size:-0}" -lt 1000 ]]; then
  NEG_FAIL="bundle.json is suspiciously small ($bundle_size bytes) — likely a stub"
fi
# Also: every skill must have a non-empty description field.
missing_desc=$(python3 -c "
import json, sys
b = json.load(open(sys.argv[1]))
empty = [s['name'] for s in b['skills'] if not s.get('description', '').strip()]
print(' '.join(empty))
" "$BUNDLE_JSON" 2>/dev/null)
if [[ -n "$missing_desc" ]]; then
  NEG_FAIL="bundle.json has skills with empty description: $missing_desc"
fi
if [[ -n "$NEG_FAIL" ]]; then
  echo "FAIL: $NEG_FAIL" >&2
  exit 1
fi

if [[ $RC -eq 0 ]]; then score=1.0; fi
echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
