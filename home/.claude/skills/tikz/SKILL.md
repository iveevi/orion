---
name: tikz
description: Generate publication-quality figures with TikZ/LaTeX through an iterative compile-and-critique loop. Use when the user wants to create, draw, or render a diagram, figure, schematic, or illustration as TikZ/LaTeX (flowcharts, graph diagrams, plots, neural-net diagrams, geometric figures, etc.), or to refine an existing .tex figure.
---

# TikZ figure generator

Turn a figure request into a compiled, vector-quality TikZ figure via a bounded loop:
refine a spec, generate `.tex`, compile to PNG, critique the image, regenerate, repeat.

## Pipeline

### 1. Refine the prompt into a spec (rubric)
Convert the request into a concrete checklist before writing any LaTeX. The spec is the
objective standard the critique judges against, so make it checkable, not prose.

Capture:
- **Elements**: every node/shape/curve that must appear, with its label text.
- **Layout**: relative positions, alignment, flow direction.
- **Connections**: edges/arrows, their direction and style.
- **Style**: colors, fonts, line styles, overall look.

Show the spec to the user only if the request is ambiguous. Otherwise proceed.

### 2. Create the working dir
```
RUN=$(mktemp -d /tmp/tikz.XXXXXX)
```
Use this ONE dir for the whole run. Write versioned files into it: `fig_v1.tex`,
`fig_v2.tex`, ... Keep history so you can fall back if a later version regresses.
`/tmp` is tmpfs and auto-clears, so the dir is scratch only.

### 3. Generate `fig_vN.tex`
Start from `templates/style.tex` (copy its preamble verbatim) so every figure inherits
the house style. Then add the `\begin{document}...\end{document}` body:
```latex
\begin{document}
\begin{tikzpicture}
  % figure body: use nbox/ncircle/nedge styles and nord* colors
\end{tikzpicture}
\end{document}
```
- **Style defaults (apply unless the user overrides):**
  - Font: Linux Biolinum, set by `\usepackage[sfdefault]{biolinum}` in the template.
  - Colors: **Nord palette only** (`nord0`..`nord15`, defined in the template). Use
    `nord6` fills, `nord10` outlines, Aurora colors (`nord11`..`nord15`) for accents.
  - Arrows: **Triangle** heads, set as the default `>` tip in the template. Use `->`,
    `<-`, `<->` normally; they pick up Triangle automatically.
- Prefer `positioning` (`right=of`, `below=of`) over manual coordinates for layout that
  must stay aligned. Prefer the `nbox`/`ncircle`/`nedge` convenience styles.
- Keep `standalone` so output crops to the figure. The template already requires it.

### 4. Compile (deterministic, no model judgment)
```
scripts/compile.sh "$RUN/fig_vN.tex"
```
- `COMPILE_OK <png_path>` → proceed to critique.
- `COMPILE_FAILED` + error lines → this is the **compile-error loop**. Read the error,
  fix the `.tex` in the SAME version, recompile. Cap at **3** attempts per version. If
  still failing, simplify the figure rather than fighting one construct.

Engine/DPI overridable: `TIKZ_ENGINE=lualatex TIKZ_DPI=300 scripts/compile.sh ...`
(use `lualatex` only if a figure needs more memory or modern fonts).

### 5. Critique the image (separate adversarial eyes)
Do NOT judge your own output inline. Spawn a fresh subagent with the Agent tool so the
critique is independent of the code you just wrote.

Give the subagent the **spec rubric** and the **PNG path**, and instruct it to:
1. `Read` the PNG.
2. Check each rubric item: present? correct? readable?
3. Look for defects vision reliably catches: overlapping/clipped elements, text outside
   bounds, missing or duplicated labels, wrong arrow direction, illegible text,
   bad spacing.
4. **Hunt for artifacts (this generator's known failure mode).** Flag anything that does
   not belong:
   - **Occluded labels**: text hidden behind a node, edge, or fill; partially covered
     glyphs; labels colliding with arrows.
   - **Stray marks**: rogue lines or dots, dangling/unconnected edges, arrowheads
     pointing at nothing, leftover construction paths, double-drawn shapes, stray fill
     bleeding outside a node, unintended coordinates rendered as visible points.
   Any such artifact is an automatic `pass: false`, even if every rubric item is present.
5. Return strict JSON: `{"pass": bool, "defects": ["specific, actionable item", ...]}`.

Treat the subagent as a gate. Vision catches gross defects, not pixel-level polish, so
do not loop forever chasing alignment it cannot measure.

### 6. Iterate or stop
- `pass: false` and under the cap → write `fig_v(N+1).tex` addressing the defects, go to 4.
- **Aesthetic-loop cap: 4 versions.** On exhaustion, keep the best version and hand to
  the user.
- `pass: true` → done.

### 7. Deliver
Copy the final artifacts out of `/tmp` before the dir clears:
```
cp "$RUN/fig_vN.tex" "$RUN/fig_vN.png" <dest>
```
Default `<dest>` is the CWD as `figure.tex` / `figure.png`, unless the user named a path.
The `.tex` is the real deliverable (editable vector source). Report both paths and show
the final PNG.

## Notes
- Two loops, kept separate: compile-error (objective, cap 3/version) vs aesthetic
  (subjective, cap 4 versions). Do not conflate "it crashed" with "it looks wrong".
- Never trust the loop to self-terminate. The caps are hard stops; fall back to the user.
- If a later version looks worse than an earlier one, deliver the earlier one.
