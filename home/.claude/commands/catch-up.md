---
description: Continue, propagate, and finish the in-progress edits I left in the working tree (wake follow mode)
argument-hint: "[path/glob to narrow scope] [--ask] [--no-verify]"
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

You are running **wake follow mode**. I have been editing this repo and left work
in progress. Your job is to **carry it to completion** — pick up every thread I
started and finish it the way I would have. Arguments: `$ARGUMENTS` (an optional
path/glob narrows scope; `--ask` makes you propose instead of apply; `--no-verify`
skips the build/test pass).

Default posture: **act, don't ask.** You are not editing alongside me — I have
stepped away and handed you the wheel. Everything you do is a git diff I will
review and can `git reset`, so a wrong guess is cheap and inaction is expensive.
Bias hard toward doing the work. Stopping to ask is the exception, used only when
you genuinely cannot tell *what* I intended (not merely how far to take it).

## 1. Resolve the drift

Run this to get the full patch of everything I changed since your last turn:

```sh
root=$(git rev-parse --show-toplevel)
key=$(printf %s "$root" | sha1sum | cut -c1-16)
state="$HOME/.claude/wake/$key"
base=$(cat "$state/base" 2>/dev/null)
GIT_INDEX_FILE="$state/index" git -C "$root" add -A
GIT_INDEX_FILE="$state/index" git -C "$root" diff --cached "$base"
```

This diff is the intent spec — it includes untracked files and respects
`.gitignore`. If a scope arg was given, start there but still follow the work
wherever it leads. If the diff is empty, say so and stop.

## 2. Cluster the diff into intent units

Group hunks into coherent threads. A diff usually holds several. Treat each as a
job to finish.

## 3. Classify and act on each cluster

| Class | Signal | Action — take it all the way |
|---|---|---|
| **propagate** | a transform applied to a *subset* of analogous sites (rename, signature change, restyle, API migration) | apply it to **every** analogous site in the repo, then fix every resulting caller, import, and reference until consistent |
| **complete** | a partially-filled set (some enum arms, cases, tests, fields) | fill in **all** the rest, plus the tests/docs/exhaustiveness the set implies |
| **implement** | stubs/markers: TODO/FIXME, `todo!()`, `pass`, `NotImplementedError`, empty body | write the real implementation, with its tests |
| **repair** | the edit left code inconsistent or broken (dangling refs, type holes) | finish it until the tree compiles and is coherent |
| **extend** | a new pattern, helper, or convention I introduced | apply it everywhere the old way still lingers |
| **done** | self-contained, coherent, nothing it implies is missing | no-op — but only after you've checked for implied follow-on work and found none |

`done` is a verdict you earn by looking, not a default you fall back to. Before
calling anything done, ask: does this change imply tests, docs, callers, sibling
cases, or a migration I haven't finished? If yes, do them.

## 4. How far to go

- **State the rule, then apply it fully.** Write the inferred transform as one
  crisp sentence, then carry it across the whole repo — there is no site cap.
  Chase references, callers, imports, exports, tests, and docs until nothing is
  left half-migrated.
- **Finish, don't sample.** Completing 8 of 20 sites and reporting the rest is a
  failure. Either the rule applies and you do all of them, or it doesn't and you
  do none.
- **Leave the tree consistent.** The end state should compile, type-check, and
  keep existing tests green. Update tests and docs that your changes invalidate.
- **TODOs in the working set.** Address TODO/FIXME markers in any file you touch
  this run, not only ones added in the diff. Skip unrelated backlog elsewhere.
- **Stop and ask only when intent is ambiguous** — two plausible transforms, or a
  destructive call you can't infer. Even then, prefer making the best-supported
  choice and flagging it over halting. `--ask` forces propose-first globally.

## 5. Sentinel overrides

Honor inline markers if present:
- `// wake: hold` / `# wake: hold` — deliberately partial; do not touch this region.
- `// wake: go` — pull this region into scope even if the diff signal is weak.

These are your only hard "stop" — absent a `hold`, assume I want the work finished.

## 6. Verify

Unless `--no-verify` was passed, run the project's build and test command after
editing and fix anything you broke. A `/catch-up` that leaves the build red is
not done.

## 7. Report

End with:
- **Intents detected** — one line per cluster with its class.
- **Action taken** — what you changed and how far you carried it (site counts,
  files touched, tests/docs updated).
- **Verify result** — build/test outcome.
- **Left alone** — only `hold` regions and anything you halted on for genuine
  ambiguity, with the question you need answered.

Do not re-mark the baseline yourself — the Stop hook does that when this turn
ends, so a second `/catch-up` sees only new drift.
