---
name: code-conventions
description: The user's mandatory code style conventions for all projects. Load and apply whenever writing or editing source code in any language. Contains a shared general ruleset plus per-language rules. Always read general.md, then read the file matching the language being edited.
---

# code-conventions

Mandatory style rules for all code the user owns. Apply on every write or edit.

## How to use

1. Always apply `general.md` (shared across all languages).
2. Additionally read and apply the file matching the language being edited.

| Language / family        | File          |
| ------------------------ | ------------- |
| All languages            | `general.md`  |
| Python                   | `python.md`   |
| C, C++, CUDA, WGSL, Slang | `c-family.md` |
| Rust                     | `rust.md`     |
| Typst                    | `typst.md`    |
| Porcelain (.por)         | `porcelain.md` |

If no per-language file exists, apply `general.md` alone.
