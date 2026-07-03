# Scaffold Bash Emission Pitfalls — Reference

`scripts/scaffold.py` builds a project tree by writing
**shell scripts that the user will execute later**. Three
classes of bugs that have shipped in the scaffold's emitted
bash and how to defend against them. If you are
modifying `scripts/scaffold.py` and adding new emitted
bash, **read this first**.

The pattern: the scaffold is one ~800-line Python file
that holds all its output templates as module-level
string constants. Each constant is concatenated with
`+ "line of bash\n"`. The bug surface is everything that
goes wrong when you compose a multi-line bash snippet
inside a Python string.

## Pitfall 1: empty `if/else/fi` clause is a syntax error

**Symptom:** the generated `run-design-set.sh` errors at
runtime with `syntax error near unexpected token \`fi'``.

**Cause:** bash requires the `else` branch to have at
least one statement. Empty else branches are a syntax
error.

**Bad** (emitted by an early version of the scaffold):

```python
# In scaffold.py:
+ "  if [[ -x \"$task_dir/grade.sh\" ]]; then\n"
+ "    if \"$task_dir/grade.sh\" ...; then\n"
+ "      n_pass=$((n_pass + 1)); grade_status=\"pass\"\n"
+ "    else\n"
+ "      grade_status=\"fail\"\n"
+ "    fi\n"
+ "  else\n"
+ "  fi\n"   # <-- empty else, syntax error
```

**Good:**

```python
+ "  else\n"
+ '    grade_status="missing"\n'   # at least one statement
+ "  fi\n"
```

**Defense:** if a generated shell script has an `if/else`
and the else branch legitimately does nothing, use `:` or
`true` as a no-op:

```python
+ "  else\n"
+ "    :\n"
+ "  fi\n"
```

**Test:** after any change to a shell template, run the
scaffold against a fresh directory, then `bash -n` on
each emitted `.sh` file:

```bash
for f in $(find /tmp/test-scaffold -name "*.sh"); do
  bash -n "$f" || echo "SYNTAX ERROR: $f"
done
```

## Pitfall 2: backslash-escaped quotes in Python string concat

**Symptom:** the generated bash parses correctly when
written to a file but produces `command not found` or
`unexpected EOF` at runtime.

**Cause:** when you put a bash double-quoted string
inside a Python single-quoted string, the backslash
escape `\"` is **preserved as `\"` in the output file**.
Bash then interprets the `\"` as a literal `"` (not a
quote escape), which closes the `"..."` early.

**Bad** (looks fine in Python, breaks in bash):

```python
+ '  tok=$(python3 -c "import json; print(int(json.load(open(\'"$task_run_dir/cycle-summary.json\')).get(\'tokens\',0) or 0))" 2>/dev/null || echo 0)\n'
```

This emits:

```bash
tok=$(python3 -c "import json; print(int(json.load(open('\"$task_run_dir/cycle-summary.json\"')).get('\"'\"'tokens'\"'\"',0) or 0))" 2>/dev/null || echo 0)
```

Bash sees the `\"` and closes the double-quoted string
after `open('`. Then `$task_run_dir` is unquoted and
gets word-split. Disaster.

**Good** (the bash single-quote / double-quote sandwich):

```python
+ '  tok=$(python3 -c "import json; print(int(json.load(open('"'"'"$task_run_dir/cycle-summary.json"'"'"' )).get('"'"'tokens'"'"',0) or 0))" 2>/dev/null || echo 0)\n'
```

`"'"'"'` is the bash idiom for embedding a literal `'`
inside a `"..."`-quoted argument. To bash, this is four
characters (`'`, `"`, `'`, `"`) that get stitched into a
single `'`. This is ugly but it's the right answer.

**Better alternative** (when the python snippet is
longer than 1 line): use a heredoc-style invocation
instead of `-c`:

