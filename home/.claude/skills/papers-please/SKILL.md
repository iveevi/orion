---
name: papers-please
description: Collect, catalog, and recall academic papers. Use when the user wants to add a paper (arXiv ID/URL, DOI, PDF URL, or local PDF) to their ~/papers collection, or asks a question about papers they've already collected ("what does X say about Y", "do I have anything on Z", "cite that paper"). Pulls valid PDFs into ~/papers, maintains INDEX.md + references.bib, and answers from per-paper digests rather than raw PDFs.
---

The collection lives in `~/papers/`. The visible folder holds **only the PDFs** — everything else (truth + generated views + per-paper artifacts) lives under the hidden `~/papers/.store/`: `index.json` (truth), `INDEX.md` and `references.bib` (generated views), and `<id>.{txt,md,bib}` per paper. Never hand-edit the views. All mutations go through the script:

```
uv run ~/.claude/skills/papers-please/add.py <subcommand>
```

Subcommands: `add <input>`, `search <query> [-n N] [--sort submittedDate|relevance|lastUpdatedDate]`, `set <id> [--title|--tags|--authors|--year|--doi]`, `digest <id>` (reads markdown from stdin), `render`, `backfill`.

The script is deterministic and cannot call a model. Anything requiring judgment (recovering a title, writing tags, writing a digest) is YOUR job — produce it, then persist it via `set`/`digest`.

## Route by intent

The core purpose: when invoked in a discussion, this skill **autonomously brings real paper content into the conversation**. It fetches the relevant papers, reads and digests them, and returns with grounded, cited context — so the discussion continues from an informed position. Fetching and digesting are **automatic**; do not ask the user for permission to pull or to read. The catalog (`~/papers`, INDEX.md, references.bib) is the persistence layer that falls out of doing this — not the goal.

First decide: is the user pointing at a **collection they already have**, or raising a **topic/question to inform the discussion**? "What do I have / what does my paper X say" is Query. A topic, concept, or question to ground the discussion in is Discover.

**Discover** (the default for a topic — fetch, read, and report back informed; no confirmation step):
1. Use the **WebSearch tool** to identify the most relevant papers for the topic — the canonical work plus anything directly on-point. Web ranking reflects real importance and recency, which the arXiv API cannot. Favor results exposing an arXiv ID or direct PDF URL. (Fallback only: `add.py search "<topic>" --sort submittedDate` when web search is unavailable.)
2. Pick the top ~3 most relevant (up to 5 if the topic is broad). **Pull them automatically** — `add.py add "<id-or-url>"` for each not already in the collection. The script dedups by ID; skip and mention duplicates. If a strong candidate has no fetchable PDF, say so and move on.
3. Fill tags for each from `~/papers/.store/<id>.txt` via `set --tags`.
4. **Read and digest each pulled paper** (the point of the whole flow): read `~/papers/.store/<id>.txt`, write the ~300-500 word structured digest, persist it via `add.py digest <id>`. Do this for every paper you pulled, not just on later re-query.
5. **Return to the discussion with synthesized, cited context** — what these papers actually say about the topic, how they relate, where they agree/differ, and which is closest to what the user is after. Lead with the synthesis; the catalog table is secondary. Cite by title/citekey.

**Add** (input contains an arXiv ID/URL, DOI, PDF URL, or local path):
1. Run `add.py add "<input>"`. It prints JSON: `{id, citekey, title, path, flags, needs}`.
2. If `needs` contains `"title"`: read the head of `~/papers/.store/<id>.txt`, determine the real title, run `add.py set <id> --title "<title>"`.
3. If `needs` contains `"tags"`: read the abstract/intro from the same `.txt`, pick 2-4 short topic tags, run `add.py set <id> --tags "tag1,tag2"`.
4. Report what was added (title + citekey) into the discussion. Surface any `flags` (e.g. `duplicate-of:*`, `unverified-metadata`) — do not silently ignore them.

**Query** (a question about the collection) — use the cheapest tier that answers it; stop early:
- **Tier 0** — read `~/papers/.store/INDEX.md`. Often enough to say which papers are relevant or whether one exists.
- **Tier 1** — for the 1-3 relevant papers, read `~/papers/.store/<id>.md` (the digest). If a paper has no digest yet (`has_digest: false`), generate one now: read `~/papers/.store/<id>.txt`, write a ~300-500 word structured digest (TL;DR, key contributions, method, results, limitations), and persist it: `add.py digest <id> < digest.md` (pipe the markdown via stdin). Then use it. Digests are persistent — written once, reused forever.
- **Tier 2** — `grep` across `~/papers/.store/*.txt` for a specific term, number, or equation the digest doesn't cover. Return line hits, not whole files.
- **Tier 3** — read a bounded section of one `.txt` only when Tier 2 located it. Never load a whole PDF into context.

**Both** ("add this and tell me how it relates…"): do Add, then treat the new paper as a Tier-1 query against what you're discussing.

## Rules
- Never read raw PDFs into context — read `.store/*.txt` or digests.
- Never hand-edit `INDEX.md`, `references.bib`, or `index.json` — go through the script (it re-renders on every mutation).
- Always cite which paper a claim came from, by title or citekey — this is a research collection, provenance matters.
- Best-effort is fine: a flagged entry beats a missing one. Report flags rather than hiding them.
