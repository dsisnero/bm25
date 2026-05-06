require "./spec_helper"
require "./support/recipe_loader"

class WhitespaceTokenizer < Bm25::Tokenizer
  def tokenize(input_text : String) : Array(String)
    input_text.split(' ').reject(&.empty?)
  end
end

class SplitOnTTokenizer < Bm25::Tokenizer
  def tokenize(input_text : String) : Array(String)
    input_text.split("T").reject(&.empty?)
  end
end

struct CustomEmbedder
  include Bm25::TokenEmbedder(String)

  def embed(token : String) : String
    token
  end
end

record SnapshotToken, index : UInt32, value : Float32
record SearchSnapshotResult, id : String, contents : String, score : Float32

def recipe_documents(recipe_file : String) : Array(Bm25::Document(String))
  Bm25SpecData.read_recipes(recipe_file).map do |recipe|
    Bm25::Document(String).new(recipe.title, recipe.recipe)
  end
end

def recipe_corpus(recipe_file : String) : Array(String)
  Bm25SpecData.read_recipes(recipe_file).map(&.recipe)
end

def recipe_search_engine(recipe_file : String, language : Bm25::Language) : Bm25::SearchEngine(String, UInt32, Bm25::DefaultTokenizer)
  Bm25::SearchEngineBuilder(String, UInt32, Bm25::DefaultTokenizer)
    .with_documents(language, recipe_documents(recipe_file), Bm25::U32Embedder.new)
    .build
end

def embedder_snapshot_embeddings(snapshot_file : String) : Array(Array(SnapshotToken))
  body = File.read("vendor/bm25/snapshots/#{snapshot_file}").split("---", 3)[2]
  embeddings = [] of Array(SnapshotToken)
  current = nil
  index = nil

  body.each_line do |line|
    if line.includes?("Embedding(")
      current = [] of SnapshotToken
    elsif match = line.match(/index: (\d+),/)
      index = match[1].to_u32
    elsif match = line.match(/value: ([0-9.]+),/)
      current.not_nil! << SnapshotToken.new(index.not_nil!, match[1].to_f32)
    elsif line.strip == "),"
      embeddings << current.not_nil!
      current = nil
    end
  end

  embeddings
end

def assert_embedding_snapshot(actual : Array(Bm25::Embedding(UInt32)), expected : Array(Array(SnapshotToken))) : Nil
  actual.size.should eq(expected.size)
  actual.zip(expected).each do |actual_embedding, expected_embedding|
    actual_embedding.size.should eq(expected_embedding.size)
    actual_embedding.tokens.zip(expected_embedding).each do |actual_token, expected_token|
      actual_token.index.should eq(expected_token.index)
      (actual_token.value - expected_token.value).abs.should be <= 0.00001_f32
    end
  end
end

def search_snapshot_results(snapshot_file : String) : Array(SearchSnapshotResult)
  body = File.read("vendor/bm25/snapshots/#{snapshot_file}").split("---", 3)[2]
  results = [] of SearchSnapshotResult
  id = nil
  contents = nil

  body.each_line do |line|
    if match = line.match(/id: "(.*)",/)
      id = match[1]
    elsif match = line.match(/contents: "(.*)",/)
      contents = match[1]
    elsif match = line.match(/score: ([0-9.]+),/)
      results << SearchSnapshotResult.new(id.not_nil!, contents.not_nil!, match[1].to_f32)
    end
  end

  results
end

def assert_search_snapshot(actual : Array(Bm25::SearchResult(String)), expected : Array(SearchSnapshotResult)) : Nil
  actual.size.should eq(expected.size)
  actual.zip(expected).each do |actual_result, expected_result|
    actual_result.document.id.should eq(expected_result.id)
    actual_result.document.contents.should eq(expected_result.contents)
    (actual_result.score - expected_result.score).abs.should be <= 0.00001_f32
  end
end

