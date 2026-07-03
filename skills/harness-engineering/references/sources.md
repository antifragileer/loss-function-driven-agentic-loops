# Sources — Harness Engineering

This file is the index of external source material the
`harness-engineering` skill is built on. URLs in the SKILL.md
body rot; the index does not. Append new sources here, and
reference them from the SKILL.md by filename.

## Sources

### OpenAI — "Harness engineering: leveraging Codex in an agent-first world"

- **Author:** Ryan Lopopolo, Member of Technical Staff
- **Published:** 2026-02-11
- **URL:** https://openai.com/index/harness-engineering/
- **Why cited:** the "map not manual" rule, the layered-architecture
  invariant enforcement, the end-to-end autonomy milestone (agent
  records videos of bugs, fixes them, opens PRs), and the
  doc-gardening agent pattern for drift/garbage collection.
- **Key takeaways distilled in the SKILL.md:** the Core principles,
  the Repository-as-system-of-record layout, the
  "Enforce invariants, not implementations" rule, the Ralph Wiggum
  loop.

### @elvissun — turbo cache loop (X post)

- **Author:** Elvis Sun (@elvissun)
- **Posted:** 2026-04-10
- **URL:** https://x.com/elvissun/status/2042633997080224034
- **Why cited:** the worked example in "What 'good' looks like" —
  hypothesis → test → result across an isolated worktree, the
  3-column trace, the 6× speedup outcome.
- **Image:** the diagram is at `references/turbo-cache-loop-diagram.png`
  in this skill.

## Adding a new source

When you ingest a new article / X post / blog / spec into the
profile and the harness-engineering skill needs to cite it:

1. Add a new section under "## Sources" with author, date, URL,
   "why cited" (1-3 lines), and the path to any saved image.
2. If the source is a long-form article, save a verbatim or
   condensed copy in this directory (or a subdirectory) and link
   to it from the entry.
3. Reference the source from the SKILL.md body by filename, not
   by URL. URLs break; filenames don't.
