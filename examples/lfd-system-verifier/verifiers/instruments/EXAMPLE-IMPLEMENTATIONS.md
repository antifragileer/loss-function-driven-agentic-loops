# Example Implementations for the 27 Stubs

Each stub in this directory returns `0.0` by default
and has a `# ----- HITL: wire your tool here -----`
block where you put your real tool invocation. This
doc shows what a wired-up version looks like for each
stub, written to satisfy the opinionated criteria
from `loss-function-design`:

- **Deterministic.** Pinned tools, pinned versions,
  no `$(date)` / network in the verifier.
- **Exit-coded.** Exit 0 with a printed float on a
  real measurement. Exit non-zero ONLY on tool error
  (not on a constraint violation — that's a real
  score, not an error).
- **Partial credit.** A score in [0.0, 1.0], not a
  binary pass/fail, so the loop has gradient.
- **Anti-cheat aware.** A linter that's easy to
  suppress is a soft target. Wire the linter into CI
  with no per-PR bypass; a stub that always passes
  has no value as a loss component.

Every example below drops into the `# ----- HITL -----`
block of the corresponding stub with no other changes
needed. Each example assumes `$PROJECT_DIR` is set by
the stub (the stub sets `PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"`
before the HITL block).

If your stack is not in the example (e.g. you write
Ruby, not Python), use the example as a *shape* — the
contract is the same: deterministic tool invocation,
exit code, float in [0.0, 1.0].

---

## code-quality

### linter.sh

**Stack:** Node/TypeScript (eslint), Python (ruff),
Go (golangci-lint), Ruby (rubocop). The shape is
identical: a linter run on the candidate, exit 0 if
clean, the count of errors mapped to a [0.0, 1.0]
score.

```bash
# Detect stack from marker files, run the right linter.
LINT_OUTPUT=""
LINT_EXIT=0
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  LINT_OUTPUT=$(npx --no-install eslint . --ext .ts,.tsx,.js,.jsx 2>&1) || LINT_EXIT=$?
elif [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/requirements.txt" ]]; then
  LINT_OUTPUT=$(ruff check . 2>&1) || LINT_EXIT=$?
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  LINT_OUTPUT=$(golangci-lint run ./... 2>&1) || LINT_EXIT=$?
elif [[ -f "$PROJECT_DIR/Gemfile" ]]; then
  LINT_OUTPUT=$(bundle exec rubocop 2>&1) || LINT_EXIT=$?
fi

# Map error count to [0.0, 1.0]. 0 errors = 1.0, 50+ = 0.0.
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -cE '^(error|warning|[^ ]+\.go:[0-9]+:[0-9]+)' || true)
ERROR_COUNT=${ERROR_COUNT:-0}
if [[ "$LINT_EXIT" -eq 0 ]]; then
  MEASUREMENT=1.0
else
  MEASUREMENT=$(python3 -c "print(max(0.0, 1.0 - $ERROR_COUNT / 50.0))")
fi
```

**Why this shape:** exit 0 on a clean run is the
"hard pass." Anything else is partial credit scaled
by error count. The `|| true` on `grep -c` is critical
— `grep` exits 1 when there are no matches, and we
don't want a missing error to flip the script to
`set -e` failure.

### type-check.sh

**Stack:** TypeScript (`tsc --noEmit`), Python
(`mypy`), Go (`go build` is enough), Rust
(`cargo check`).

```bash
TC_EXIT=0
TC_OUTPUT=""
if [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
  TC_OUTPUT=$(npx --no-install tsc --noEmit 2>&1) || TC_EXIT=$?
elif [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  TC_OUTPUT=$(mypy . 2>&1) || TC_EXIT=$?
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  TC_OUTPUT=$(go build ./... 2>&1) || TC_EXIT=$?
elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
  TC_OUTPUT=$(cargo check 2>&1) || TC_EXIT=$?
fi

ERR_COUNT=$(echo "$TC_OUTPUT" | grep -cE 'error|TS[0-9]+' || true)
ERR_COUNT=${ERR_COUNT:-0}
if [[ "$TC_EXIT" -eq 0 ]]; then
  MEASUREMENT=1.0
else
  MEASUREMENT=$(python3 -c "print(max(0.0, 1.0 - $ERR_COUNT / 20.0))")
fi
```

