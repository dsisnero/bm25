module Bm25
  struct TokenEmbedding(D)
    getter index : D
    getter value : Float32

    def initialize(@index : D, @value : Float32)
    end
  end

  struct Embedding(D)
    getter tokens : Array(TokenEmbedding(D))

    def initialize(@tokens : Array(TokenEmbedding(D)))
    end

    def each(& : TokenEmbedding(D) ->)
      @tokens.each { |tok| yield tok }
    end

    def indices : Array(D)
      @tokens.map(&.index)
    end

    def values : Array(Float32)
      @tokens.map(&.value)
    end

    def size
      @tokens.size
    end

    def empty?
      @tokens.empty?
    end

    def [](index : Int)
      @tokens[index]
    end

    def each_value(& : Float32 ->)
      @tokens.each { |tok| yield tok.value }
    end

    def each_index(& : D ->)
      @tokens.each { |tok| yield tok.index }
    end

    def method_missing(called : String, *args, **options)
      @tokens.send(called, *args, **options)
    end
  end

  module TokenEmbedder(D)
    abstract def embed(token : String) : D
  end

  struct U32Embedder
    include TokenEmbedder(UInt32)

    def embed(token : String) : UInt32
      Bm25.hash32(token)
    end
  end

  struct U64Embedder
    include TokenEmbedder(UInt64)

    def embed(token : String) : UInt64
      Bm25.hash64(token)
    end
  end

  private K64 = 0xf1357aea2e62a9c5_u64

  def self.hash32(token : String) : UInt32
    hash_bytes(token).to_u32!
  end

  def self.hash64(token : String) : UInt64
    hash_bytes(token)
  end

  private def self.hash_bytes(bytes : String) : UInt64
    data = bytes.to_slice
    len = data.size

    s0 = 0x243f6a8885a308d3_u64
    s1 = 0x13198a2e03707344_u64

    if len <= 16
      if len >= 8
        s0 ^= read_u64_le(data, 0)
        s1 ^= read_u64_le(data, len - 8)
      elsif len >= 4
        s0 ^= read_u32_le(data, 0).to_u64
        s1 ^= read_u32_le(data, len - 4).to_u64
      elsif len > 0
        lo = data[0].to_u64
        mid = data[len // 2].to_u64
        hi = data[len - 1].to_u64
        s0 ^= lo
        s1 ^= (hi << 8) | mid
      end
    else
      bulk_end = len - 1
      pos = 0
      while pos + 16 <= bulk_end
        x = read_u64_le(data, pos)
        y = read_u64_le(data, pos + 8)
        t = multiply_mix(s0 ^ x, 0xa4093822299f31d0_u64 ^ y)
        s0 = s1
        s1 = t
        pos += 16
      end

      suffix_start = len - 16
      s0 ^= read_u64_le(data, suffix_start)
      s1 ^= read_u64_le(data, suffix_start + 8)
    end

    multiply_mix(s0, s1) ^ len.to_u64
  end

  private def self.read_u64_le(data : Slice(UInt8), offset : Int) : UInt64
    data[offset].to_u64 |
      (data[offset + 1].to_u64 << 8) |
      (data[offset + 2].to_u64 << 16) |
      (data[offset + 3].to_u64 << 24) |
      (data[offset + 4].to_u64 << 32) |
      (data[offset + 5].to_u64 << 40) |
      (data[offset + 6].to_u64 << 48) |
      (data[offset + 7].to_u64 << 56)
  end

  private def self.read_u32_le(data : Slice(UInt8), offset : Int) : UInt32
    data[offset].to_u32 |
      (data[offset + 1].to_u32 << 8) |
      (data[offset + 2].to_u32 << 16) |
      (data[offset + 3].to_u32 << 24)
  end

  private def self.multiply_mix(x : UInt64, y : UInt64) : UInt64
    lx = x & 0xFFFF_FFFF
    ly = y & 0xFFFF_FFFF
    hx = (x >> 32) & 0xFFFF_FFFF
    hy = (y >> 32) & 0xFFFF_FFFF

    afull = lx &* hy
    bfull = hx &* ly

    afull ^ bfull.rotate_right(32)
  end

  class Embedder(D, T)
    FALLBACK_AVGDL = 256.0_f32

    getter avgdl : Float32

    def initialize(@tokenizer : T, @token_embedder : TokenEmbedder(D), @k1 : Float32 = 1.2, @b : Float32 = 0.75, @avgdl : Float32 = FALLBACK_AVGDL)
    end

    def embed(text : String) : Embedding(D)
      tokens = @tokenizer.tokenize(text)
      avgdl = @avgdl <= 0 ? FALLBACK_AVGDL : @avgdl

      indices = tokens.map { |tok| @token_embedder.embed(tok) }
      counts = Hash(D, Int32).new(0)
      indices.each { |idx| counts[idx] += 1 }

      values = indices.map do |idx|
        token_frequency = counts[idx].to_f32
        numerator = token_frequency * (@k1 + 1.0)
        denominator = token_frequency + @k1 * (1.0 - @b + @b * (tokens.size.to_f32 / avgdl))
        numerator / denominator
      end

      token_embeddings = indices.zip(values).map { |idx, val| TokenEmbedding(D).new(idx, val) }
      Embedding(D).new(token_embeddings)
    end
  end

  class EmbedderBuilder(D, T)
    def initialize(@token_embedder : TokenEmbedder(D), @k1 : Float32 = 1.2, @b : Float32 = 0.75, @avgdl : Float32 = 256.0, @tokenizer : T? = nil)
    end

    def self.with_avgdl(avgdl : Float32, token_embedder : TokenEmbedder(D)) : self
      new(token_embedder, avgdl: avgdl)
    end

    def self.with_defaults(token_embedder : TokenEmbedder(D)) : self
      new(token_embedder)
    end

    def k1(k1 : Float32) : self
      @k1 = k1
      self
    end

    def b(b : Float32) : self
      @b = b
      self
    end

    def avgdl(avgdl : Float32) : self
      @avgdl = avgdl
      self
    end

    def tokenizer(tokenizer : T) : self
      @tokenizer = tokenizer
      self
    end

    def build : Embedder(D, T)
      tokenizer = @tokenizer || T.new
      Embedder(D, T).new(tokenizer, @token_embedder, @k1, @b, @avgdl)
    end
  end
end
