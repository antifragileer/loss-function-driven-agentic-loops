#!/usr/bin/env bash
# h5-compatibility-matrix-consistency grader (held-out)
# Verifies the compatibility.md matrix is internally consistent.
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
COMPAT="$REPO_ROOT/compatibility.md"
BUNDLE_JSON="$REPO_ROOT/bundle.json"

if [[ ! -f "$COMPAT" ]]; then
  echo "FAIL: compatibility.md not found" >&2
  echo "score=0.0"
  exit 1
fi
if [[ ! -f "$BUNDLE_JSON" ]]; then
  echo "FAIL: bundle.json not found" >&2
  echo "score=0.0"
  exit 1
fi

python3 - "$COMPAT" "$BUNDLE_JSON" <<'PYEOF'
import json, sys, re
compat_path, bundle_path = sys.argv[1], sys.argv[2]
compat = open(compat_path).read()
bundle = json.load(open(bundle_path))
bundle_skills = {s["name"] for s in bundle["skills"]}

# Find the "Current versions" table; check that every skill
# listed there exists in the bundle
in_versions = set()
for line in compat.splitlines():
    # Match table rows: "| `skill-name` | version |"
    m = re.match(r"^\|\s*`([a-z][a-z0-9-]+)`\s*\|\s*[\d.]+\s*\|", line)
    if m:
        in_versions.add(m.group(1))

missing_in_bundle = in_versions - bundle_skills
if missing_in_bundle:
    print(f"FAIL: in compatibility.md but not in bundle: {missing_in_bundle}",
          file=sys.stderr)
    sys.exit(1)

missing_in_compat = bundle_skills - in_versions
if missing_in_compat:
    print(f"FAIL: in bundle but not in compatibility.md: {missing_in_compat}",
          file=sys.stderr)
    sys.exit(1)

# Find the version matrix; check that every skill name that
# appears as a column header (short form) maps to a real skill
matrix_section = re.search(
    r"## The version matrix\s*\n(.*?)(?=\n## |\Z)",
    compat, re.S)
if not matrix_section:
    print("FAIL: no '## The version matrix' section", file=sys.stderr)
    sys.exit(1)

# The matrix has short forms like "loss-fn-design 2.x" or
# "lfd 2.x" or "cline 2.x" or "cc 1.x" etc. We just check
# that the matrix mentions each full skill name.
for skill in bundle_skills:
    if skill not in compat:
        print(f"FAIL: skill {skill!r} not mentioned in compatibility.md body",
              file=sys.stderr)
        sys.exit(1)
PYEOF
RC=$?

score=0.0
if [[ $RC -eq 0 ]]; then score=1.0; fi
echo "score=$score"
exit $([ "$score" = "1.0" ] && echo 0 || echo 1)
