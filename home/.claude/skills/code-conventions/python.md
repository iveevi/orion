# Python conventions

Apply together with `general.md`.

- Do not write docstrings.
- Format all code with `black`.
- Put every import at module top level. Never place an import inside a function or other nested scope. If a top-level import would cause a circular import, break the cycle another way (e.g. `from __future__ import annotations` in the module whose annotations trigger it), not with a deferred local import.
- Import from sibling modules of the same package with `from .module import *`. Never name the imported symbols, and never use a parenthesised multi-line import list. One line per module depended on; the module list is the documentation, not the symbol list.

```python
from .renderer import *
from .scene import *
```

- This applies only to intra-package imports. Third-party and stdlib imports still name what they use (`from dataclasses import dataclass`), since their namespaces are not ours to absorb.
- Use `typing`'s capitalized generic aliases (`List`, `Dict`, `Tuple`, ...) in annotations, not the builtin lowercase generics (`list`, `dict`, ...).
