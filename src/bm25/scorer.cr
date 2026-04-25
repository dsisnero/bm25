module Bm25
  struct ScoredDocument(K)
    getter id : K
    getter score : Float32

    def initialize(@id : K, @score : Float32)
    end
  end

  class Scorer(K, D)
    def initialize
      @embeddings = Hash(K, Embedding(D)).new
      @inverted_token_index = Hash(D, Set(K)).new
    end

    def upsert(document_id : K, embedding : Embedding(D)) : Nil
      if @embeddings.has_key?(document_id)
        remove(document_id)
      end
      embedding.each_index do |token_index|
        @inverted_token_index[token_index] ||= Set(K).new
        @inverted_token_index[token_index] << document_id
      end
      @embeddings[document_id] = embedding
    end

    def remove(document_id : K) : Nil
      if embedding = @embeddings.delete(document_id)
        embedding.each_index do |token_index|
          if matches = @inverted_token_index[token_index]?
            matches.delete(document_id)
          end
        end
      end
    end

    def score(document_id : K, query_embedding : Embedding(D)) : Float32?
      document_embedding = @embeddings[document_id]?
      return unless document_embedding
      score_(document_embedding, query_embedding)
    end

    def matches(query_embedding : Embedding(D)) : Array(ScoredDocument(K))
      relevant_doc_ids = Set(K).new
      query_embedding.each_index do |token_index|
        if doc_set = @inverted_token_index[token_index]?
          doc_set.each { |doc_id| relevant_doc_ids << doc_id }
        end
      end

      scores = relevant_doc_ids.map do |doc_id|
        doc_embedding = @embeddings[doc_id]
        ScoredDocument(K).new(doc_id, score_(doc_embedding, query_embedding))
      end

      scores.sort! { |a, b| b.score <=> a.score }
      scores
    end

    private def idf(token_index : D) : Float32
      token_frequency = (@inverted_token_index[token_index]?.try(&.size) || 0).to_f32
      n_docs = @embeddings.size.to_f32
      numerator = n_docs - token_frequency + 0.5_f32
      denominator = token_frequency + 0.5_f32
      Math.log(1.0_f32 + numerator / denominator).to_f32
    end

    private def doc_value(document_embedding : Embedding(D), token_index : D) : Float32
      document_embedding.tokens.each do |tok_emb|
        return tok_emb.value if tok_emb.index == token_index
      end
      0.0_f32
    end

    private def score_(document_embedding : Embedding(D), query_embedding : Embedding(D)) : Float32
      document_score = 0.0_f32
      query_embedding.each_index do |token_index|
        document_score += idf(token_index) * doc_value(document_embedding, token_index)
      end
      document_score
    end
  end
end
