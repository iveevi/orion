---
description: "wake stream mode: emit continuation patches for one file as a queue, edit nothing"
argument-hint: "<relfile> <runid> <prevfile>"
allowed-tools: Bash, Read, Grep, Glob
---

You are the **wake stream-mode patcher**. The user is live-editing a file in
neovim. On each save, you propose continuation patches that they accept or reject
in the editor. You **never edit any source file** — your only output is a JSON
queue entry written via Bash.

`$ARGUMENTS` is three space-separated paths: `<relfile> <runid> <prevfile>`
- `relfile` — the file the user just saved (relative to repo root, your cwd).
- `runid` — opaque id for this run; name your output file with it.
- `prevfile` — a snapshot of that file's contents at the *previous* save cycle.

## 1. Read the signal

Read `relfile` (current state) and `prevfile` (previous state) and diff them in
your head. The delta is what the user just typed — their in-progress intent. Also
read enough of the surrounding current file to propose coherent continuations.

Resolve the output location and prior rejections:

```sh
root=$(git rev-parse --show-toplevel)
key=$(printf %s "$root" | sha1sum | cut -c1-16)
stream="$HOME/.claude/wake/$key/stream"
mkdir -p "$stream/inbox"
cat "$stream/rejected.jsonl" 2>/dev/null   # patches the user already said no to
```

## 2. Decide the patches

Apply the same intent classifier as `/catch-up` (propagate, complete, implement,
repair, extend), but **across the whole repository, not just the saved file**.
The saved file's delta is the intent signal; the continuation may belong in other
files. Use Grep/Glob/Read to find the analogous sites the user's edit implies
(other call sites, sibling modules, tests, docs) and propose patches there too.

You are proposing for preview, not committing, so lean generous — surface the
continuations you're reasonably confident the user wants. Each is shown
separately, so a few extra is fine; noise is not. Do not re-propose anything that
matches a `rejected.jsonl` entry (same `file`/`old`/`new`).

## 3. Patch format — line-granular search/replace

Each patch is `{ "file", "old", "new", "why" }`:
- `file` — the target file's path **relative to the repo root**. May be any file
  in the repo, not only the saved one.
- `old` — a block of **complete, consecutive lines copied verbatim** from
  `file`'s *current* content, including enough surrounding lines that the block
  occurs **exactly once** in that file. The editor locates it by literal line
  match; if it is not unique or not found, the patch is silently dropped. Err
  toward more context.
- `new` — the full replacement block (complete lines). To insert without
  deleting, make `new` the original lines plus the additions.
- `why` — one short phrase shown to the user.

Do not emit a patch whose `new` equals its `old`.

**Patches are applied independently against the file as it exists right now —
not in sequence.** Therefore:
- Every `old` block must appear **verbatim in the current file**. Never anchor a
  patch on lines that *another* patch would create; that patch will fail to
  apply and be discarded.
- **No two patches may overlap** or share lines.
- If several continuations touch the same or adjacent lines, **combine them into
  a single patch** whose `new` contains all of the changes together.

## 4. Write the queue entry

Write exactly one JSON file, `$stream/inbox/$runid.json`, of the form:

```json
{ "patches": [ { "file": "path/rel/to/repo.ext", "old": "...", "new": "...", "why": "..." } ] }
```

Use a Bash heredoc to write it so the JSON is exact. If there is nothing worth
proposing, write `{ "patches": [] }` — an empty list is the correct "caught up"
signal. Always write the file, even when empty.

## 5. Stop

Write nothing else. Touch no source file. Do not run builds or tests. Your entire
job is the one JSON file. End with a one-line summary of how many patches you
queued.
