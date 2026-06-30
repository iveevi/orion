#import "style.typ": *

#setup(canvas({
  import cetz.draw: *

  // ---- Pipeline spine ----
  nbox((0, 0), [Source], name: "src")
  nbox((0, -1.6), [Frontend], name: "fe")
  nbox((0, -3.2), [IR], name: "ir")
  nbox((0, -4.8), text(fill: nord0)[Optimizer], name: "opt", border: nord11)
  nbox((0, -6.4), [Backend], name: "be")
  nbox((0, -8.0), [Machine code], name: "mc")

  nedge("src.south", "fe.north")
  nedge("fe.south", "ir.north")
  nedge("ir.south", "opt.north")
  nedge("opt.south", "be.north")
  nedge("be.south", "mc.north")

  content((1.7, -0.8), text(size: 9pt, style: "italic", fill: nord3)[emit IR])
  content((1.9, -5.6), text(size: 9pt, style: "italic", fill: nord3)[codegen])

  // ---- Side panel: passes ----
  let pass(pos, body, c) = nbox(pos, text(size: 9pt)[#body], bg: nord6, border: c, w: 2.8, h: 0.62)

  content((4.2, 0.2), text(weight: "bold", fill: nord0)[Analysis])
  pass((4.2, -0.7), [Dominator Tree], nord13)
  pass((4.2, -1.5), [Alias Analysis], nord13)
  pass((4.2, -2.3), [Loop Info], nord13)

  content((7.6, 0.2), text(weight: "bold", fill: nord0)[Transforms])
  pass((7.6, -0.7), [Mem2Reg], nord8)
  pass((7.6, -1.5), [InstCombine], nord8)
  pass((7.6, -2.3), [GVN / DCE], nord8)

  line("opt.east", (3.4, -4.8), stroke: (paint: nord11, thickness: 1.4pt), mark: (start: ">", end: ">"))
  content((2.5, -4.3), text(size: 8pt, style: "italic", fill: nord11)[iterate])
}))
