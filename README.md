# bm25

A Crystal port of [Michael-JB/bm25](https://github.com/Michael-JB/bm25) — a BM25 crate for everything [Okapi BM25](https://en.wikipedia.org/wiki/Okapi_BM25). Provides utilities at three levels:

1. **BM25 Embedder** — Embeds text into a sparse vector space for information retrieval.
2. **BM25 Scorer** — Scores query embedding relevance against document embeddings.
3. **BM25 Search Engine** — Fast, light-weight, in-memory keyword search.

## Documentation

- [Architecture](docs/architecture.md) — Module structure and data flow
- [Development](docs/development.md) — Dev setup, submodule, branching
- [Coding Guidelines](docs/coding-guidelines.md) — Style, naming, conventions
- [Testing](docs/testing.md) — Spec structure and parity testing
- [PR Workflow](docs/pr-workflow.md) — PR lifecycle and review criteria

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  bm25:
    github: dsisnero/bm25
```

Then `shards install`.

## Usage

### Embed

Fit an embedder to your corpus:

```crystal
require "bm25"

corpus = [
  "The sky blushed pink as the sun dipped below the horizon.",
  "Apples, oranges, papayas, and more papayas.",
  "She found a forgotten letter tucked inside an old book.",
  "A single drop of rain fell, followed by a thousand more.",
]

embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_fit_to_corpus(Bm25::LanguageMode::Fixed(Bm25::Language::English), corpus, Bm25::U32Embedder.new)
  .build

embedding = embedder.embed(corpus[1])
```

### Score

Use the scorer directly:

```crystal
scorer = Bm25::Scorer(UInt32, UInt32).new
embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_fit_to_corpus(Bm25::LanguageMode::Fixed(Bm25::Language::English), corpus, Bm25::U32Embedder.new)
  .build

corpus.each_with_index do |doc, i|
  scorer.upsert(i.to_u32, embedder.embed(doc))
end

query_embedding = embedder.embed("pink")
matches = scorer.matches(query_embedding)
```

### Search

In-memory search engine:

```crystal
engine = Bm25::SearchEngineBuilder(UInt32, UInt32, Bm25::DefaultTokenizer)
  .with_corpus(Bm25::LanguageMode::Fixed(Bm25::Language::English), corpus, Bm25::U32Embedder.new)
  .build

results = engine.search("orange", 3)
```

### Custom tokenizer

```crystal
class MyTokenizer < Bm25::Tokenizer
  def tokenize(text : String) : Array(String)
    text.split('T').reject(&.empty?)
  end
end

embedder = Bm25::Embedder(UInt32, MyTokenizer).new(
  MyTokenizer.new, Bm25::U32Embedder.new, avgdl: 1.0
)
```

### Custom embedder

```crystal
struct MyEmbedder
  include Bm25::TokenEmbedder(String)
  def embed(token : String) : String
    token
  end
end

embedder = Bm25::Embedder(String, Bm25::DefaultTokenizer).new(
  Bm25::DefaultTokenizer.new, MyEmbedder.new, avgdl: 3.0
)
```

## License

[MIT](https://github.com/dsisnero/bm25/blob/main/LICENSE)
