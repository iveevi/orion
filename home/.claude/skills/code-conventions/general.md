# General conventions

Apply to all languages.

- Add only code the current change exercises. No unused imports, variables, constants, fields, parameters, helpers, or branches; no speculative abstraction, no handling for cases that cannot yet occur. If nothing calls it now, do not write it.
- Always use an explicit `return` keyword where the language allows a value to be returned implicitly (Rust's trailing expression, and the like). This is about never relying on an implicit return *value*; it does not mean putting a bare `return` at the end of a void/`-> None` function.
- Never prefix names with an underscore.
- Use `snake_case` for variables, functions, fields, and other ordinary identifiers.
- Use `PascalCase` for types (classes, structs, enums, type aliases, interfaces).

## Comments

- Never write comments. Code must be self-explanatory through naming and structure.
- This is absolute: no explanatory comments, no section headers, no docstrings, no TODO/FIXME markers, no commented-out code.
- Do not add comments even when the surrounding file already has them.
- Preserve comments that already exist in code you are editing; never introduce new ones.
- Sole exceptions, only when functionally required: shebang lines, encoding declarations, license headers mandated by the project, and pragmas the toolchain reads (`# type: ignore`, `// eslint-disable`, `# noqa`).