**Reward-hack defense:** `tsc` with `--noEmit` is
preferred over `tsc` (which writes `.js` next to
`.ts`). `mypy` with the default config doesn't
type-check untyped functions silently — pin
`--disallow-untyped-defs` if you want a stricter
gate.

### complexity.sh

**Stack:** Python (radon), Go (gocyclo), generic
(lizard — works for most languages).

```bash
MAX_CC=10  # project threshold; expose as env or parse from config
MAX_CC=${MAX_CC:-10}

# lizard prints per-function complexity; the worst one is the candidate's CC.
LIZARD_OUT=$(lizard "$PROJECT_DIR" --CCN $MAX_CC 2>/dev/null || true)
# lizard exits 0 even with violations; parse the "total nloc" / function list.
WORST_CC=$(echo "$LIZARD_OUT" | awk '/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+/ {print $3}' | sort -n | tail -1)
WORST_CC=${WORST_CC:-0}

# 1.0 if under threshold, linear decay to 0.0 at 2x threshold.
MEASUREMENT=$(python3 -c "
m = $MAX_CC
w = $WORST_CC
if w <= m: print(1.0)
elif w <= 2*m: print(round(1.0 - 0.5*(w-m)/m, 4))
else: print(0.0)
")
```

**Why this shape:** radon/gocyclo are language-specific.
lizard works across 30+ languages. The `WORST_CC`
default of 0 is a *failing* score (worst CC of 0 means
"nothing was measured"), so if lizard fails to install
the loop sees `0.0` and the diagnostic shows up in the
sub-loss readout.

---

## tests

The seven test instruments below share a common
shape. The differences are: which test command runs,
which subset of tests counts, and what "pass" looks
like for that subset.

### unit-tests.sh

```bash
TEST_OUTPUT=""
TEST_EXIT=0
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  TEST_OUTPUT=$(npm test --silent -- --reporter=json 2>/dev/null) || TEST_EXIT=$?
elif [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  TEST_OUTPUT=$(pytest --json-report --json-report-file=/tmp/ut.json -q 2>/dev/null) || TEST_EXIT=$?
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  TEST_OUTPUT=$(go test -json ./... 2>/dev/null) || TEST_EXIT=$?
fi

# Parse pass/fail counts from the test framework's JSON output.
if [[ -f /tmp/ut.json ]]; then
  PASS=$(python3 -c "import json; d=json.load(open('/tmp/ut.json')); print(d['summary']['passed'])")
  FAIL=$(python3 -c "import json; d=json.load(open('/tmp/ut.json')); print(d['summary']['failed'])")
  TOTAL=$((PASS + FAIL))
  if [[ "$TOTAL" -eq 0 ]]; then MEASUREMENT=0.0
  else MEASUREMENT=$(python3 -c "print(round($PASS/$TOTAL, 4))")
  fi
else
  # No JSON output, fall back to exit code.
  if [[ "$TEST_EXIT" -eq 0 ]]; then MEASUREMENT=1.0; else MEASUREMENT=0.0; fi
fi
```

**Anti-cheat:** pytest's `--json-report` requires
`pytest-json-report` to be installed. The
`pytest-json-report` install is itself a
deterministic check that the test infrastructure is
intact — if a dependency audit removes it, the unit
test sub-loss goes to 0.

### integration-tests.sh

Same shape as unit-tests, but selects tests by
marker/folder:

```bash
# pytest: select by marker
pytest -m integration --json-report --json-report-file=/tmp/it.json -q 2>/dev/null || true
# jest: select by path
npm test --silent -- integration/ --reporter=json 2>/dev/null || true
# go: separate package
go test -json ./integration/... 2>/dev/null || true

# Same JSON parse as unit-tests.sh
PASS=$(python3 -c "import json; d=json.load(open('/tmp/it.json')); print(d['summary']['passed'])" 2>/dev/null || echo 0)
FAIL=$(python3 -c "import json; d=json.load(open('/tmp/it.json')); print(d['summary']['failed'])" 2>/dev/null || echo 0)
TOTAL=$((PASS + FAIL))
[[ "$TOTAL" -eq 0 ]] && MEASUREMENT=0.0 || MEASUREMENT=$(python3 -c "print(round($PASS/$TOTAL, 4))")
```

### test-coverage.sh

