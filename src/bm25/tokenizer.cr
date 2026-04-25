module Bm25
  abstract class Tokenizer
    abstract def tokenize(input_text : String) : Array(String)
  end
end
