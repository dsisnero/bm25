# Architecture

This repository is a Crystal port of the upstream Rust `bm25` crate. The implementation is intentionally small: all public runtime types live under `Bm25`, and the data path is tokenizer -> embedder -> scorer -> optional search engine.

## Module Layout

| Component | File | Purpose |
|---|---|---|
| `Bm25::Tokenizer` | `src/bm25/tokenizer.cr` | Abstract tokenizer contract. Custom tokenizers subclass it and implement `tokenize(String) : Array(String)`. |
| `Bm25::DefaultTokenizer` | `src/bm25/default_tokenizer.cr` | Built-in tokenizer with normalization, lowercasing, word splitting, stopword removal, stemming, and fixed/detect language modes. |
| `Bm25::Language` / `LanguageMode` | `src/bm25/default_tokenizer.cr` | Language enum and fixed/detect tokenizer mode wrapper. |
| `Bm25::TokenEmbedding(D)` | `src/bm25/embedder.cr` | One sparse embedding item: an index plus its BM25 term-frequency weight. |
| `Bm25::Embedding(D)` | `src/bm25/embedder.cr` | Ordered wrapper around `Array(TokenEmbedding(D))` with `indices`, `values`, `each_index`, and `each_value`. |
| `Bm25::TokenEmbedder(D)` | `src/bm25/embedder.cr` | Module interface for converting a token string into an embedding index of type `D`. |
| `Bm25::U32Embedder` / `U64Embedder` | `src/bm25/embedder.cr` | Built-in token embedders using Rust-compatible fxhash output. |
| `Bm25::NoDefaultTokenizer` | `src/bm25/embedder.cr` | Sentinel type mirroring upstream's feature-gated dummy tokenizer. It fails fast if used. |
| `Bm25::Embedder(D, T)` | `src/bm25/embedder.cr` | Tokenizes text and produces sparse BM25-weighted embeddings. |
| `Bm25::EmbedderBuilder(D, T)` | `src/bm25/embedder.cr` | Configures `k1`, `b`, `avgdl`, tokenizer, language mode, and token embedder. |
| `Bm25::Scorer(K, D)` | `src/bm25/scorer.cr` | Stores document embeddings and an inverted token index, then scores query embeddings. |
| `Bm25::Document(K)` | `src/bm25/search.cr` | Document ID and raw string contents. |
| `Bm25::SearchEngine(K, D, T)` | `src/bm25/search.cr` | In-memory document store built on `Embedder` and `Scorer`. |
| `Bm25::SearchEngineBuilder(K, D, T)` | `src/bm25/search.cr` | Builds search engines from `avgdl`, documents, corpus strings, or custom tokenizers. |

## Data Flow

```text
document text
  -> Tokenizer#tokenize
  -> Array(String)
  -> TokenEmbedder(D)#embed for each token
  -> Embedding(D)
  -> Scorer#upsert(document_id, embedding)
```

Query flow mirrors document flow:

```text
query text
  -> Embedder#embed
  -> query Embedding(D)
  -> Scorer#matches
  -> SearchEngine#search
  -> Array(SearchResult(K))
```

`SearchEngine` is a convenience layer. Callers that already own document storage can use `Embedder` and `Scorer` directly.

## BM25 Embeddings

`Embedder#embed` computes per-token values before IDF is applied:

1. Tokenize input text.
2. Convert tokens into embedding indices through `TokenEmbedder(D)`.
3. Count term frequency per index.
4. Compute the BM25 term-frequency normalization using `k1`, `b`, document length, and `avgdl`.
5. Return one `TokenEmbedding(D)` per token occurrence, preserving repeated tokens.

`Scorer` applies IDF at query time using the indexed corpus:

```text
idf = log(1 + (n_docs - token_frequency + 0.5) / (token_frequency + 0.5))
score = sum(idf(token) * document_token_value(token))
```

Matches are sorted descending by score.

## Tokenizer Behavior

The default tokenizer follows the upstream behavior expected by the current parity snapshots:

- Optional unicode-to-ASCII normalization through the local `Bm25.deunicode` table.
- Lowercase conversion before token filtering and stemming.
- Word splitting in `Bm25.split_unicode_words`, with punctuation splitting, decimal preservation, apostrophe handling, emoji text normalization, and degree symbol normalization.
- English and German stopword sets embedded in `src/bm25/default_tokenizer.cr`.
- English stemming through the local `Porter2` module.
- German stemming through the local `GermanStemmer` module.

`LanguageMode.fixed(language)` uses the supplied language. `Bm25.fixed(language)` is the public convenience wrapper.

`LanguageMode.detect` stores no fixed language. `DefaultTokenizer` resolves Detect by counting English and German stopwords in the normalized token stream and choosing German only when its score is higher. This is enough for the current upstream English/German detection parity tests, but it is intentionally documented as drift from Rust's optional `whichlang` feature.

## Builders

Builders are mutating Crystal builders. Setter methods update internal state and return `self`:

```crystal
embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_avgdl(128.0_f32, Bm25::U32Embedder.new)
  .language_mode(Bm25::Language::English)
  .b(0.75_f32)
  .k1(1.2_f32)
  .build
```

Constructors and builder factories require an explicit `TokenEmbedder(D)` instance. This is deliberate: Crystal does not use Rust's default type parameters and feature flags in the same way, so the port keeps dependency and type behavior explicit.

## Generics

- `K`: document ID type, for example `UInt32` or `String`.
- `D`: embedding index type, for example `UInt32`, `UInt64`, or a custom type.
- `T`: tokenizer type, usually `Bm25::DefaultTokenizer` or a custom subclass of `Bm25::Tokenizer`.

`TokenEmbedder(D)` must return the same `D` used by the embedder, scorer, and search engine.

## Hashing

`Bm25.hash32` and `Bm25.hash64` implement Rust `fxhash` string behavior, including the Rust string sentinel byte. This preserves upstream snapshot output for default `UInt32` and `UInt64` embedding spaces.

## Search Engine

`SearchEngine` owns:

- an `Embedder(D, T)` for new documents and queries
- a `Scorer(K, D)` for sparse embedding scoring
- a `Hash(K, String)` for document contents

`with_corpus` assigns `UInt32` IDs from the corpus index. `with_documents` preserves caller-provided IDs.

Upserting an existing ID removes the previous embedding before indexing the new one. Removing deletes both stored contents and scorer state.

## Parity Files

Parity status is tracked in:

- `plans/inventory/rust_source_parity.tsv`
- `plans/inventory/rust_test_parity.tsv`
- `plans/inventory/rust_port_inventory.tsv`

The Rust upstream checkout is `vendor/bm25`. Snapshot fixtures and CSV recipe data are read directly from that checkout in specs.
