# test-tasks/

The tasks the loop runs the candidate against. Three
subdirectories, each with a different contract.

## Subdirectories

| Subdir | Visibility to the agent | Grader is on disk? | Run by |
|---|---|---|---|
| `design/` | Visible (the loop reads these) | Yes — `grade.sh` is a real grader | `run-design-set.sh` (every cycle) |
| `held-out/` | **Off-limits** (`chmod 700`, agent must not read) | Yes — `grade.sh` is a real grader | `verifiers/private/grader.sh` (at the end) |
| `method/` | Visible | Yes — `grade.sh` is a real grader | The method task (3 cycles, plateau detection) |

The `design/` and `held-out/` split is the standard LFD
training-vs-test split. The agent sees `design/` during
the loop (its training signal) and is graded against
`held-out/` at the end (its test). The `method/`
subdirectory is a third category — it exercises the loop's
*machinery* (improvement tracking, forced-entropy rule)
rather than a candidate's output.

## Per-task contract

Each task is a subdirectory with at least two files:

| File | Required? | Contract |
|---|---|---|
| `prompt.txt` | Yes | The prompt the agent sees. Plain text. |
| `grade.sh` | Yes | Executable. Exits 0 (pass) or 1 (fail). Prints `score=<float>` to stdout (e.g. `score=1.0` for pass, `score=0.0` for fail). May print other lines; only `score=...` lines are parsed. |
| `<starting-file>` | Optional | The buggy / blank / broken file the agent modifies. The agent reads this, fixes it, writes the result. |
| `README.md` | Optional | Free-form context for the grader. The harness does not read it. |
| `sample.ndjson` | Optional (d1 only) | Fixture data the grader uses (sample Cline NDJSON for the parser-shape test). |

The `grade.sh` is run from inside the task dir (`cd
test-tasks/design/dN-name && ./grade.sh`). It receives
the wrapper's `cycle-summary.json` path as `$1` (the
"iter dir" or "task run dir"). It inspects the wrapper's
output and returns 0 or 1.

**The grader is the truth.** A `grade.sh` that always
returns 0 is a stub-always-pass and the anti-cheat
firewall will flag it. A `grade.sh` that always returns 1
is a stub-always-fail and the design set will never pass.
Both cases are detected by `verifiers/integrity.sh` and
the `harness-completeness-checklist.md` Section 3.

## Negative checks (anti-cheat)

Every `grade.sh` should have at least one **negative
check** — an assertion that the agent did NOT do
something. Example:

```bash
# The agent should not call time.Sleep to mask timing
if grep -q "time.Sleep" "$ITER_DIR/cycle-summary.json" 2>/dev/null; then
  echo "FAIL: time.Sleep detected" >&2
  exit 1
fi
```

The harness-completeness-checklist Section 3 enforces
this. A grader with only positive checks (e.g. "does
the function return 42?") passes for an empty stub
function that returns 42 — that's not a real test.

## Design task categories

The 5 design tasks in this dogfood are intentionally
diverse (the loop's training signal):

| Task | Category | What it tests |
|---|---|---|
| `d1-parse-cline-output` | parser shape | Cline NDJSON → 8-shared-key JSON |
| `d2-verify-bundle-manifest` | manifest consistency | `bundle.json` shape, version, skills list |
| `d3-verify-install-script` | installer | `install.sh --check` against a fresh profile |
| `d4-compute-sub-losses` | scorer | 7-sub-loss output, gates, weighted sum |
| `d5-loop-driver-smoke` | loop driver | `cycle.sh` produces well-formed output (cycle-summary, design-set-score, iteration-log) |

For a production project, see
[`../../skills/meta-loss-function-development/SKILL.md`](../../skills/meta-loss-function-development/SKILL.md)
Round 2 for the 4-category task split (happy-path,
error/edge, cross-cutting, negative) and Round 3 for
the categorical-difference rule for held-out tasks.

## Held-out task categories

The 5 held-out tasks target harder properties:

| Task | What it tests |
|---|---|
| `h1-shared-parser-shape` | All 5 adapter parsers produce the same 8-key shape on identical input |
| `h2-install-determinism` | `install.sh` is deterministic: same input → same output |
| `h3-drift-opt-in` | The `drift` sub-loss correctly handles the `expected_model=""` opt-in |
| `h4-force-entropy-trigger` | The loop's force-entropy rule fires on consecutive stalls |
| `h5-compatibility-matrix-consistency` | The `compatibility.md` matrix is internally consistent |

## Adding new tasks

To add a design task:

1. Create `test-tasks/design/d6-<name>/`
2. Write `prompt.txt` (the task description)
3. Write `grade.sh` (returns 0/1, prints `score=<float>`,
   includes a negative check)
4. Re-run `./run-verification.sh` — the new task is
   auto-discovered by `run-design-set.sh`

To add a held-out task:

1. Create `test-tasks/held-out/h6-<name>/`
2. Write `prompt.txt` and `grade.sh`
3. `chmod 700 test-tasks/held-out/h6-<name>/` and
   `chmod 600` the files inside
4. The held-out grader auto-enumerates from the dir

To add a method task:

1. Create `test-tasks/method/<name>/`
2. Write `prompt.txt` (the orchestrator's per-cycle prompt
   template) and `grade.sh` (asserts the loop ran 3 cycles,
   that `iteration-log.md` has 3 entries, that the 3rd
   cycle's entry includes `FORCED_ENTROPY=true`)
3. Update `run-verification.sh` to invoke the new
   method task (currently hardcoded to
   `method-drives-improvement`)

The verifier is intentionally **auto-discovering**: it
picks up new tasks from the filesystem without code
changes to the orchestrator.

## See also

- [`../verifiers/README.md`](../verifiers/README.md) — the
  harness the loop runs against
- [`../../skills/meta-loss-function-development/references/harness-completeness-checklist.md`](../../skills/meta-loss-function-development/references/harness-completeness-checklist.md)
  — the gate these tasks must pass before the loop runs