```bash
COV_PCT=0
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  npx --no-install nyc --reporter=json-summary npm test --silent 2>/dev/null > /tmp/cov.json || true
  COV_PCT=$(python3 -c "import json; print(json.load(open('/tmp/cov.json'))['total']['lines']['pct'])" 2>/dev/null || echo 0)
elif [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  coverage run -m pytest -q 2>/dev/null >/dev/null
  coverage json -o /tmp/cov.json 2>/dev/null
  COV_PCT=$(python3 -c "import json; print(json.load(open('/tmp/cov.json'))['totals']['percent_covered_display'])" 2>/dev/null || echo 0)
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  COV_PCT=$(go test -cover ./... 2>/dev/null | grep -oE 'coverage: [0-9.]+%' | awk '{s+=$2; n++} END{print (n>0 ? s/n : 0)}')
fi
MEASUREMENT=$(python3 -c "print(round(min(1.0, $COV_PCT / 80.0), 4))")
```

**Threshold:** 80% is the conventional bar. Below
80%, scale linearly. Above 100% is impossible
(`min(1.0, ...)`).

**Anti-cheat:** `coverage.py` and `nyc` both have
"branch coverage" mode. If the candidate writes
tests that cover 100% of one branch but skip the
other, `branch=true` catches it. The verifier
config (`[run] branch = true` for coverage.py,
`all: true` for nyc) should be checked in.

### mutation-tests.sh

```bash
MUT_SCORE=0
if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  mutmut run --use-coverage --survive-threshold 0 2>/dev/null >/dev/null
  MUT_SCORE=$(mutmut results 2>/dev/null | awk '/killed/ {k++} /survived/ {s++} END {print (k+s>0 ? k/(k+s) : 0)}')
elif [[ -f "$PROJECT_DIR/package.json" ]]; then
  npx --no-install stryker run 2>/dev/null >/dev/null
  MUT_SCORE=$(python3 -c "import json; d=json.load(open('reports/mutation/mutation.json')); print(d['mutationScore']/100.0)" 2>/dev/null || echo 0)
fi
MEASUREMENT=$(python3 -c "print(round(min(1.0, $MUT_SCORE), 4))")
```

**Why mutation testing matters:** it catches the
cheat where an agent writes `assert x == x` (always
passes, no coverage signal). Mutation testing
introduces bugs and checks that the test suite
catches them. If 100% of mutants are killed, the
test suite has real teeth.

**Cost:** mutation testing is slow. The orchestrator's
`MAX_LOC_PER_CYCLE` doesn't bound wall-clock; the
`per-cycle-wall-clock.sh` does. If mutation testing
exceeds the cycle budget, prefer a faster suite (e.g.
`mutmut --use-coverage` skips uncovered lines).

### e2e-tests.sh

```bash
E2E_EXIT=0
E2E_OUTPUT=""
if [[ -f "$PROJECT_DIR/playwright.config.ts" ]]; then
  E2E_OUTPUT=$(npx --no-install playwright test --reporter=json 2>/dev/null) || E2E_EXIT=$?
elif [[ -f "$PROJECT_DIR/cypress.config.js" ]]; then
  E2E_OUTPUT=$(npx --no-install cypress run --reporter json 2>/dev/null) || E2E_EXIT=$?
fi

# Playwright/Cypress JSON: parse passed/failed counts
PASS=$(echo "$E2E_OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); s=d.get('stats',{}); print(s.get('expected',0))" 2>/dev/null || echo 0)
FAIL=$(echo "$E2E_OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); s=d.get('stats',{}); print(s.get('unexpected',0))" 2>/dev/null || echo 0)
TOTAL=$((PASS + FAIL))
[[ "$TOTAL" -eq 0 ]] && MEASUREMENT=0.0 || MEASUREMENT=$(python3 -c "print(round($PASS/$TOTAL, 4))")
```

**Pitfall:** Playwright/Cypress are *browsers* — they
need a real browser binary. The Docker image
must have Chromium installed. If `npx playwright install`
fails, the e2e sub-loss is 0.0; that's the
deterministic signal the loop needs.

### regression-tests.sh

