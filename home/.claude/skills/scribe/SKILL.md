---
name: scribe
description: Write research-paper-grade technical, academic, and pedagogical prose and reports, grounded in real citations. Use when the user asks for a methods paragraph, related-work section, report, tutorial passage, explanatory writeup, or any prose that must read like a working researcher wrote it AND rest on real references. Auto-discovers and cites relevant papers via the paper skill, then runs a hybrid drafters->critic->judge pipeline. Delivers the result in whatever form fits the discussion — reported inline, written to a file, or merged into an existing document (LaTeX, Markdown, etc.).
---

# Scribe — grounded academic prose

Two stages, run in this order:

1. **You (main loop) gather references inline** using the `paper` skill's Discover flow.
2. **You invoke the `scribe` workflow** at `~/.claude/skills/scribe/workflow.js`, passing those references. The workflow drafts in 2 academic voices, runs one adversarial critic+revise round, polishes, and judges. Drafters cite ONLY the references you supply.

This division matters: reference gathering needs the `paper` skill and the live web, which only the main loop has. The workflow is sandboxed and cannot fetch — it can only cite what you hand it.

## Stage 1 — gather references (auto-discover + cite)

Unless the user explicitly says "don't pull anything new" or "only use what I have", default to discovery. Run the `paper` skill's **Discover** flow on the brief's topic:

1. `WebSearch` the topic to identify the canonical + directly on-point papers.
2. Pick the top ~3 (up to 5 if broad). For each not already in `~/papers`, run `uv run ~/.claude/skills/paper/add.py add "<id-or-url>"`. Dedup is automatic.
3. Fill tags (`set --tags`) and write a digest for each (`digest <id>`), per the paper skill's rules.
4. Read each paper's digest (`~/papers/.store/<id>.md`) and grab its citekey from `~/papers/.store/references.bib` (or the `add.py` JSON output).

If the brief is purely pedagogical with no empirical claims to cite ("explain why softmax gradients are stable"), discovery is optional — a short reference set or none is fine. Use judgment: prose that makes claims about prior work or results MUST be grounded; prose that derives something from first principles need not be.

Build a compact `references` array from what you gathered. One entry per paper:

```json
{
  "citekey": "vaswani2017attention",
  "title": "Attention Is All You Need",
  "authors": "Vaswani et al.",
  "year": 2017,
  "claims": "1-3 sentence summary of the specific findings/claims from this paper that are relevant to THIS brief — pulled from the digest, not the whole abstract."
}
```

The `claims` field is what the drafters actually read to decide where to cite. Make it specific to the brief, not a generic summary.

## Stage 2 — invoke the workflow

Always invoke via `scriptPath` (the `name:` registry caches a stale snapshot from session start):

```
Workflow({
  scriptPath: "/home/vedavamadath/.claude/skills/scribe/workflow.js",
  args: {
    brief: "<user's brief verbatim>",
    genre: "<inferred or specified>",
    audience: "<inferred or specified>",
    length: <integer>,
    drafters: 2,
    iterations: 1,
    criticModel: "claude-sonnet-4-6",
    references: [ /* the array from Stage 1; [] if none */ ]
  }
})
```

Pass the brief **verbatim** as `args.brief`. Parse out any inline params the user gave; otherwise pick defaults below.

| Param | Default | Notes |
|---|---|---|
| `genre` | infer from brief ("related-work" → `related-work`; "explain" → `pedagogical`; "we trained" → `methods`; "write up the results of" → `report`) | one of: methods, related-work, tutorial, review, results, discussion, report, pedagogical, introduction |
| `audience` | infer from vocabulary; fallback "an ML/CS researcher with standard prerequisites but new to this specific work" | calibrates jargon |
| `length` | 300 (paragraph), 500 (section), 800 (tutorial/report) | tighter is better |
| `drafters` | 2 | 1 for a quick draft; 3 for high-stakes |
| `iterations` | 1 | one critic+revise round; bump to 2 only for camera-ready |
| `criticModel` | `"claude-sonnet-4-6"` | critics flag, not create |

Hybrid defaults cost roughly $1–2 per run. For "this is for my paper submission" / camera-ready / a named top venue, bump `drafters` to 3 and `iterations` to 2 and tell the user the cost goes to ~$3–5.

The Workflow tool returns immediately with a task ID; a notification arrives on completion (usually 1–3 min). Do NOT poll — continue other work or wait for the notification.

## After completion

When the notification arrives, the `result` object has: `prose` (winning draft), `winning_register`, `reasoning`, `spec`, `references`, `alternates`, `ranking`, `output_tokens`, `markdown`. Read it with `jq` from the output file the notification names — never paste the whole JSON.

**Choose the destination from the discussion. There is no default file path.** Decide where the prose belongs based on what the user is doing, in roughly this order of preference:

1. **Into the work in progress** — if the conversation is about a specific document (a LaTeX paper, a README, a report draft, a notebook), put the prose where it goes: `Edit`/`Write` it into that file, in that file's format. For a LaTeX paper, convert `[@citekey]` to `\cite{citekey}`, inline/display math is already LaTeX, and make sure the cited keys exist in the paper's `.bib` (append from `~/papers/.store/references.bib` if missing). For a Markdown/Pandoc doc, `[@citekey]` is already correct.
2. **A new file** — if the user asked for "a document"/"a file" but named no target, write one to the current working directory (or a path they gave) with a sensible name and extension: `.md` for Markdown, `.tex` for a standalone LaTeX document (wrap with a minimal preamble + `\bibliography` only if they want a compilable paper).
3. **Inline** — if it is short, a single paragraph, or clearly meant to be read in-conversation, just report the prose directly. No file.

If it is genuinely ambiguous which of these fits, ask — one short question beats guessing wrong. `result.markdown` is a ready-made full render (prose + reasoning + spec + alternates) for when a self-contained file is wanted; `result.prose` is just the passage for when you are inserting into something.

Then report:
- Where the prose landed (file path + format, or "inline below")
- Winning register (one line)
- Which references were cited (citekeys), and that they resolve against `~/papers/.store/references.bib`
- Cost estimate (input = total subagent_tokens − `result.output_tokens`; Opus 4.8 at $5/$25 per MTok, Sonnet 4.6 critics at $3/$15)

If you wrote to a file, show the first paragraph inline so the user can judge without opening it; don't paste the whole passage unless it is short (< ~300 words).

## When NOT to use this skill

- A single sentence to rewrite — just rewrite it.
- Editing the user's existing prose — this generates from scratch; edit line-by-line instead.
- Non-academic register (marketing, blog, fiction) — the voices are all academic. Decline and explain.
- A one- or two-word brief ("explain transformers") — ask what aspect, for whom, what length before invoking. A vague brief wastes the run.
