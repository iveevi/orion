---
name: explain
description: Explain a topic, codebase, or concept at a concise, high level. Use whenever the user asks to explain, describe, or give an overview of something ("explain X", "how does X work", "what does this do"). Prioritizes the big picture over exhaustive detail.
---

# explain

Explain at a high level of abstraction, as concisely as possible.

## Rules

1. Lead with the core idea in one or two sentences. The reader should grasp the essence before any detail.
2. Stay at the architectural / conceptual level. Describe what components do and how they relate, not line-by-line mechanics.
3. Hard cap: aim for under ~150 words. Only exceed if the user asks for more depth.
4. Omit edge cases, caveats, history, and alternatives unless directly asked.
5. No exhaustive enumerations. Pick the 2-4 elements that matter; say "among others" if needed.
6. Use an analogy only if it compresses the explanation, never as decoration.
7. Structure: prefer short prose or a tight bullet list. No nested headings for a short explanation.
8. For code: name the entry point, the main data flow, and the key abstraction. Do not paste code blocks unless a specific snippet is the answer.
9. End when the question is answered. Do not offer to elaborate; the user will ask.