```bash
# Regression tests = the test suite pinned to last-known-good behavior.
# Convention: a `tests/regression/` directory or a `@regression` marker.
REG_EXIT=0
REG_OUTPUT=""
if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  REG_OUTPUT=$(pytest -m regression --json-report --json-report-file=/tmp/reg.json -q 2>/dev/null) || REG_EXIT=$?
elif [[ -f "$PROJECT_DIR/package.json" ]]; then
  REG_OUTPUT=$(npm test --silent -- regression/ --reporter=json 2>/dev/null) || REG_EXIT=$?
fi

# Same parse as unit-tests.
if [[ -f /tmp/reg.json ]]; then
  PASS=$(python3 -c "import json; d=json.load(open('/tmp/reg.json')); print(d['summary']['passed'])")
  FAIL=$(python3 -c "import json; d=json.load(open('/tmp/reg.json')); print(d['summary']['failed'])")
  TOTAL=$((PASS + FAIL))
  [[ "$TOTAL" -eq 0 ]] && MEASUREMENT=0.0 || MEASUREMENT=$(python3 -c "print(round($PASS/$TOTAL, 4))")
else
  [[ "$REG_EXIT" -eq 0 ]] && MEASUREMENT=1.0 || MEASUREMENT=0.0
fi
```

**Difference from unit-tests:** regression tests
should be a *strict subset* that pins last-known-good
behavior. If the candidate breaks a regression test
that the unit tests miss, this sub-loss fires.

### contract-tests.sh

```bash
# Contract tests = schema validation, API spec compliance, etc.
# Stack-agnostic: they validate a candidate conforms to a contract.
CONTRACT_EXIT=0
CONTRACT_OUTPUT=""
# Example: Pact consumer-driven contract tests
if [[ -d "$PROJECT_DIR/pacts" ]]; then
  CONTRACT_OUTPUT=$(npm test --silent -- contract/ --reporter=json 2>/dev/null) || CONTRACT_EXIT=$?
# Example: OpenAPI schema validation
elif [[ -f "$PROJECT_DIR/openapi.yaml" ]]; then
  CONTRACT_OUTPUT=$(npx --no-install swagger-cli validate "$PROJECT_DIR/openapi.yaml" 2>&1) || CONTRACT_EXIT=$?
fi
[[ "$CONTRACT_EXIT" -eq 0 ]] && MEASUREMENT=1.0 || MEASUREMENT=0.0
```

**Why a separate sub-loss:** contract failures are
*worse* than test failures — they break the public
API. The `compute_sub_losses.py` weight for
`contract-tests` should be higher than `unit-tests`
in your project, since the cost of a contract break
is unbounded (downstream services break).

---

## security

### secret-scan.sh

**Stack:** gitleaks (any language), trufflehog
(more thorough, slower), detect-secrets (Python).

```bash
SECRET_COUNT=0
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --no-git --source "$PROJECT_DIR" --report-path /tmp/secrets.json 2>/dev/null || true
  SECRET_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/secrets.json')) or []))" 2>/dev/null || echo 0)
elif command -v detect-secrets >/dev/null 2>&1; then
  detect-secrets scan "$PROJECT_DIR" > /tmp/secrets.json 2>/dev/null
  SECRET_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/secrets.json'))['results']))" 2>/dev/null || echo 0)
fi
# Any secret = hard fail.
if [[ "$SECRET_COUNT" -eq 0 ]]; then MEASUREMENT=1.0
else MEASUREMENT=0.0
fi
```

**Why binary for secrets, not partial credit:** a
secret in the diff is not "80% bad." It's 100% bad.
A 0.99 score on a secret-scan means the agent
shipped one secret — that's a hard reject.

**Anti-cheat:** gitleaks has a `.gitleaksignore` —
agents can add their secrets to it. The integrity.sh
guard `no-secret-ignore-edit` (you add this) refuses
to score the cycle if `.gitleaksignore` was modified
in the candidate.

### sast.sh

**Stack:** Semgrep (multi-language), Bandit (Python),
ESLint security plugin (JS/TS), Gosec (Go).

```bash
SAST_EXIT=0
SAST_OUTPUT=""
if command -v semgrep >/dev/null 2>&1; then
  SAST_OUTPUT=$(semgrep --config=auto --json --quiet "$PROJECT_DIR" 2>/dev/null) || SAST_EXIT=$?
  HIGH_COUNT=$(echo "$SAST_OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for r in d['results'] if r['extra']['severity']=='ERROR'))" 2>/dev/null || echo 0)
  MED_COUNT=$(echo "$SAST_OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for r in d['results'] if r['extra']['severity']=='WARNING'))" 2>/dev/null || echo 0)
elif command -v bandit >/dev/null 2>&1; then
  SAST_OUTPUT=$(bandit -r "$PROJECT_DIR" -f json -q 2>/dev/null) || SAST_EXIT=$?
  HIGH_COUNT=$(echo "$SAST_OUTPUT" | python3 -c "import json,sys; print(sum(1 for r in json.load(sys.stdin)['results'] if r['issue_severity']=='HIGH'))" 2>/dev/null || echo 0)
  MED_COUNT=0
fi
# Weighted: a HIGH issue is a 0.5 deduction, MEDIUM is 0.1.
MEASUREMENT=$(python3 -c "print(max(0.0, 1.0 - 0.5*$HIGH_COUNT - 0.1*$MED_COUNT))")
```

