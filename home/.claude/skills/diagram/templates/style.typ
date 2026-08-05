// House diagram style: Linux Biolinum font, Nord palette, triangle arrow heads.
// Import into every generated figure:
//   #import "style.typ": *
// Preferred path is fletcher (`diagram`/`node`/`edge`); drop to raw cetz
// (`canvas({ import cetz.draw: * ; ... })`) only for freeform geometry.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#let cetz = fletcher.cetz
#let canvas = cetz.canvas
#let draw = cetz.draw
// Node shapes live under `shapes.*` (shapes.diamond, shapes.pill, shapes.hexagon,
// ...). Not wildcard-imported: `rect`/`circle`/`ellipse` would shadow the Typst
// built-in elements of the same name.
#let shapes = fletcher.shapes

// --- Nord palette ----------------------------------------------------------
// Polar Night (dark)
#let nord0 = rgb("#2E3440")
#let nord1 = rgb("#3B4252")
#let nord2 = rgb("#434C5E")
#let nord3 = rgb("#4C566A")
// Snow Storm (light)
#let nord4 = rgb("#D8DEE9")
#let nord5 = rgb("#E5E9F0")
#let nord6 = rgb("#ECEFF4")
// Frost (blue/teal)
#let nord7 = rgb("#8FBCBB")
#let nord8 = rgb("#88C0D0")
#let nord9 = rgb("#81A1C1")
#let nord10 = rgb("#5E81AC")
// Aurora (accents)
#let nord11 = rgb("#BF616A") // red
#let nord12 = rgb("#D08770") // orange
#let nord13 = rgb("#EBCB8B") // yellow
#let nord14 = rgb("#A3BE8C") // green
#let nord15 = rgb("#B48EAD") // purple

// --- Page + text defaults --------------------------------------------------
// Tight crop to the figure, Linux Biolinum as default font.
#let setup(body) = {
  set page(width: auto, height: auto, margin: 6pt, fill: white)
  set text(font: "Linux Biolinum", fill: nord0, size: 11pt)
  body
}

// --- fletcher: house-styled diagram ----------------------------------------
// Same signature as fletcher's `diagram`, with house defaults pre-applied.
// Override any of them per call: `#fig(spacing: 4em, node-fill: nord13, ...)`.
#let fig(
  spacing: 2.4em,
  node-stroke: (paint: nord10, thickness: 1.4pt),
  node-fill: nord6,
  node-corner-radius: 3pt,
  node-inset: 8pt,
  edge-stroke: (paint: nord3, thickness: 1.2pt),
  ..args,
) = diagram(
  spacing: spacing,
  node-stroke: node-stroke,
  node-fill: node-fill,
  node-corner-radius: node-corner-radius,
  node-inset: node-inset,
  edge-stroke: edge-stroke,
  ..args,
)

// Accent variants: a node in one of the Aurora colors, everything else default.
#let accent-node(pos, body, color: nord11, ..args) = node(
  pos, body,
  stroke: (paint: color, thickness: 1.4pt),
  fill: color.lighten(78%),
  ..args,
)

// Label-only node: text with no frame (headings, annotations, math terms).
#let plain-node(pos, body, ..args) = node(pos, body, stroke: none, fill: none, ..args)

// --- raw cetz helpers (freeform figures only) ------------------------------
// Use inside `canvas({ ... })` when the figure is geometry, not a node graph.
// Helpers qualify every call as `draw.*`; a wildcard `import cetz.draw: *` in
// their bodies would shadow the `fill`/`stroke` parameters.

#let nbox(pos, body, name: none, bg: nord6, border: nord10, w: 2.6, h: 0.9) = {
  draw.rect(
    (rel: (-w / 2, -h / 2), to: pos),
    (rel: (w / 2, h / 2), to: pos),
    radius: 0.12, fill: bg, stroke: (paint: border, thickness: 1.4pt),
    name: name,
  )
  draw.content(pos, text(fill: nord0)[#body])
}

#let ncircle(pos, body, name: none, bg: nord6, border: nord10, r: 0.6) = {
  draw.circle(pos, radius: r, fill: bg, stroke: (paint: border, thickness: 1.4pt), name: name)
  draw.content(pos, text(fill: nord0)[#body])
}

#let nedge(from, to, paint: nord3, ..args) = {
  draw.line(from, to, stroke: (paint: paint, thickness: 1.4pt), mark: (end: ">"), ..args)
}
