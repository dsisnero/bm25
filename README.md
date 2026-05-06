# bm25

Crystal port of [Michael-JB/bm25](https://github.com/Michael-JB/bm25), a BM25 library for sparse text embeddings, scoring, and lightweight in-memory keyword search.

This shard exposes three layers:

1. **Embedder**: turns text into sparse BM25-weighted embeddings.
2. **Scorer**: scores query embeddings against indexed document embeddings.
3. **SearchEngine**: stores documents and searches them through the embedder and scorer.

## Documentation

- [Architecture](docs/architecture.md): modules, data flow, tokenizer behavior, builders, and parity notes
- [Development](docs/development.md): setup, upstream source of truth, commands, and inventory checks
- [Coding Guidelines](docs/coding-guidelines.md): Crystal patterns used by this port
- [Testing](docs/testing.md): spec layout, upstream fixtures, snapshots, and parity gates
- [PR Workflow](docs/pr-workflow.md): review expectations for parity changes

## Features

- Sparse BM25 embeddings with configurable `k1`, `b`, and `avgdl`
- Direct scoring API for callers that manage documents themselves
- In-memory search engine with `upsert`, `remove`, `get`, `each`, and `search`
- Default tokenizer with unicode normalization, punctuation splitting, stopword removal, and stemming
- Fixed language modes for English and German parity coverage, plus `Bm25.detect`
- `UInt32` and `UInt64` fxhash-compatible token embedders
- Custom tokenizer and token embedder extension points
- Upstream Rust fixture and snapshot parity specs

## Installation

Add this shard to `shard.yml`:

```yaml
dependencies:
  bm25:
    github: dsisnero/bm25
```

Then install dependencies:

```bash
shards install
```

## BM25 Parameters

BM25 scores query relevance using term frequency, inverse document frequency, and document length normalization.

- `avgdl` is the average meaningful token count for the corpus. Fit it from a known corpus when possible.
- `b` controls document length normalization. `0.75` is the default; `0` disables length normalization.
- `k1` controls the effect of repeated terms. `1.2` is the default.

When you do not have the full corpus available, use `with_avgdl` with a reasonable estimate.

## Embed

Fit an embedder to a corpus and embed text:

```crystal
require "bm25"

corpus = [
  "The sky blushed pink as the sun dipped below the horizon.",
  "Apples, oranges, papayas, and more papayas.",
  "She found a forgotten letter tucked inside an old book.",
  "A single drop of rain fell, followed by a thousand more.",
]

embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_fit_to_corpus(Bm25.fixed(Bm25::Language::English), corpus, Bm25::U32Embedder.new)
  .build

embedding = embedder.embed(corpus[1])

embedding.indices # => Array(UInt32)
embedding.values  # => Array(Float32)
```

Build from explicit BM25 parameters:

```crystal
embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_avgdl(7.0_f32, Bm25::U32Embedder.new)
  .b(0.75_f32)
  .k1(1.2_f32)
  .build
```

## Language Mode

Use a fixed tokenizer language when the corpus language is known:

```crystal
embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_avgdl(256.0_f32, Bm25::U32Embedder.new)
  .language_mode(Bm25.fixed(Bm25::Language::German))
  .build
```

Use detection when input can be English or German:

```crystal
tokenizer = Bm25::DefaultTokenizer.new(Bm25.detect)
tokens = tokenizer.tokenize("Slices of pizza")
```

`Bm25.detect` is implemented locally with an English/German stopword heuristic to satisfy current upstream parity tests. It is not a general replacement for upstream Rust's optional `whichlang` integration.

## Tokenizer

The default tokenizer normalizes unicode, lowercases text, splits on word-like boundaries, removes stopwords, and stems tokens.

```crystal
tokenizer = Bm25::DefaultTokenizer.builder
  .language_mode(Bm25::Language::English)
  .normalization(true)
  .stopwords(true)
  .stemming(true)
  .build

tokenizer.tokenize("Slices of 🍕") # => ["slice", "pizza"]
```

Provide a custom tokenizer by subclassing `Bm25::Tokenizer`:

```crystal
class SplitOnTTokenizer < Bm25::Tokenizer
  def tokenize(input_text : String) : Array(String)
    input_text.split("T").reject(&.empty?)
  end
end

embedder = Bm25::EmbedderBuilder(UInt32, SplitOnTTokenizer)
  .with_avgdl(1.0_f32, Bm25::U32Embedder.new)
  .tokenizer(SplitOnTTokenizer.new)
  .build

embedder.embed("CupTofTtea").indices
```

## Embedding Space

The embedding index type is the `D` type parameter. Use the built-in fxhash-compatible embedders for `UInt32` or `UInt64`:

```crystal
u32_embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_avgdl(2.0_f32, Bm25::U32Embedder.new)
  .build

u64_embedder = Bm25::EmbedderBuilder(UInt64, Bm25::DefaultTokenizer)
  .with_avgdl(2.0_f32, Bm25::U64Embedder.new)
  .build
```

Use a custom embedding space by implementing `Bm25::TokenEmbedder(D)`:

```crystal
struct ConstantEmbedder
  include Bm25::TokenEmbedder(String)

  def embed(token : String) : String
    "constant"
  end
end

embedder = Bm25::EmbedderBuilder(String, Bm25::DefaultTokenizer)
  .with_avgdl(2.0_f32, ConstantEmbedder.new)
  .build
```

## Score

Use `Scorer` directly when you want BM25 scoring but own document storage yourself:

```crystal
corpus = [
  "The sky blushed pink as the sun dipped below the horizon.",
  "She found a forgotten letter tucked inside an old book.",
  "Apples, oranges, pink grapefruits, and more pink grapefruits.",
  "A single drop of rain fell, followed by a thousand more.",
]

embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
  .with_fit_to_corpus(Bm25::Language::English, corpus, Bm25::U32Embedder.new)
  .build

scorer = Bm25::Scorer(UInt32, UInt32).new

corpus.each_with_index do |document, index|
  scorer.upsert(index.to_u32, embedder.embed(document))
end

query_embedding = embedder.embed("pink")
matches = scorer.matches(query_embedding)
score = scorer.score(0_u32, query_embedding)
```

## Search

Use `SearchEngine` for document storage plus search:

```crystal
corpus = [
  "The rabbit munched the orange carrot.",
  "The snake hugged the green lizard.",
  "The hedgehog impaled the orange orange.",
  "The squirrel buried the brown nut.",
]

engine = Bm25::SearchEngineBuilder(UInt32, UInt32, Bm25::DefaultTokenizer)
  .with_corpus(Bm25::Language::English, corpus, Bm25::U32Embedder.new)
  .build

results = engine.search("orange", 3)
```

Build with custom document IDs:

```crystal
documents = [
  Bm25::Document(String).new("Guacamole", "avocado, lime juice, salt, onion, tomatoes, coriander."),
  Bm25::Document(String).new("Hummus", "chickpeas, tahini, olive oil, garlic, lemon juice, salt."),
]

engine = Bm25::SearchEngineBuilder(String, UInt32, Bm25::DefaultTokenizer)
  .with_documents(Bm25::Language::English, documents, Bm25::U32Embedder.new)
  .build
```

Mutate an existing engine:

```crystal
engine = Bm25::SearchEngineBuilder(UInt32, UInt32, Bm25::DefaultTokenizer)
  .with_avgdl(10.0_f32, Bm25::U32Embedder.new)
  .language_mode(Bm25::Language::English)
  .build

document = Bm25::Document(UInt32).new(42_u32, "A breeze carried jasmine through the open window.")

engine.upsert(document)
engine.get(42_u32)
engine.remove(42_u32)
```

Changing the corpus after build time changes the true average document length. If many documents are added or removed, rebuild or choose an `avgdl` that reflects the expected corpus.

## Development

Run the main gates:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

Run the ported upstream search benchmark:

```bash
crystal run benchmarks/search.cr
```

More details live in [Development](docs/development.md), [Testing](docs/testing.md), and [Architecture](docs/architecture.md).

## License

[MIT](LICENSE)
