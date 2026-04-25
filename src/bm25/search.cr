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
  end

  class SearchEngineBuilder(K, D, T)
    def initialize(@embedder_builder : EmbedderBuilder(D, T)? = nil, @documents : Array(Document(K)) = [] of Document(K))
    end

    def self.with_avgdl(avgdl : Float32, token_embedder : TokenEmbedder(D)) : self
      eb = EmbedderBuilder(D, T).with_avgdl(avgdl, token_embedder)
      new(embedder_builder: eb)
    end

    def k1(v : Float32) : self
      if eb = @embedder_builder
        eb.k1(v)
      end
      self
    end

    def b(v : Float32) : self
      if eb = @embedder_builder
        eb.b(v)
      end
      self
    end

    def avgdl(v : Float32) : self
      if eb = @embedder_builder
        eb.avgdl(v)
      end
      self
    end

    def tokenizer(v : T) : self
      if eb = @embedder_builder
        eb.tokenizer(v)
      end
      self
    end

    def token_embedder(v : TokenEmbedder(D)) : self
      if eb = @embedder_builder
        eb.token_embedder(v)
      end
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