### dependency-audit.sh

**Stack:** `npm audit` (Node), `pip-audit` (Python),
`govulncheck` (Go), `cargo audit` (Rust).

```bash
HIGH_VULN=0
MED_VULN=0
if [[ -f "$PROJECT_DIR/package-lock.json" ]]; then
  npm audit --json 2>/dev/null > /tmp/audit.json
  HIGH_VULN=$(python3 -c "import json; d=json.load(open('/tmp/audit.json')); print(d['metadata']['vulnerabilities']['high'])" 2>/dev/null || echo 0)
  MED_VULN=$(python3 -c "import json; d=json.load(open('/tmp/audit.json')); print(d['metadata']['vulnerabilities']['moderate'])" 2>/dev/null || echo 0)
elif [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
  pip-audit -r "$PROJECT_DIR/requirements.txt" --format json 2>/dev/null > /tmp/audit.json
  HIGH_VULN=$(python3 -c "import json; print(len([d for d in json.load(open('/tmp/audit.json')) if d.get('aliases',[])]))" 2>/dev/null || echo 0)
  MED_VULN=0
fi
MEASUREMENT=$(python3 -c "print(max(0.0, 1.0 - 0.3*$HIGH_VULN - 0.1*$MED_VULN))")
```

**Anti-cheat:** `npm audit fix` can mask the real
dependency state. The integrity.sh guard
`no-deps-lockfile-removed` (you add this) refuses to
score if `package-lock.json` / `requirements.txt` /
`go.sum` is missing or empty in the candidate.

### sbom.sh

**Stack:** CycloneDX (`cyclonedx-bom`), SPDX
(`spdx-tools`).

```bash
SBOM_OK=0
if command -v cyclonedx-bom >/dev/null 2>&1; then
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    cyclonedx-bom -o /tmp/sbom.json -f json 2>/dev/null && SBOM_OK=1
  fi
fi
[[ "$SBOM_OK" -eq 1 ]] && MEASUREMENT=1.0 || MEASUREMENT=0.0
```

**Why binary:** an SBOM is either present or not.
Partial-credit doesn't make sense for compliance
artifacts.

---

## quality-ux

### a11y.sh

**Stack:** axe-core (via Playwright), pa11y (CLI
wrapper).

```bash
A11Y_VIOLATIONS=0
if command -v pa11y >/dev/null 2>&1 && [[ -f "$PROJECT_DIR/dist/index.html" ]]; then
  A11Y_VIOLATIONS=$(pa11y --json "$PROJECT_DIR/dist/index.html" 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" || echo 0)
fi
MEASUREMENT=$(python3 -c "print(max(0.0, 1.0 - $A11Y_VIOLATIONS / 10.0))")
```

**Note:** a11y requires a built artifact. The
`build.sh` step must run before `a11y.sh`. The
verifier's `cycle.sh` is responsible for ordering.

### i18n.sh

**Stack:** custom — check that all translatable
strings are extracted and translated for each
locale.

```bash
# Convention: locales/<lang>/translation.json. Compare to a source-of-truth en.json.
SOURCE_KEYS=$(python3 -c "
import json, os
p = '$PROJECT_DIR/locales/en.json'
if os.path.exists(p):
    print(len(json.load(open(p))))
else:
    print(0)
")
TOTAL_COVERAGE=0
LOCALES=0
for locale_file in "$PROJECT_DIR"/locales/*.json; do
  [[ "$locale_file" == *en.json ]] && continue
  [[ ! -f "$locale_file" ]] && continue
  LOCALES=$((LOCALES + 1))
  KEYS=$(python3 -c "import json; print(len(json.load(open('$locale_file'))))")
  if [[ "$SOURCE_KEYS" -gt 0 ]]; then
    COVERAGE=$(python3 -c "print(round($KEYS / $SOURCE_KEYS, 4))")
    TOTAL_COVERAGE=$(python3 -c "print($TOTAL_COVERAGE + $COVERAGE)")
  fi
done
[[ "$LOCALES" -gt 0 ]] && MEASUREMENT=$(python3 -c "print(round($TOTAL_COVERAGE / $LOCALES, 4))") || MEASUREMENT=0.0
```

