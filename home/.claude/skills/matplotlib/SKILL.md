---
name: matplotlib
description: Apply the user's standard matplotlib style to any data analysis plotting. Use whenever creating charts, plots, or figures with matplotlib/seaborn in Python. Enforces LaTeX rendering, Linux Biolinum sans-serif font, seaborn Set2 palette, and titling conventions.
---

# Standard matplotlib style

Apply this style to every matplotlib figure produced during data analysis.

## Usage

Copy or import `plot.py` (located in this skill directory) and call `apply_style()` before plotting:

```python
from plot import apply_style, sc, SET2
apply_style()
ax.set_title(sc("Damped Response"))
```

`apply_style()` sets rcParams globally. `sc(text)` wraps a subplot title in LaTeX small caps (`\textsc{...}`). `SET2` is the color list if you need it directly.

## Conventions (not enforced by rcParams — follow them)

- **LaTeX is always on.** Wrap math in `$...$`. Escape literal `%`, `_`, `&` in text labels.
- **Font:** Linux Biolinum (sans-serif companion to Libertine), via the `libertine` LaTeX package with `newtxmath` for matching math glyphs.
- **Capitalization:** Use proper Title Case for axis labels, legend entries, and subplot titles.
- **No figure-level (`suptitle`) titles.** Do not add a top-level title.
- **Every subplot (Axes) gets its own descriptive title** via `ax.set_title(sc(...))`, rendered in small caps.
- **Palette:** seaborn Set2 (8 colors), applied as the axes color cycle.

## Requirements

Needs a LaTeX install (`pdflatex`) with the `libertine`, `newtxmath`, and `fontenc` packages. Verify with `kpsewhich libertine.sty biolinum.sty`.

Run `python plot.py` in this directory to render `style_demo.pdf` and confirm the setup works.
