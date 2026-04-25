require "./spec_helper"

class WhitespaceTokenizer < Bm25::Tokenizer
  def tokenize(input_text : String) : Array(String)
    input_text.split(' ').reject(&.empty?)
  end
end

struct CustomEmbedder
  include Bm25::TokenEmbedder(String)

  def embed(token : String) : String
    token
  end
end

describe Bm25 do
  describe Bm25::Embedder do
    it "allows custom token embedder" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(String, WhitespaceTokenizer).new(tokenizer, CustomEmbedder.new, 1.2, 0.75, 3.0)
      embedding = embedder.embed("hello world")

      embedding.indices.should eq(["hello", "world"])
      embedding.values.each { |v| (v > 0.0).should be_true }
    end

    it "weights unique words equally" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, 1.2, 0.75, 3.0)
      embedding = embedder.embed("banana apple orange")

      embedding.size.should eq(3)
      embedding.tokens.each_cons(2) do |pair|
        pair[0].value.should eq(pair[1].value)
      end
    end

    it "weights repeated words unequally" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, 1.2, 0.75, 3.0)
      embedding = embedder.embed("space station station")

      embedding.values.should eq([1.0, 1.375, 1.375])
    end

    it "handles empty input" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new)
      embedding = embedder.embed("")

      embedding.should be_empty
    end

    it "returns avgdl" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, 1.2, 0.75, 5.75)
      embedder.avgdl.should eq(5.75)
    end
  end

  describe Bm25::Scorer do
    it "scores missing document as nil" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      query = Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(1_u32, 1.0)])

      score = scorer.score(0_u32, query)
      score.should be_nil
    end

    it "scores mutually exclusive indices as zero" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      doc = Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(1_u32, 1.0)])
      scorer.upsert(0_u32, doc)

      query = Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])
      score = scorer.score(0_u32, query)
      score.should eq(0.0)
    end

    it "scores rare indices higher than common ones" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      scorer.upsert(0_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)]))
      scorer.upsert(1_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)]))
      scorer.upsert(2_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(1_u32, 1.0)]))

      score_common = scorer.score(0_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])).not_nil!
      score_rare = scorer.score(2_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(1_u32, 1.0)])).not_nil!

      (score_common < score_rare).should be_true
    end

    it "scores longer embeddings lower than shorter ones" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      scorer.upsert(0_u32, Bm25::Embedding(UInt32).new([
        Bm25::TokenEmbedding(UInt32).new(0_u32, 0.9),
        Bm25::TokenEmbedding(UInt32).new(1_u32, 0.9),
      ]))
      scorer.upsert(1_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)]))

      score_long = scorer.score(0_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])).not_nil!
      score_short = scorer.score(1_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])).not_nil!

      (score_long < score_short).should be_true
    end

    it "only matches embeddings with non-zero score" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      scorer.upsert(0_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)]))
      scorer.upsert(1_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(1_u32, 1.0)]))

      query = Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])
      matches = scorer.matches(query)

      matches.size.should eq(1)
      matches[0].id.should eq(0_u32)
    end

    it "does not score frequent terms negatively" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      scorer.upsert(0_u32, Bm25::Embedding(UInt32).new([
        Bm25::TokenEmbedding(UInt32).new(0_u32, 1.5),
        Bm25::TokenEmbedding(UInt32).new(0_u32, 1.5),
      ]))

      query = Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])
      matches = scorer.matches(query)

      (matches[0].score >= 0.0).should be_true
    end

    it "sorts matches by score" do
      scorer = Bm25::Scorer(UInt32, UInt32).new
      scorer.upsert(0_u32, Bm25::Embedding(UInt32).new([
        Bm25::TokenEmbedding(UInt32).new(0_u32, 0.9),
        Bm25::TokenEmbedding(UInt32).new(1_u32, 0.9),
      ]))
      scorer.upsert(1_u32, Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)]))

      query = Bm25::Embedding(UInt32).new([Bm25::TokenEmbedding(UInt32).new(0_u32, 1.0)])
      matches = scorer.matches(query)

      matches.each_cons(2) do |pair|
        (pair[0].score >= pair[1].score).should be_true
      end
    end
  end

  describe Bm25::SearchEngine do
    it "searches and returns relevant documents" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      engine.upsert(Bm25::Document(UInt32).new(0_u32, "space station"))
      engine.upsert(Bm25::Document(UInt32).new(1_u32, "bacon and avocado sandwich"))

      results = engine.search("sandwich with bacon", 5)
      results.size.should eq(1)
      results[0].document.contents.should eq("bacon and avocado sandwich")
      (results[0].score > 0.0).should be_true
    end

    it "does not return unrelated documents" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      engine.upsert(Bm25::Document(UInt32).new(0_u32, "space station"))
      engine.upsert(Bm25::Document(UInt32).new(1_u32, "bacon avocado sandwich"))

      results = engine.search("mathematics computer programming", 5)
      results.should be_empty
    end

    it "can insert a document" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, avgdl: 2.0)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      doc = Bm25::Document(UInt32).new(42_u32, "bananas and apples")
      doc_id = doc.id
      engine.upsert(doc)

      result = engine.get(doc_id)
      result.should_not be_nil
      result.not_nil!.contents.should eq("bananas and apples")
    end

    it "can remove a document" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, avgdl: 2.0)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      doc = Bm25::Document(UInt32).new(123_u32, "bananas and apples")
      doc_id = doc.id
      engine.upsert(doc)
      engine.remove(doc_id)

      engine.get(doc_id).should be_nil
    end

    it "handles empty input" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, avgdl: 2.0)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      engine.upsert(Bm25::Document(UInt32).new(123_u32, ""))
      results = engine.search("bacon sandwich", 5)
      results.should be_empty
    end

    it "handles empty search" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, avgdl: 2.0)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      engine.upsert(Bm25::Document(UInt32).new(123_u32, "pencil and paper"))
      results = engine.search("", 5)
      results.should be_empty
    end

    it "ranks shorter documents higher" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, avgdl: 3.0)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      engine.upsert(Bm25::Document(UInt32).new(0_u32, "Correct horse battery staple bacon bacon bacon"))
      engine.upsert(Bm25::Document(UInt32).new(1_u32, "Correct horse battery staple"))

      results = engine.search("staple", 2)
      results.size.should eq(2)
      results[0].document.id.should eq(1_u32)
      results[1].document.id.should eq(0_u32)
      (results[0].score > results[1].score).should be_true
    end

    it "returns exact matches with highest score" do
      tokenizer = WhitespaceTokenizer.new
      embedder = Bm25::Embedder(UInt32, WhitespaceTokenizer).new(tokenizer, Bm25::U32Embedder.new, avgdl: 3.0)
      engine = Bm25::SearchEngine(UInt32, UInt32, WhitespaceTokenizer).new(embedder)

      engine.upsert(Bm25::Document(UInt32).new(0_u32, "space station"))
      engine.upsert(Bm25::Document(UInt32).new(1_u32, "bacon and avocado sandwich"))

      results = engine.search("bacon", 5)
      results.size.should eq(1)
      results[0].document.id.should eq(1_u32)
    end

    it "builds with custom token embedder via builder" do
      tokenizer = WhitespaceTokenizer.new
      builder = Bm25::SearchEngineBuilder(String, String, WhitespaceTokenizer).with_avgdl(3.0, CustomEmbedder.new)
      builder.tokenizer(tokenizer)
      engine = builder.build

      engine.upsert(Bm25::Document(String).new("a", "hello world"))

      results = engine.search("hello", 5)
      results.size.should eq(1)
      results[0].document.id.should eq("a")
    end

    it "returns document contents via to_s" do
      doc = Bm25::Document(String).new("id1", "hello world")
      doc.to_s.should eq("hello world")
    end
  end
end
