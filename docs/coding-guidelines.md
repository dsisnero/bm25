# Coding Guidelines

## Crystal Conventions

- Follow `crystal tool format` output — no manual formatting exceptions.
- Use abstract classes (not modules) for polymorphism with shared state.
- Builder pattern returns `self` (mutating, not consuming).
- No external shard dependencies for core logic — implement inline.

## Type Generics

- `D` = document/embedding index type (e.g. `UInt32`, `String`)
- `T` = tokenizer type (e.g. `DefaultTokenizer`, `WhitespaceTokenizer`)
- `TokenEmbedder(D)` must be explicitly provided — no unsafe defaults.

## Naming

- Upstream Rust names are preserved (Crystal casing: `snake_case` methods, `PascalCase` types).
- Spec file mirrors source: `src/bm25/foo.cr` → `spec/foo_spec.cr`.