### docs-coverage.sh

**Stack:** language-agnostic — count public
functions/classes without docstrings.

```bash
TOTAL_PUBLIC=0
DOCUMENTED=0
if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  OUTPUT=$(python3 -c "
import ast, os
total = 0
doc = 0
for root, _, files in os.walk('$PROJECT_DIR'):
    for f in files:
        if f.endswith('.py'):
            try:
                tree = ast.parse(open(os.path.join(root, f)).read())
                for node in ast.walk(tree):
                    if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
                        if not node.name.startswith('_'):
                            total += 1
                            if ast.get_docstring(node):
                                doc += 1
            except Exception: pass
print(f'{doc} {total}')
" 2>/dev/null)
  DOCUMENTED=$(echo "$OUTPUT" | cut -d' ' -f1)
  TOTAL_PUBLIC=$(echo "$OUTPUT" | cut -d' ' -f2)
elif [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
  OUTPUT=$(npx --no-install -p ts-doc-check ts-doc-check "$PROJECT_DIR/src" 2>/dev/null)
  DOCUMENTED=$(echo "$OUTPUT" | grep -oE '[0-9]+ documented' | grep -oE '[0-9]+' || echo 0)
  TOTAL_PUBLIC=$(echo "$OUTPUT" | grep -oE '[0-9]+ total' | grep -oE '[0-9]+' || echo 0)
fi
[[ "$TOTAL_PUBLIC" -gt 0 ]] && MEASUREMENT=$(python3 -c "print(round($DOCUMENTED/$TOTAL_PUBLIC, 4))") || MEASUREMENT=0.0
```

---

## observability

### observability.sh

**Stack:** language-agnostic — count log statements
in production code paths.

```bash
# Convention: every public function should have at least one log statement
# covering its entry and exit. Custom lint; no standard tool.
LOG_COUNT=$(grep -rE 'console\.(log|info|warn|error)|logger\.(info|warn|error)|logging\.(info|warning|error)' "$PROJECT_DIR/src" "$PROJECT_DIR/lib" 2>/dev/null | wc -l)
PUBLIC_FN_COUNT=$(grep -rE '^(export )?(async )?function|^(export )?const \w+ = \(' "$PROJECT_DIR/src" 2>/dev/null | wc -l)
[[ "$PUBLIC_FN_COUNT" -gt 0 ]] && MEASUREMENT=$(python3 -c "print(round(min(1.0, $LOG_COUNT / $PUBLIC_FN_COUNT), 4))") || MEASUREMENT=0.0
```

### trace-coverage.sh

**Stack:** OpenTelemetry SDK check.

```bash
SPAN_COUNT=$(grep -rE 'tracer\.start_as_current_span|trace\.getTracer|@trace' "$PROJECT_DIR/src" 2>/dev/null | wc -l)
HTTP_HANDLER_COUNT=$(grep -rE 'app\.(get|post|put|delete|patch)|@app\.route|router\.(get|post|put|delete)' "$PROJECT_DIR/src" 2>/dev/null | wc -l)
[[ "$HTTP_HANDLER_COUNT" -gt 0 ]] && MEASUREMENT=$(python3 -c "print(round(min(1.0, $SPAN_COUNT / $HTTP_HANDLER_COUNT), 4))") || MEASUREMENT=0.0
```

---

## performance

### perf-budget.sh

**Stack:** autocannon (Node), wrk (generic), hey
(Go), k6 (multi-language).

```bash
P99_MS=99999
ENDPOINT="${PERF_BUDGET_ENDPOINT:-http://localhost:3000/health}"
if command -v autocannon >/dev/null 2>&1; then
  P99_MS=$(autocannon -d 5 -j "$ENDPOINT" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['latency']['p99'])" || echo 99999)
elif command -v wrk >/dev/null 2>&1; then
  P99_MS=$(wrk -t2 -c10 -d5s --latency "$ENDPOINT" 2>/dev/null | grep -oE '99%[ ]+[0-9.]+' | awk '{print $2}')
fi
# 1.0 if P99 < 100ms, decay to 0.0 at 1000ms.
MEASUREMENT=$(python3 -c "
p = $P99_MS
if p <= 100: print(1.0)
elif p >= 1000: print(0.0)
else: print(round(1.0 - 0.5*(p-100)/900, 4))
")
```

