# Coding Guidelines

## Crystal Conventions

- Follow `crystal tool format` output — no manual formatting exceptions.
- `Tokenizer` is an abstract class (not module) — `DefaultTokenizer < Tokenizer`.
- Builder pattern returns `self` (mutating, not consuming).
- `TokenEmbedder(D)` is a module included in structs — no implicit defaults.

## Type Parameters

- `D` = embedding index type (e.g. `UInt32`, `String`)
- `T` = tokenizer type (e.g. `DefaultTokenizer`, `WhitespaceTokenizer`)
- `TokenEmbedder(D)` must be explicitly provided to all constructors/builders.

## Naming

- Types: `PascalCase` — `SearchEngine`, `DefaultTokenizer`, `EmbedderBuilder`
- Methods: `snake_case` — `tokenize`, `upsert`, `with_avgdl`
- Spec files: `spec/<name>_spec.cr` mirrors `src/bm25/<name>.cr`

## Shards

- `crystal-stemmer` — Porter2 stemming (vendored algorithm)
- `deunicode` — Unicode-to-ASCII normalization
- `stopwords` — Stopword lists (NLTK-backed)
- No other shard dependencies for core logic.
