# POSIX Shell Portability — Reference

`scripts/cycle.sh` and `scripts/run-loop.sh` use bash, but
they emit shell snippets (in `prompt.txt`, the STOP-event
line, the iteration log format) that the user (or other
scripts) may parse with whatever shell is on the host. Three
classes of GNU-isms that **silently break on macOS / BSD
userland** and how to fix them.

If you are debugging "the script exits with strange
errors on macOS" or "the iteration log shows partial
lines", it's almost always one of these.

## Issue 1: `grep -P` (PCRE) is not in BSD grep

**Symptom:** `grep: invalid option -- P` on stderr; the
command exits 1; if the script is `set -e`, it dies
silently afterward.

**Cause:** macOS's BSD `grep` does not implement PCRE. The
`-P` flag is GNU-only.

**Bad** (worked on Linux, fails on macOS):

```bash
LAST_CYCLE=$(grep -oP 'cycle \K\d+' "$LOG_FILE" | tail -1)
```

**Good** (POSIX `sed`):

```bash
LAST_CYCLE=$(sed -n 's/.*cycle \([0-9]*\).*/\1/p' "$LOG_FILE" | tail -1)
```

The `\K` lookbehind in PCRE has no direct POSIX equivalent.
A capturing group + backreference is the portable form.

## Issue 2: `sed \w` and `\{1,\}` are GNU extensions

