# Typst conventions

Apply together with `general.md`.

- Use two spaces for indentation.
- Keep lines at 80 characters or less (raw blocks and unbreakable strings exempt).
- When a call would exceed 80 characters, put each argument on its own line and the closing paren on its own line:

```typst
fletcher.node(
  (8.8 * u, 1.6 * u),
  [`StorageBuffer<`#hl(`array<Light>`)`, `#hl(`std430`)`> lights`],
  fill: panel_colors.body,
  stroke: 1.2pt + panel_colors.border,
  corner-radius: 0.12 * u,
  inset: 0.5em,
  name: <type>,
)
```

- Positional arguments that form one logical group (e.g. an edge's endpoints and marker string) may share a line; keyword arguments each get their own line.
- Enforce mechanically with `typstyle --line-width 80 -i <files>` (it never changes rendering; verify with a pixel compare when in doubt).

```typst
fletcher.edge(
  <tag>, (7.5 * u, 1.15 * u), "-|>",
  bend: 20deg,
  label: note[Data type],
  label-pos: 0.35,
  label-side: left,
)
```
