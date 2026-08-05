---
name: diagram
description: Generate publication-quality diagrams and figures in Typst — fletcher for node-and-arrow diagrams, CeTZ for freeform geometry — compiled to PNG. Use when the user wants to create, draw, or render a diagram, figure, schematic, or illustration (flowcharts, graph/commutative diagrams, state machines, architecture diagrams, neural-net diagrams, plots, geometric figures), or to refine an existing .typ figure.
---

# Diagram generator

Turn a figure request into a compiled, vector-quality Typst figure: refine a spec,
generate `.typ`, compile to PNG, check it against the spec, deliver.

## Backend choice — fletcher first

**Default to fletcher.** It is a node-and-arrow layout engine: you place nodes on a grid
and it computes sizes, edge endpoints, anchoring, and arrow clipping for you. Nearly every
diagram request is a node graph — flowcharts, pipelines, architectures, state machines,
commutative diagrams, block diagrams, trees, DAGs.

**Drop to raw CeTZ only for freeform geometry** — things with no nodes and no edges:
geometric constructions, coordinate plots, annotated shapes, waveforms, hand-placed
illustrations. If you find yourself hand-computing where an arrow should start so it
touches a box edge, you should be using fletcher.

Both come from the same `templates/style.typ`; fletcher re-exports CeTZ, so a figure can
mix them (a fletcher `node` body can contain a CeTZ `canvas`).

## Pipeline

### 1. Refine the prompt into a spec (checklist)
Convert the request into a concrete checklist before writing any Typst. Make it
checkable, not prose — it is what you build against and what you confirm before
delivering.

Capture:
- **Elements**: every node/shape/curve that must appear, with its label text.
- **Layout**: grid positions, alignment, flow direction.
- **Connections**: edges/arrows, their direction and style.
- **Style**: colors, fonts, line styles, overall look.

Show the spec to the user only if the request is ambiguous. Otherwise proceed.

### 2. Create the working dir
```
RUN=$(mktemp -d /tmp/diagram.XXXXXX)
```
Use this ONE dir for the whole run. Copy `templates/style.typ` into it so figures can
`#import "style.typ": *`. Write `fig.typ` there; if the user asks for revisions later,
version them (`fig_v2.typ`, ...) so you can fall back if a revision regresses. `/tmp` is
tmpfs and auto-clears, so the dir is scratch only.

### 3. Generate `fig.typ`
Import the copied template so every figure inherits the house style. Skeleton:
```typ
#import "style.typ": *

#setup(fig(
  node((0, 0), [Input], name: <in>),
  edge("-|>"),
  node((0, 1), [Model]),
  edge(<in>, (1, 1), "--|>", [skip]),
))
```
Freeform fallback (CeTZ):
```typ
#import "style.typ": *

#setup(canvas({
  import cetz.draw: *
  // geometry: line, circle, arc, bezier, content, ...
}))
```

**Style defaults (apply unless the user overrides):**
- Font: Linux Biolinum, set by `setup()`.
- Colors: **Nord palette only** (`nord0`..`nord15` from the template). `nord6` fills,
  `nord10` strokes, Aurora (`nord11`..`nord15`) for accents via `accent-node`.
- Arrows: triangle heads — `"-|>"` in fletcher, `mark: (end: ">")` in raw CeTZ.
- Output crops tight: the page is `width: auto, height: auto`.
- **One page per file.** `typst compile` to PNG fails on multi-page documents; never
  emit a `#pagebreak()`.

**fletcher reference (v0.5.8, wraps CeTZ 0.3.4):**
- `fig(...)` is `diagram(...)` with house defaults (spacing, node stroke/fill/inset,
  corner radius, edge stroke) pre-applied. Override any of them per call.
- `node(pos, label, ..)` — `pos` is a grid coordinate `(col, row)`; rows increase
  **downward**. Useful args: `name: <label>` (referenceable elsewhere),
  `shape: shapes.diamond` (also `pill`, `hexagon`, `circle`, `ellipse`, `cylinder`,
  `parallelogram`, `trapezium`, `triangle`, `house`, `chevron`, `octagon`),
  `fill:`, `stroke:`, `extrude: (0, 3)` (double outline), `radius:`, `inset:`,
  `width:`/`height:`, `enclose: ((0,0), (1,1))` (a group box around other nodes).
  Shapes are under `shapes.*`, not bare names — bare `rect`/`circle` would shadow
  Typst's own elements.
