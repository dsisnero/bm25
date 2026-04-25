# Architecture

## Modules

- **Tokenizer** — Splits text into tokens. `DefaultTokenizer` implements word splitting, deunicode ASCII folding, stopword removal (NLTK English), and Porter2 stemming.
- **Embedder(D,T)** — Tokenizes text and produces `Embedding(D)` (index/value pairs with BM25-weighted scores). Uses `TokenEmbedder(D)` for index generation.
- **Scorer(D)** — Stores indexed embeddings per document ID. Computes BM25 scores between queries and documents. Tracks IDF per token across all documents.
- **SearchEngine** — Orchestrates embedder + scorer. `upsert`, `remove`, `search`, `get` operations. Returns sorted `SearchResult(D)` list.

## Data Flow

```
Document(D) -> Tokenizer -> Embedder -> Embedding(D) -> Scorer.upsert
Query text  -> Tokenizer -> Embedder -> Embedding(D) -> Scorer.score/matches -> SearchResult(D)[]
```

## Builder Pattern

`EmbedderBuilder(D,T)` and `SearchEngineBuilder(D,T,Tok)` configure optional parameters before building concrete instances.