**Symptom:** `sed` silently produces no output (the regex
doesn't match); the surrounding script logic sees an empty
capture group; arithmetic comparisons fail downstream.

**Cause:** BSD `sed` (which is the only `sed` on macOS)
accepts POSIX BRE and a subset of ERE. `\w` (word-char
class) and `\{1,\}` (interval expressions) are GNU
extensions that some BSD `sed` builds recognize, but you
shouldn't rely on it.

**Bad** (works on GNU sed, fails on BSD):

```bash
FORCED=$(echo "$line" | sed -n 's/.*FORCED_ENTROPY=\(\w\{1,\}\).*/\1/p')
COUNT=$(echo "$line" | sed -n 's/.*pass_rate=\([0-9.]\{1,\}\).*/\1/p')
```

**Good** (POSIX ERE — works on both):

```bash
FORCED=$(echo "$line" | sed -n 's/.*FORCED_ENTROPY=\([a-zA-Z0-9_]*\).*/\1/p')
COUNT=$(echo "$line" | sed -n 's/.*pass_rate=\([0-9.]*\).*/\1/p')
```

`[a-zA-Z0-9_]` replaces `\w`. `*` (zero-or-more) replaces
`\{1,\}` (one-or-more) — in this context both produce
the same result because the regex is anchored by the
`FORCED_ENTROPY=` and `pass_rate=` literal prefixes; if
those prefixes are present, there's always at least one
character to capture.

## Issue 3: `set -e` + assignment failure modes (cross-ref)

See `references/set-euo-pipefail-pitfalls.md` for the
three "silent exit" failure modes. POSIX portability and
`set -euo pipefail` are different problems but they
overlap in scripts that mix both.

## Issue 4: empty `if/else/fi` clauses

**Symptom:** the **generated** bash in the harness (e.g.,
`run-design-set.sh` from `harness-scaffold`) errors at
runtime with `syntax error near unexpected token \`fi'``.

**Cause:** when the scaffold's `scaffold.py` emits a
snippet like:

```bash
if [[ -x "$task_dir/grade.sh" ]]; then
  if "$task_dir/grade.sh" ...; then
    n_pass=$((n_pass + 1))
  else
    grade_status="fail"
  fi
else
fi   # <-- empty else, bash syntax error
```

Bash requires the `else` branch to have at least one
statement. An empty `else` is a syntax error.

**Fix:** put a no-op or default assignment in the empty
branch:

```bash
else
  grade_status="missing"
fi
```

`harness-scaffold/scripts/scaffold.py` had this bug in
the `RUN_DESIGN_SET_SH` template. The fix landed in the
same session this reference was added.

## Issue 5: backslash-escaped quotes inside concatenated bash

**Symptom:** the generated bash parses correctly when
written to a file but produces a `command not found`
or `unexpected EOF` error at runtime.

**Cause:** when `scaffold.py` builds a bash snippet via
Python string concatenation, a line like:

```python
+ '  tok=$(python3 -c "import json; print(int(json.load(open(\'"$task_run_dir/cycle-summary.json"\')).get(\'tokens\',0) or 0))" 2>/dev/null || echo 0)\n'
```

emits a file containing:

```bash
tok=$(python3 -c "import json; print(int(json.load(open('\"$task_run_dir/cycle-summary.json\"')).get('\"'\"'tokens'\"'\"',0) or 0))" 2>/dev/null || echo 0)
```

The `\"` inside the bash double-quoted string is
**interpreted as a literal `"` by bash** (not a quote
escape) — which closes the `"..."` early, then tries to
parse `$task_run_dir/cycle-summary.json` as a command, and
explodes.

**Fix:** don't put bash double-quote escapes inside a
Python single-quoted string. Use the single-quote / double-
quote sandwich pattern that bash actually expects:

```python
+ '  tok=$(python3 -c "import json; print(int(json.load(open('"'"'"$task_run_dir/cycle-summary.json"'"'"' )).get('"'"'tokens'"'"',0) or 0))" 2>/dev/null || echo 0)\n'
```

`"'"'"'` is the bash idiom for embedding a literal `'` in
a `"..."`-quoted argument. The result, when written to a
file, is:

```bash
tok=$(python3 -c "import json; print(int(json.load(open('\"$task_run_dir/cycle-summary.json\"' )).get('\"'\"'tokens'\"'\"',0) or 0))" 2>/dev/null || echo 0)
```

…which bash parses correctly because the `'"'"'` is
**four characters** to bash: `'`, `"`, `'`, `"` — bash
stitches them into a single `'` inside the surrounding
`"..."`.

This is ugly. The cleanest way to write a `python3 -c "..."`
invocation from inside Python is to put the Python script
in a heredoc-style argument or call Python with
`python3 - <<'PY' ... PY`. The scaffold avoids that for
compactness, so the sandwich pattern is the workaround.

## Audit recipe

When you change `cycle.sh` or `run-loop.sh`, run this on
macOS and Linux before committing:

```bash
# On macOS:
bash -n scripts/cycle.sh && bash -n scripts/run-loop.sh

# On Linux (if available):
shellcheck scripts/cycle.sh scripts/run-loop.sh

# On either, search for GNU-isms:
grep -nE 'grep -[a-z]*P|sed .*\\\\\w|sed .*\\\\{1,\\}|grep -oP' scripts/*.sh
# should return nothing
```

`shellcheck` (Linux/brew) is the gold standard — it flags
GNU-isms, `set -e` failure modes, and unquoted expansions
in one pass. If you can install it, do.

## The "no GNU-isms" rule for new code in this skill

Any new shell snippet in `cycle.sh`, `run-loop.sh`, or
emitted via Python into the harness must be **POSIX sh +
bash 3.2** compatible. Specifically:

- No `grep -P`, `grep -oP`, `grep -P` (use `sed -n` + capture
  groups)
- No `\w`, `\{1,\}` in `sed` patterns (use `[a-zA-Z0-9_]`,
  `*`)
- No `[[ ... =~ ... ]]` with PCRE (use BRE/ERE patterns or
  `case` statements)
- No `local` outside functions (bashism; use `local` only
  in functions)
- No `$(< file)` (process substitution; use `$(cat file)`)
- No `mapfile` / `readarray` (bash 4+ only; use a `while
  read` loop)

If a test on macOS passes, it'll pass on Linux. The
reverse is not true.

## What `cycle.sh` does to defend against this

`cycle.sh` was audited and patched in the session that
added this reference. All grep -P usages were replaced
with sed; all sed GNU-isms were replaced with POSIX. The
script was verified to run end-to-end on macOS with a
fake `cline` binary and produce the expected output
(pass_rate=0.2, weighted_sum=0.5116, STOP on stall).
