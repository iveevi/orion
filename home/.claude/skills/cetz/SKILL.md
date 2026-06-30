---
name: cetz
description: Generate publication-quality figures with CeTZ/Typst through an iterative compile-and-critique loop. Use when the user wants to create, draw, or render a diagram, figure, schematic, or illustration as CeTZ/Typst (flowcharts, graph diagrams, plots, neural-net diagrams, geometric figures, etc.), or to refine an existing .typ figure.
---

# CeTZ figure generator

Turn a figure request into a compiled, vector-quality CeTZ figure via a bounded loop:
refine a spec, generate `.typ`, compile to PNG, critique the image, regenerate, repeat.

## Pipeline

### 1. Refine the prompt into a spec (rubric)
Convert the request into a concrete checklist before writing any Typst. The spec is the
objective standard the critique judges against, so make it checkable, not prose.

Capture:
- **Elements**: every node/shape/curve that must appear, with its label text.
- **Layout**: relative positions, alignment, flow direction.
- **Connections**: edges/arrows, their direction and style.
- **Style**: colors, fonts, line styles, overall look.

Show the spec to the user only if the request is ambiguous. Otherwise proceed.

### 2. Create the working dir
```
RUN=$(mktemp -d /tmp/cetz.XXXXXX)
```
Use this ONE dir for the whole run. Copy `templates/style.typ` into it so figures can
`#import "style.typ": *`. Write versioned files: `fig_v1.typ`, `fig_v2.typ`, ... Keep
history so you can fall back if a later version regresses. `/tmp` is tmpfs and
auto-clears, so the dir is scratch only.

### 3. Generate `fig_vN.typ`
Copy `templates/style.typ` next to the figure and import it so every figure inherits the
house style. Body skeleton:
```typ
#import "style.typ": *

#setup(canvas({
  import cetz.draw: *
  // figure body: use nbox/ncircle/nedge helpers and nord* colors
}))
```
- **Style defaults (apply unless the user overrides):**
  - Font: Linux Biolinum, set by `setup()` in the template.
  - Colors: **Nord palette only** (`nord0`..`nord15`, defined in the template). Use
    `nord6` fills, `nord10` strokes, Aurora colors (`nord11`..`nord15`) for accents.
  - Arrows: **Triangle** heads via `mark: (end: ">")`. The `nedge` helper applies this.
- Prefer relative coordinates and named anchors (`name:` on a shape, then `"name.east"`)
  over hand-tuned absolute numbers when layout must stay aligned.
- Prefer the `nbox`/`ncircle`/`nedge` convenience helpers from the template.
- The page is set to `width: auto, height: auto` so output crops to the figure.

CeTZ reference (v0.4.2):
- Draw fns live in `cetz.draw`: `line`, `rect`, `circle`, `content`, `bezier`, `arc`,
  `grid`, `group`, `set-style`. Import once at the top of the canvas block.
- Coordinates: `(x, y)` tuples, `(rel: (dx, dy), to: <coord>)` for relative, or
  `"name.anchor"` strings (anchors: `north`, `south`, `east`, `west`, `center`, ...).
- `content(pos, [body])` places typst markup (math, text) at a point.
- Stroke is `(paint: color, thickness: 1.4pt)`; fill is a color.

### 4. Compile (deterministic, no model judgment)
```
scripts/compile.sh "$RUN/fig_vN.typ"
```
- `COMPILE_OK <png_path>` → proceed to critique.
- `COMPILE_FAILED` + error lines → this is the **compile-error loop**. Read the error,
  fix the `.typ` in the SAME version, recompile. Cap at **3** attempts per version. If
  still failing, simplify the figure rather than fighting one construct.

DPI overridable: `CETZ_DPI=300 scripts/compile.sh ...` (default 300).

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
- `pass: false` and under the cap → write `fig_v(N+1).typ` addressing the defects, go to 4.
- **Aesthetic-loop cap: 4 versions.** On exhaustion, keep the best version and hand to
  the user.
- `pass: true` → done.

### 7. Deliver
Copy the final artifacts out of `/tmp` before the dir clears:
```
cp "$RUN/fig_vN.typ" "$RUN/fig_vN.png" <dest>
```
Default `<dest>` is the CWD as `figure.typ` / `figure.png`, unless the user named a path.
The `.typ` is the real deliverable (editable vector source). If you deliver the `.typ`
alone it will not compile without `style.typ`; either copy `style.typ` alongside it or
inline the template's definitions into the figure. Report both paths and show the final
PNG.

## Notes
- Two loops, kept separate: compile-error (objective, cap 3/version) vs aesthetic
  (subjective, cap 4 versions). Do not conflate "it crashed" with "it looks wrong".
- Never trust the loop to self-terminate. The caps are hard stops; fall back to the user.
- If a later version looks worse than an earlier one, deliver the earlier one.
