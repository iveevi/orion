---
name: prose-forge
description: Generate research-paper-grade technical / academic / pedagogical prose via the prose-forge-academic multi-agent workflow. Use when the user asks for a methods paragraph, related-work paragraph, tutorial section, explanatory passage, review writeup, or any prose that needs to read like a working researcher wrote it. Accepts a brief plus optional genre, audience, length, iterations, drafters, and criticModel. Writes a markdown deliverable to /tmp/ for inspection.
---

# Prose Forge — invoke the academic prose pipeline

This skill wraps the multi-agent workflow at `~/.claude/workflows/prose-forge-academic.js` (Spec → N parallel drafts in distinct academic voices → adversarial critic panel + reviser, looped → polish → judge). It produces LaTeX-aware research prose and saves a markdown render to `/tmp/`.

## Always invoke via scriptPath, not name

The `name:`-resolved workflow registry caches a stale snapshot from session start. Edits to the workflow file are NOT picked up by `Workflow({name: "prose-forge-academic"})`. **Always invoke with `scriptPath: "/home/vedavamadath/.claude/skills/prose-forge/workflow.js"`** so the live file runs.

## What the user gives you

The user's `/prose-forge` invocation is normally a brief — a sentence or paragraph describing what to write. Examples:
- `/prose-forge write a related-work paragraph comparing sparse attention to Reformer and Linformer`
- `/prose-forge explain why batch normalization helps optimization`
- `/prose-forge methods section: we used a 12-layer transformer trained on C4 for 100k steps`

The brief is whatever the user said after the slash command. Pass it verbatim as `args.brief`. Do not paraphrase or restate.

If the user provided any of the following inline, parse them out and pass them too:
- length / word count → `args.length` (integer)
- audience / reader → `args.audience` (string)
- genre → `args.genre` (one of: `methods` / `related-work` / `tutorial` / `review` / `results` / `discussion` / `pedagogical` / `introduction`)
- iterations → `args.iterations` (integer)
- drafters → `args.drafters` (1–5)
- model for critics → `args.criticModel` (e.g. `"claude-sonnet-4-6"`)

If the user did NOT specify these, infer sensible defaults from the brief itself rather than asking. The workflow has reasonable fallbacks (genre: pedagogical, length: 400, iterations: 3, drafters: 3, critics: inherit session model). For most invocations the cost-conscious defaults below are better.

## Defaults you should pick when the user is silent

| Param | Default to use | Why |
|---|---|---|
| `genre` | infer from brief language ("related-work paragraph" → `related-work`; "explain" → `pedagogical`; "we trained" → `methods`) | better drafter framing |
| `audience` | infer from the brief's vocabulary level; if unclear, "an ML/CS researcher with the standard prerequisites for the topic, but new to this specific work" | calibrates jargon |
| `length` | 300 words for paragraphs, 500 for sections, 800 for tutorial passages | tighter is almost always better |
| `iterations` | 2 | 3 rarely buys quality over 2 and costs 50% more |
| `drafters` | 2 | 3 is only worth it for very high-stakes prose |
| `criticModel` | `"claude-sonnet-4-6"` | critics flag, not create; Sonnet is sufficient and cuts cost ~40% |

These defaults cost ≈$3–5 per run. Full-Opus defaults (iterations=3, drafters=3, all-Opus) cost ≈$10–13.

If the brief is clearly high-stakes (the user said "for my paper submission", "polish this for camera-ready", or names a top venue), bump iterations to 3 and consider keeping critics on the inherited Opus model. Tell the user the cost trade.

## Invocation

```
Workflow({
  scriptPath: "/home/vedavamadath/.claude/skills/prose-forge/workflow.js",
  args: {
    brief: "<user's brief verbatim>",
    genre: "<inferred or specified>",
    audience: "<inferred or specified>",
    length: <integer>,
    iterations: 2,
    drafters: 2,
    criticModel: "claude-sonnet-4-6"
  }
})
```

The Workflow tool returns immediately with a task ID and a notification arrives when the run completes (usually 2–5 minutes). Do NOT poll. Continue with other work or, if there is no other work, just wait — the notification will trigger your continuation.

## After completion

When the task notification arrives:

1. Read the output file the notification names. The `result` object has fields:
   - `prose` — the winning draft (text)
   - `winning_register` — voice name (feynman / knuth / olah / neurips / pinker)
   - `reasoning` — judge's paragraph
   - `spec` — extracted structure
   - `alternates` — all polished drafts
   - `ranking` — indices best→worst
   - `output_tokens` — output token count
   - `markdown` — a complete markdown document ready to write to disk

2. Save the markdown to `/tmp/prose-forge-<task-id>.md`:
   ```sh
   jq -r '.result.markdown' <output-file-path> > /tmp/prose-forge-<task-id>.md
   ```

3. Compute and report cost. Total tokens come from the task usage envelope (`subagent_tokens`); output tokens come from `result.output_tokens`; input = total − output. At Opus 4.8 ($5 input / $25 output per MTok) for non-critic agents and Sonnet 4.6 ($3 / $15) for critics, a typical run with the recommended defaults lands at $3–5.

4. Report to the user:
   - The path to the markdown file in `/tmp/`
   - The winning register (one line)
   - The total cost estimate
   - The first paragraph of the winning prose inline (so they can decide whether to open the file)

Do not paste the entire prose unless it's short (< ~300 words) — point them to the markdown file.

## When NOT to use this skill

- The user wants a single sentence rewritten. Just rewrite it.
- The user wants help editing existing prose they wrote. This skill generates from scratch; for editing, work line-by-line.
- The user wants prose in a non-academic register (marketing copy, blog post, fiction). The drafters' voice references are all academic. Decline and explain.
- The brief is one or two words ("explain transformers"). Ask for more context — what aspect, for whom, what length — before invoking. A vague brief produces vague output and wastes ~$5.
