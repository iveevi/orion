# General conventions

Apply to all languages.

- Add only code the current change exercises. No unused imports, variables, constants, fields, parameters, helpers, or branches; no speculative abstraction, no handling for cases that cannot yet occur. If nothing calls it now, do not write it.
- Never prefix names with an underscore.
- Use `snake_case` for variables, functions, fields, and other ordinary identifiers.
- Use `PascalCase` for types (classes, structs, enums, type aliases, interfaces).

## Comments

- Use single-line comment syntax only (`//`, `#`), never block/multi-line syntax (`/* */`, `"""`). For multi-line comments, use multiple single-line comments.
- Put each comment on its own line. Never trail a comment off the end of a line of code.
- Only comment non-trivial logic or for sectioning/organizational purposes.