describe Bm25 do
  describe Bm25::Embedder do
    it "exposes NoDefaultTokenizer as a sentinel type" do
      tokenizer = Bm25::NoDefaultTokenizer.new

      expect_raises(Exception, "NoDefaultTokenizer is a sentinel") do
        tokenizer.tokenize("anything")
      end
    end

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

    it "matches the upstream English recipe snapshot" do
      corpus = recipe_corpus("recipes_en.csv")
      embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
        .with_fit_to_corpus(Bm25::Language::English, corpus, Bm25::U32Embedder.new)
        .build

      embeddings = corpus.map { |document| embedder.embed(document) }
      snapshot = embedder_snapshot_embeddings("bm25__embedder__tests__it_matches_snapshot_en.snap")

      assert_embedding_snapshot(embeddings, snapshot)
    end

    it "matches the upstream German recipe snapshot" do
      corpus = recipe_corpus("recipes_de.csv")
      embedder = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
        .with_fit_to_corpus(Bm25::Language::German, corpus, Bm25::U32Embedder.new)
        .build

      embeddings = corpus.map { |document| embedder.embed(document) }
      snapshot = embedder_snapshot_embeddings("bm25__embedder__tests__it_matches_snapshot_de.snap")

      assert_embedding_snapshot(embeddings, snapshot)
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

  describe Bm25::Embedding do
    it "creates via any factory" do
      emb = Bm25::Embedding(UInt32).any
      emb.size.should eq(1)
      emb[0].index.should eq(1_u32)
      emb[0].value.should eq(1.0_f32)
    end
  end

  describe Bm25::EmbedderBuilder do
    it "fits avgdl to corpus" do
      tokenizer = WhitespaceTokenizer.new
      corpus = ["hello world", "foo bar baz"]
      builder = Bm25::EmbedderBuilder(UInt32, WhitespaceTokenizer).with_tokenizer_and_fit_to_corpus(tokenizer, corpus, Bm25::U32Embedder.new)
      embedder = builder.build
      embedder.avgdl.should eq(2.5_f32)
    end

    it "fits avgdl to empty corpus" do
      builder = Bm25::EmbedderBuilder(UInt32, WhitespaceTokenizer).with_tokenizer_and_fit_to_corpus(WhitespaceTokenizer.new, [] of String, Bm25::U32Embedder.new)
      embedder = builder.build
      embedder.avgdl.should eq(256.0_f32)
    end

    it "allows customisation of tokenizer" do
      embedder = Bm25::EmbedderBuilder(UInt32, SplitOnTTokenizer)
        .with_avgdl(1.0_f32, Bm25::U32Embedder.new)
        .build

      embedding = embedder.embed("CupTofTtea")

      embedding.indices.should eq([3568447556_u32, 3221979461_u32, 415655421_u32])
    end
  end

  describe Bm25::SearchEngineBuilder do
    it "builds with documents" do
      docs = [
        Bm25::Document(String).new("a", "hello world"),
        Bm25::Document(String).new("b", "goodbye world"),
      ]
      builder = Bm25::SearchEngineBuilder(String, String, WhitespaceTokenizer).with_tokenizer_and_documents(WhitespaceTokenizer.new, docs, CustomEmbedder.new)
      engine = builder.build
      engine.get("a").should_not be_nil
      engine.get("b").should_not be_nil
    end

    it "builds with corpus" do
      corpus = ["hello world", "foo bar baz"]
      builder = Bm25::SearchEngineBuilder(UInt32, String, WhitespaceTokenizer).with_tokenizer_and_corpus(WhitespaceTokenizer.new, corpus, CustomEmbedder.new)
      engine = builder.build
      engine.avgdl.should eq(2.5_f32)
      engine.get(0_u32).should_not be_nil
      engine.get(1_u32).should_not be_nil
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

    it "can update a document" do
      document_id = "hello_world"
      document = Bm25::Document(String).new(document_id, "bananas and apples")
      engine = Bm25::SearchEngineBuilder(String, UInt32, Bm25::DefaultTokenizer)
        .with_documents(Bm25::Language::English, [document], Bm25::U32Embedder.new)
        .build
      new_document = Bm25::Document(String).new(document_id, "oranges and papayas")

      engine.upsert(new_document)
      result = engine.get(document_id)

      result.should eq(new_document)
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

    it "only returns results containing query" do
      engine = recipe_search_engine("recipes_en.csv", Bm25::Language::English)

      results = engine.search("vegetable", 5)

      results.size.should eq(5)
      results.all? { |result| result.document.contents.includes?("vegetable") }.should be_true
    end

    it "returns results sorted by score" do
      engine = recipe_search_engine("recipes_en.csv", Bm25::Language::English)

      results = engine.search("chicken", 1000)

      results.should_not be_empty
      results.each_cons(2) do |pair|
        (pair[0].score >= pair[1].score).should be_true
      end
    end

    it "matches the upstream English recipe search snapshot" do
      engine = recipe_search_engine("recipes_en.csv", Bm25::Language::English)
      results = engine.search("bake").sort_by { |result| result.document.id }
      snapshot = search_snapshot_results("bm25__search__tests__it_matches_snapshot_en.snap")

      assert_search_snapshot(results, snapshot)
    end

    it "matches the upstream German recipe search snapshot" do
      engine = recipe_search_engine("recipes_de.csv", Bm25::Language::German)
      results = engine.search("backen").sort_by { |result| result.document.id }
      snapshot = search_snapshot_results("bm25__search__tests__it_matches_snapshot_de.snap")

      assert_search_snapshot(results, snapshot)
    end

    it "matches common unicode equivalents with the default tokenizer" do
      engine = Bm25::SearchEngineBuilder(UInt32, UInt32, Bm25::DefaultTokenizer)
        .with_corpus(Bm25.fixed(Bm25::Language::French), ["étude"], Bm25::U32Embedder.new)
        .build

      results_1 = engine.search("etude")
      results_2 = engine.search("étude")

      results_1.size.should eq(1)
      results_2.size.should eq(1)
      results_1.should eq(results_2)
    end

    it "can search for emoji with the default tokenizer" do
      engine = Bm25::SearchEngineBuilder(UInt32, UInt32, Bm25::DefaultTokenizer)
        .with_corpus(Bm25.fixed(Bm25::Language::English), ["🔥"], Bm25::U32Embedder.new)
        .build

      results_1 = engine.search("🔥")
      results_2 = engine.search("fire")

      results_1.size.should eq(1)
      results_2.size.should eq(1)
      results_1.should eq(results_2)
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
