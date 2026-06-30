// Default figure style: Linux Biolinum font, Nord palette, triangle arrow heads.
// Import this file into every generated figure to inherit the house style:
//   #import "style.typ": *
// then build the figure inside `canvas({ import cetz.draw: *; ... })`.

#import "@preview/cetz:0.4.2"
#let canvas = cetz.canvas
#let draw = cetz.draw

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

// --- Drawing convenience helpers -------------------------------------------
// Use cetz.draw functions inside canvas. These wrap common house styles.
// Triangle arrow heads: pass `mark: (end: ">")` to cetz line(); ">" is the
// triangle (stealth-like) tip in cetz.
//
// NOTE: helpers qualify every call as `draw.*` and avoid `import cetz.draw: *`
// inside their bodies. A wildcard import would shadow `fill`/`stroke` params
// with cetz's own draw functions of the same name.

// Rounded box node centered at `pos` with `body` text. Returns nothing; draws.
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

// Directed edge between two coordinates/anchors with a triangle head.
#let nedge(from, to, paint: nord3, ..args) = {
  draw.line(from, to, stroke: (paint: paint, thickness: 1.4pt), mark: (end: ">"), ..args)
}
