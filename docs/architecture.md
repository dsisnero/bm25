# Architecture

## Modules

All types live under the `Bm25` module, one file per component:

| Module | File | Description |
|--------|------|-------------|
| `Tokenizer` | `src/bm25/tokenizer.cr` | Abstract class — subclasses implement `tokenize(String) : Array(String)` |
| `DefaultTokenizer` | `src/bm25/default_tokenizer.cr` | Full-featured tokenizer with unicode normalization, stemming (Porter2 via crystal-stemmer), stopword removal (NLTK-backed), and word-boundary splitting |
| `Embedder(D, T)` | `src/bm25/embedder.cr` | Tokenizes text and produces `Embedding(D)` — index/value pairs with BM25-weighted scores |
| `EmbedderBuilder(D, T)` | `src/bm25/embedder.cr` | Builder for `Embedder` — configures k1, b, avgdl, tokenizer |
| `TokenEmbedder(D)` | `src/bm25/embedder.cr` | Module — implement to customize the hash function from token to index |
| `Scorer(K, D)` | `src/bm25/scorer.cr` | Stores indexed embeddings per document ID K, computes BM25 scores, tracks IDF |
| `SearchEngine(K, D, T)` | `src/bm25/search.cr` | Orchestrates embedder + scorer — upsert, remove, search, get |
| `SearchEngineBuilder(K, D, T)` | `src/bm25/search.cr` | Builder for `SearchEngine` — fits avgdl to corpus |

## Data Flow

```
Document --[Tokenizer]--> tokens --[Embedder]--> Embedding(D) --[Scorer.upsert]--> indexed corpus
Query    --[Tokenizer]--> tokens --[Embedder]--> Embedding(D) --[Scorer.matches]--> SearchResult(D)[]
```

## Builder Pattern

Both `EmbedderBuilder(D, T)` and `SearchEngineBuilder(K, D, T)` use a mutating builder pattern (returning `self`). Call `.build` to produce the concrete instance.

## Generics

- `K` — Document ID type (`UInt32`, `String`, etc.)
- `D` — Embedding index type (`UInt32`, `UInt64`, `String`, etc.)
- `T` — Tokenizer type (subclass of `Tokenizer`)