```python
content = (
    "python3 - <<'PY'\n"
    "import json, sys\n"
    f"path = '{task_run_dir}/cycle-summary.json'\n"
    "d = json.load(open(path))\n"
    "print(d.get('tokens', 0))\n"
    "PY\n"
)
```

The heredoc approach is more readable and immune to
quoting bugs.

**Test:** after any change to a shell template that
contains `python3 -c "..."`, **actually run the emitted
script** end-to-end (don't just `bash -n` it). The
syntax is fine; the bug is at runtime when the python
process gets the wrong argv.

## Pitfall 3: emitted bash must be POSIX-portable

**Symptom:** the emitted scripts work on Linux but fail
on macOS with `grep: invalid option -- P` or
`sed: 1: ...: unexpected regex` or similar.

**Cause:** the emitted bash uses GNU-isms that BSD
userland on macOS doesn't implement:
- `grep -P` (PCRE)
- `sed \w` or `sed \{1,\}` (GNU extensions)
- `[[ ... =~ ... ]]` with PCRE patterns

**Defense:** the emitted scripts must use only POSIX ERE
patterns (`[a-zA-Z0-9_]`, `*`, `+`, `?`) and standard
bash 3.2 syntax. See `loop-driver/references/posix-shell-portability.md`
for the full list.

**Test:** scaffold the project on macOS. `bash -n` every
emitted file. Then `bash <file>` and verify it actually
runs.

## The verification recipe (use this after every change)

After modifying any string constant in `scaffold.py`:

```bash
# 1. Scaffold a fresh project
rm -rf /tmp/test-scaffold
mkdir -p /tmp/test-scaffold
cp /path/to/slack-clone-golang-prompt.txt /tmp/test-scaffold/GOAL.md
python3 /path/to/scaffold.py \
    --project-root /tmp/test-scaffold \
    --goal-prompt /tmp/test-scaffold/GOAL.md > /dev/null

# 2. bash -n every emitted shell script
for f in $(find /tmp/test-scaffold -name "*.sh" -type f); do
  if ! bash -n "$f" 2>/tmp/err; then
    echo "SYNTAX ERROR in $f:"
    cat /tmp/err
  fi
done

# 3. python3 -c "import ast; ast.parse(...)" every emitted python file
for f in $(find /tmp/test-scaffold -name "*.py" -type f); do
  if ! python3 -c "import ast; ast.parse(open('$f').read())" 2>/tmp/err; then
    echo "PYTHON SYNTAX ERROR in $f:"
    cat /tmp/err
  fi
done

# 4. Run the design-set against a fake cline (full end-to-end)
#    See loop-driver/references/integration-test-recipe.md
```

Steps 1-3 catch static issues. Step 4 catches runtime
quoting bugs that `bash -n` can't see.

## Why the inlined-templates design makes this worse

`scaffold.py` keeps all templates as module-level Python
string constants and concatenates them at runtime. This
design has one big upside (single-file distribution, no
Jinja) and one big downside (every line of bash has to
be valid as a Python string AND as a bash string, with
correct escaping at the boundary).

The defense is the verification recipe above. There is
no way to catch all quoting issues by inspection.

If you want to add a complex emitted script (a 50+ line
verifier, for example), consider:

- Putting the script in `templates/<name>.sh` as a real
  file, read it at scaffold time with `Path.read_text()`,
  and use `string.Template` substitution for the few
  variables that need to vary.
- This decouples the bash from the Python string-quoting
  rules entirely. The `templates/README.md` explains why
  templates are currently inlined and what the trade-off
  is.

## What the scaffold does to defend against these

`scripts/scaffold.py` was patched in the same session
that added this reference. All three pitfall classes
above are fixed in the current scaffold:

- All `if/else/fi` branches have at least one statement.
- The `python3 -c "..."` invocations in `run-design-set.sh`
  use the `'"'"'` sandwich pattern.
- All emitted bash is POSIX-portable (no GNU-isms).

The verification recipe is what guards against
regressions. Run it after every change to a shell
template.
