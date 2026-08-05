"""Standard matplotlib style for data analysis. Import and call `apply_style()`."""

import matplotlib as mpl
import matplotlib.pyplot as plt

SET2 = [
    "#66c2a5",
    "#fc8d62",
    "#8da0cb",
    "#e78ac3",
    "#a6d854",
    "#ffd92f",
    "#e5c494",
    "#b3b3b3",
]

STYLE = {
    "text.usetex": True,
    "text.latex.preamble": r"\usepackage{libertine}\usepackage[libertine]{newtxmath}\usepackage[T1]{fontenc}\renewcommand{\familydefault}{\sfdefault}",
    "font.family": "sans-serif",
    "axes.prop_cycle": mpl.cycler(color=SET2),
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "axes.titlesize": "medium",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "grid.linewidth": 0.5,
    "legend.frameon": False,
}


def apply_style():
    mpl.rcParams.update(STYLE)


def sc(s):
    """Wrap a subplot title in LaTeX small caps."""
    return rf"\textsc{{{s}}}"


if __name__ == "__main__":
    import numpy as np

    apply_style()
    x = np.linspace(0, 2 * np.pi, 200)
    fig, axes = plt.subplots(1, 2, figsize=(8, 3.2))
    for k, ax in enumerate(axes, 1):
        for j in range(3):
            ax.plot(x, np.sin(x + j) * k, label=f"Series {j}")
        ax.set_title(sc(f"Panel {k}: Damped Response"))
        ax.set_xlabel(r"Phase $\phi$ (rad)")
        ax.set_ylabel(r"Amplitude $A$")
        ax.legend()
    fig.savefig("style_demo.pdf")
    print("wrote style_demo.pdf")
