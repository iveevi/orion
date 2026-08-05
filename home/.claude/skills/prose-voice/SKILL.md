---
name: prose-voice
description: The user's prose voice for technical and academic writing. Use whenever writing, editing, polishing, or rewriting English prose intended for humans - papers, abstracts, related work, README bodies, documentation, commit-message bodies, issue text, or when the user says "polish", "rewrite", "tighten", or "make this read better". Do NOT use for code, code comments, or terse tool output.
---

# Prose voice

Target register: declarative, precise, technical, willing to run long when the
argument needs it, free of rhetorical padding.

## Rules

Match the register of the surrounding document. Do not raise or lower its
formality, vocabulary, or sentence complexity; a long clause-heavy sentence
should stay long. Keep the author's technical vocabulary exactly as written,
including terms of art that resemble filler in ordinary prose.

Avoid the following, which read as machine-written:

- rhetorical antithesis used for cadence: "not X, but Y", "X isn't just Y, it's Z", "it is less about X than about Y"
- three-item lists assembled for rhythm rather than because there are three things
- trailing participial clauses: "..., making it", "..., allowing you to", "..., ensuring that"
- throat-clearing: "it is worth noting", "importantly", "notably", "in essence", "at its core", "fundamentally"
- inflated register: delve, realm, landscape, tapestry, testament, pivotal, intricate
- a closing sentence that restates what was just said

Punctuation is plain ASCII: straight quotes and apostrophes, never typographic.
Do not introduce em dashes or en dashes. Semicolons and colons are fine where
the grammar calls for them.

Never invent facts, numbers, citations, or reference keys. Preserve markup,
math, identifiers, labels, and citation keys byte-for-byte; revise only the
prose between them.

## Exemplars

Read `exemplars.md` in this skill directory before writing anything longer than
a paragraph. It holds human-written, peer-reviewed passages by the author and
his collaborators, indexed by rhetorical move (motivating a gap, stating a
tension, classifying prior work, justifying a design decision, and others).
Match their register, sentence rhythm, and level of hedging. Do not borrow
their topic or vocabulary.