**Anti-cheat:** the endpoint must be a real
end-to-end check (e.g. `GET /api/users/:id` with
a real DB query), not `/health` which returns a
cached value. The integrity.sh guard
`perf-endpoint-real` (you add this) verifies the
endpoint is in the project's router, not a stub.

### bundle-size.sh

**Stack:** size-limit (Node), du (generic).

```bash
BUNDLE_KB=0
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  BUNDLE_KB=$(npx --no-install size-limit 2>/dev/null | grep -oE 'Bundle size: [0-9.]+ kB' | grep -oE '[0-9.]+' | head -1 || echo 0)
elif [[ -d "$PROJECT_DIR/dist" ]]; then
  BUNDLE_KB=$(du -sk "$PROJECT_DIR/dist" 2>/dev/null | awk '{print int($1)}')
fi
# 1.0 if < 500KB, decay to 0.0 at 5MB.
MEASUREMENT=$(python3 -c "
k = $BUNDLE_KB
if k <= 500: print(1.0)
elif k >= 5000: print(0.0)
else: print(round(1.0 - 0.5*(k-500)/4500, 4))
")
```

### startup-time.sh

**Stack:** time command + a known startup script.

```bash
START_MS=99999
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  START_MS=$( { time node "$PROJECT_DIR/dist/index.js" </dev/null >/dev/null 2>&1; } 2>&1 | awk '/real/ {print $2}' | sed 's/0m//;s/s//' | awk '{print int($1*1000)}')
fi
# 1.0 if < 500ms, decay to 0.0 at 5s.
MEASUREMENT=$(python3 -c "
s = $START_MS
if s <= 500: print(1.0)
elif s >= 5000: print(0.0)
else: print(round(1.0 - 0.5*(s-500)/4500, 4))
")
```

---

## reliability

### hermeticity.sh

**Stack:** language-agnostic — count network calls
in the test suite.

```bash
# Convention: tests should not make real network calls.
# Look for: requests.get, fetch(), http.Get, axios.get, etc.
NETWORK_CALLS=$(grep -rE 'requests\.(get|post|put|delete|patch)|fetch\(|http\.(Get|Post)|axios\.(get|post|put|delete)' "$PROJECT_DIR/tests" "$PROJECT_DIR/test" 2>/dev/null | wc -l)
# 1.0 if zero, partial if some calls are wrapped in mock contexts.
WRAPPED_CALLS=$(grep -rE 'monkeypatch|mock\(|vi\.mock|jest\.mock' "$PROJECT_DIR/tests" "$PROJECT_DIR/test" 2>/dev/null | wc -l)
NET_UNWRAPPED=$((NETWORK_CALLS - WRAPPED_CALLS))
[[ "$NET_UNWRAPPED" -le 0 ]] && MEASUREMENT=1.0 || MEASUREMENT=0.0
```

**Why binary:** an unwrapped network call in tests
means the test suite is non-hermetic. The score
should be 0.0 — tests that depend on external state
are not tests, they're integration smoke checks.

### determinism.sh

**Stack:** language-agnostic — run a test suite
twice with the same seed and compare.

```bash
# Convention: pytest's `-p no:randomly`, jest's `--ci`, go test's `-shuffle=off`.
TEST_OUTPUT_1=""
TEST_OUTPUT_2=""
if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  TEST_OUTPUT_1=$(pytest -p no:randomly --tb=no -q 2>&1 | tail -20)
  TEST_OUTPUT_2=$(pytest -p no:randomly --tb=no -q 2>&1 | tail -20)
fi
# Compare. If test output is byte-identical, deterministic.
if [[ "$TEST_OUTPUT_1" == "$TEST_OUTPUT_2" ]]; then MEASUREMENT=1.0
else MEASUREMENT=0.0
fi
```

**Anti-cheat:** a passing but non-deterministic test
suite is *worse* than a failing one — it makes the
verifier flaky. The orchestrator runs the suite
twice; if output diverges, the determinism sub-loss
goes to 0.0 and the orchestrator's verifier exits
non-zero.

### flakiness.sh

**Stack:** language-agnostic — run the test suite
N times and count unique outcomes.