- `edge(from, to, marks, label, ..)` — args are positional-flexible. Omit `from`/`to`
  and it connects the previous and next `node`. Coordinates can be grid tuples, node
  `<names>`, or relative direction strings: `edge("d")`, `edge("rr")`,
  `edge("d,r,u", "-|>")` for a multi-segment path.
  - Marks: `"-|>"` solid arrow, `"<|-|>"` double, `"--|>"` dashed, `"..|>"` dotted,
    `"->>"`, `"hook->"`, `"wave"`, `"stroke: (dash: ...)"` via `stroke:`.
  - Useful args: `bend: 30deg` (curve; `bend: 130deg` with equal endpoints = self-loop),
    `label-pos: 0.3`, `label-side: left|right|center`, `label-sep:`, `corner: right`
    (elbow), `crossing: true` (white gap where edges cross), `shift: 4pt`
    (parallel edges), `decorations: "wave"`.
- Math-mode shorthand for grid-shaped diagrams: `#diagram($A edge(f, ->) & B \ C$)` —
  `&` separates columns, `\` rows. Compact for commutative diagrams.
- Helpers in the template: `accent-node(pos, body, color: nord11)` for a highlighted
  node, `plain-node(pos, body)` for unframed text (annotations, legends, titles).
- Layout knobs on `fig`: `spacing: (3em, 2em)` (x, y), `cell-size:`, `node-defocus:`,
  `debug: 1` (draw the grid — for your own diagnosis, never in the delivered figure).
- fletcher sizes cells to their contents; prefer letting it lay out and only nudge with
  `spacing`/`inset`. Hand-placing coordinates defeats the engine.
- Auto shape selection makes short square-ish labels round. Pass `shape: shapes.rect`
  when nodes must look uniform.

**CeTZ reference (v0.3.4, freeform path):**
- Draw fns live in `cetz.draw`: `line`, `rect`, `circle`, `content`, `bezier`, `arc`,
  `grid`, `group`, `set-style`. Import once at the top of the canvas block.
- Coordinates: `(x, y)` tuples, `(rel: (dx, dy), to: <coord>)` for relative, or
  `"name.anchor"` strings (anchors: `north`, `south`, `east`, `west`, `center`, ...).
- `content(pos, [body])` places Typst markup (math, text) at a point.
- Stroke is `(paint: color, thickness: 1.4pt)`; fill is a color.
- Template helpers: `nbox`, `ncircle`, `nedge`.

### 4. Compile (deterministic, no model judgment)
```
scripts/compile.sh "$RUN/fig.typ"
```
- `COMPILE_OK <png_path>` → proceed.
- `COMPILE_FAILED` + error lines → this is the **compile-error loop**. Read the error,
  fix the `.typ`, recompile. Cap at **3** attempts. If still failing, simplify the figure
  rather than fighting one construct.

DPI overridable: `DIAGRAM_DPI=300 scripts/compile.sh ...` (default 300).

### 5. Deliver
`Read` the PNG once to confirm it matches the step-1 checklist and has no gross defect —
a missing or occluded label, an edge tunneling through a node, a group box clipping an
arrowhead. Fix and recompile only if something is actually broken. Do not iterate on
polish: fletcher's layout is usually right first time, and nudging spacing by eye tends
to regress as often as it improves.

Copy the final artifacts out of `/tmp` before the dir clears:
```
cp "$RUN/fig.typ" "$RUN/fig.png" <dest>
```
Default `<dest>` is the CWD as `figure.typ` / `figure.png`, unless the user named a path.
The `.typ` is the real deliverable (editable vector source). If you deliver the `.typ`
alone it will not compile without `style.typ`; either copy `style.typ` alongside it or
inline the template's definitions into the figure. Report both paths and show the final
PNG.

## Notes
- Reach for raw CeTZ only after asking whether the figure is really a node graph. Most
  are, and fletcher's layout beats hand-placed coordinates every time.
- The only loop is the compile-error loop (objective, cap 3). It is a hard stop, not a
  suggestion — on exhaustion, simplify or fall back to the user.
- Prefer fixing a layout problem structurally — let fletcher place things, split an
  overloaded edge, widen `spacing` — over hand-tuning coordinates until it looks right.
