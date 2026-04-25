module Bm25
  struct Document(K)
    getter id : K
    getter contents : String

    def initialize(@id : K, @contents : String)
    end

    def to_s(io : IO) : Nil
      io << @contents
    end
  end

  struct SearchResult(K)
    getter document : Document(K)
    getter score : Float32

    def initialize(@document : Document(K), @score : Float32)
    end
  end

  class SearchEngine(K, D, T)
    def initialize(@embedder : Embedder(D, T))
      @scorer = Scorer(K, D).new
      @documents = Hash(K, String).new
    end

    def upsert(document : Document(K)) : Nil
      embedding = @embedder.embed(document.contents)

      if @documents.has_key?(document.id)
        remove(document.id)
      end
      @documents[document.id] = document.contents
      @scorer.upsert(document.id, embedding)
    end

    def remove(document_id : K) : Nil
      @documents.delete(document_id)
      @scorer.remove(document_id)
    end

    def get(document_id : K) : Document(K)?
      if contents = @documents[document_id]?
        Document(K).new(document_id, contents)
      end
    end

    def each(& : Document(K) ->)
      @documents.each do |id, contents|
        yield Document(K).new(id, contents)
      end
    end

    def search(query : String, limit : Int32? = nil) : Array(SearchResult(K))
      query_embedding = @embedder.embed(query)
      matches = @scorer.matches(query_embedding)

      limit = limit || Int32::MAX
      results = [] of SearchResult(K)
      matches.each do |match|
        break if results.size >= limit
        if doc = get(match.id)
          results << SearchResult(K).new(doc, match.score)
        end
      end
      results
    end

    def avgdl : Float32
      @embedder.avgdl
    end

    def k1 : Float32
      @embedder.k1
    end

    def b : Float32
      @embedder.b
    end
  end

  class SearchEngineBuilder(K, D, T)
    def initialize(@embedder_builder : EmbedderBuilder(D, T)? = nil, @documents : Array(Document(K)) = [] of Document(K))
    end

    def self.with_avgdl(avgdl : Float32, token_embedder : TokenEmbedder(D)) : self
      eb = EmbedderBuilder(D, T).with_avgdl(avgdl, token_embedder)
      new(embedder_builder: eb)
    end

    def self.with_tokenizer_and_documents(tokenizer : T, documents : Array(Document(K)), token_embedder : TokenEmbedder(D)) : self
      contents = documents.map(&.contents)
      eb = EmbedderBuilder(D, T).with_tokenizer_and_fit_to_corpus(tokenizer, contents, token_embedder)
      new(embedder_builder: eb, documents: documents)
    end

    def self.with_tokenizer_and_corpus(tokenizer : T, corpus : Array(String), token_embedder : TokenEmbedder(D)) : self
      eb = EmbedderBuilder(D, T).with_tokenizer_and_fit_to_corpus(tokenizer, corpus, token_embedder)
      new(embedder_builder: eb)
    end

    def self.with_documents(language_mode : LanguageMode, documents : Array(Document(K)), token_embedder : TokenEmbedder(D)) : self
      contents = documents.map(&.contents)
      eb = EmbedderBuilder(D, T).with_fit_to_corpus(language_mode, contents, token_embedder)
      new(embedder_builder: eb, documents: documents)
    end

    def self.with_corpus(language_mode : LanguageMode, corpus : Array(String), token_embedder : TokenEmbedder(D)) : self
      eb = EmbedderBuilder(D, T).with_fit_to_corpus(language_mode, corpus, token_embedder)
      new(embedder_builder: eb)
    end

    def k1(v : Float32) : self
      @embedder_builder.try(&.k1(v))
      self
    end

    def b(v : Float32) : self
      @embedder_builder.try(&.b(v))
      self
    end

    def avgdl(v : Float32) : self
      @embedder_builder.try(&.avgdl(v))
      self
    end

    def tokenizer(v : T) : self
      @embedder_builder.try(&.tokenizer(v))
      self
    end

    def token_embedder(v : TokenEmbedder(D)) : self
      @embedder_builder.try(&.token_embedder(v))
      self
    end

    def language_mode(mode : LanguageMode) : self
      @embedder_builder.try(&.language_mode(mode))
      self
    end

    def build : SearchEngine(K, D, T)
      embedder = @embedder_builder.try(&.build).not_nil!
      engine = SearchEngine(K, D, T).new(embedder)
      @documents.each { |doc| engine.upsert(doc) }
      engine
    end
  end
end
