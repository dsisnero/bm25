# Coding Guidelines

## Core Rules

- Preserve upstream Rust behavior first; prefer Crystal idioms only when they do not change observable behavior.
- Keep public types under the `Bm25` module.
- Run `crystal tool format` before verification.
- Do not add shard dependencies for behavior that can be ported locally with reasonable scope.
- Update parity inventories whenever upstream coverage or source mapping changes.

## Types And Interfaces

`Tokenizer` is an abstract class:

```crystal
class MyTokenizer < Bm25::Tokenizer
  def tokenize(input_text : String) : Array(String)
    input_text.split
  end
end
```

`TokenEmbedder(D)` is a module:

```crystal
struct MyEmbedder
  include Bm25::TokenEmbedder(UInt32)

  def embed(token : String) : UInt32
    token.size.to_u32
  end
end
```

Use explicit generic parameters:

- `K` for document ID type
- `D` for embedding index type
- `T` for tokenizer type

Avoid implicit defaults in constructors and builder factories when they obscure parity. The code requires explicit token embedder instances such as `Bm25::U32Embedder.new`.

## Builders

Builder methods mutate and return `self`:

```crystal
builder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_avgdl(128.0_f32, Bm25::U32Embedder.new)
  .language_mode(Bm25::Language::English)
  .b(0.75_f32)

embedder = builder.build
```

This differs from Rust's consuming builder style and matches Crystal object semantics.

## Tokenizer Implementation

Keep tokenizer behavior snapshot-driven:

- `Bm25.deunicode` is local and table-driven.
- `Bm25.split_unicode_words` owns punctuation, decimal, apostrophe, emoji, and degree-symbol splitting behavior.
- English stopwords and Porter2 stemming are local.
- German stopwords and stemming are local.
- Detect mode is English/German only and based on stopword counts.

When changing tokenizer behavior, update or add specs against `vendor/bm25/data` and `vendor/bm25/snapshots`.

## Numeric Behavior

Use explicit numeric types where parity depends on precision or overflow:

- `Float32` for BM25 weights and scores.
- `UInt32` / `UInt64` for default embedding spaces.
- Wrapping arithmetic for fxhash (`&*`) where required.
- Explicit suffixes such as `1.2_f32`, `0_u32`, and `0xff_u64`.

## Specs

Prefer specs that mirror upstream test intent and names. Use dataset or snapshot fixtures when upstream does.

Keep helper code in `spec/support` when it mirrors upstream helpers, such as the recipe CSV loader.

## Naming

- Types: `PascalCase`, for example `SearchEngine`, `DefaultTokenizer`, `EmbedderBuilder`.
- Methods: `snake_case`, for example `tokenize`, `upsert`, `with_avgdl`.
- Specs: `*_spec.cr`.
- Fixture helpers: descriptive method names such as `recipe_corpus` and `assert_search_snapshot`.

## Documentation

When adding API or behavior:

- update README examples if public usage changes
- update `docs/architecture.md` for new runtime patterns
- update `docs/testing.md` for new fixture or snapshot strategy
- update inventory notes for intentional drift