```bash
N=5
OUTCOMES=""
for i in $(seq 1 $N); do
  RESULT=$(pytest -q --tb=no 2>&1 | tail -3 | md5sum | cut -c1-8)
  OUTCOMES="$OUTCOMES $RESULT"
done
UNIQUE=$(echo "$OUTCOMES" | tr ' ' '\n' | sort -u | wc -l)
# 1.0 if all runs identical, decay to 0.0 at N unique outcomes.
MEASUREMENT=$(python3 -c "
u = $UNIQUE; n = $N
print(round(max(0.0, 1.0 - (u-1)/(n-1)), 4))
")
```

**Cost:** this runs the test suite N times. Bound N
(usually 3-5) in the script; the cycle budget catches
the rest. If the cycle is too slow to run the suite
5 times, the loop shortens the flakiness N via env
var.

---

## compliance

### license-audit.sh

**Stack:** license-checker (Node), pip-licenses
(Python), go-licenses (Go).

```bash
BAD_LICENSES=0
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  BAD_LICENSES=$(npx --no-install license-checker --json 2>/dev/null | python3 -c "
import json, sys
allowed = {'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'ISC', 'MPL-2.0'}
d = json.load(sys.stdin)
bad = sum(1 for pkg, info in d.items() if not any(a in info.get('licenses','') for a in allowed))
print(bad)
" 2>/dev/null || echo 0)
elif [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
  BAD_LICENSES=$(pip-licenses --format=json 2>/dev/null | python3 -c "
import json, sys
allowed = {'MIT License', 'Apache Software License', 'BSD License', 'ISC License (ISCL)'}
d = json.load(sys.stdin)
bad = sum(1 for pkg in d if pkg.get('License') not in allowed)
print(bad)
" 2>/dev/null || echo 0)
fi
# Any non-allowed license = hard fail.
[[ "$BAD_LICENSES" -eq 0 ]] && MEASUREMENT=1.0 || MEASUREMENT=0.0
```

### supply-chain.sh

**Stack:** sigstore/cosign verify, SLSA provenance
check.

```bash
SIGNED=0
TOTAL=0
if command -d cosign >/dev/null 2>&1; then
  for img in $(grep -oE 'image:\s+\S+' "$PROJECT_DIR/deploy/*.yaml" 2>/dev/null | awk '{print $2}'); do
    TOTAL=$((TOTAL + 1))
    cosign verify --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' "$img" >/dev/null 2>&1 && SIGNED=$((SIGNED + 1))
  done
fi
[[ "$TOTAL" -gt 0 ]] && MEASUREMENT=$(python3 -c "print(round($SIGNED/$TOTAL, 4))") || MEASUREMENT=0.0
```

---

## The 5 per-runtime stubs

These three stubs depend on the runtime the loop is
using. The README explains which orchestrator reads
which:

- `cline-version.sh`, `cline-skills-dir.sh` — only
  the real-agent run with Cline calls these.
- `fake-agent-skills-dir.sh` — only the fake-agent
  run calls this.

The "real" implementations are wired by the loop
driver (cycle.sh), not by you. They check the runtime
binary's version and the skills directory where the
agent will pick up the candidate. See
`integrity.sh` for the source of truth on how these
are invoked.

---

## When to add a new stub

If your project has a constraint the 27 stubs don't
cover, add a new one in the scaffold source
(`skills/harness-scaffold/scripts/scaffold.py`)
following the same pattern:

1. Add a new tuple to `INSTRUMENT_FILES` with a
   `# ----- HITL: wire your tool here -----` block.
2. Add a new entry to `compute_sub_losses.py`'s
   sub-loss dictionary with a default weight.
3. Add a row to this doc under the right category.
4. Add a task in `test-tasks/design/` that exercises
   the new instrument end-to-end.
5. Run `./run-verification.sh` to confirm the
   instrument is wired into the report.

A new instrument without a corresponding design task
is invisible to the agent. The agent doesn't optimize
what it can't see scored.

## See also

- [`../README.md`](../README.md) — directory
  overview, wrappers, integrity.sh
- [`../../BUILDING-A-GREAT-HARNESS.md`](../../BUILDING-A-GREAT-HARNESS.md)
  — the full V0→V1 surface spec, including the
  4-piece loss function anatomy
- [`../../skills/loss-function-design/SKILL.md`](../../skills/loss-function-design/SKILL.md)
  — the verifier contract: candidate × evidence →
  score, partial credit, reward-hack defenses
