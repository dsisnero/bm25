require "./spec_helper"

describe Bm25::DefaultTokenizer do
  it "tokenizes english text" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("space station").should eq(["space", "station"])
  end

  it "converts to lowercase" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("SPACE STATION").should eq(["space", "station"])
  end

  it "removes whitespace" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("\tspace\r\nstation\n space       station").should eq(["space", "station", "space", "station"])
  end

  it "removes stopwords" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("i me my myself we our ours ourselves").should be_empty
  end

  it "keeps numbers" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("42 1337 3.14").should eq(["42", "1337", "3.14"])
  end

  it "keeps contracted words when stemming and stopwords disabled" do
    tok = Bm25::DefaultTokenizer.new(stemming: false, stopwords: false)
    tok.tokenize("can't you're won't let's couldn't've").should eq(["can't", "you're", "won't", "let's", "couldn't've"])
  end

  it "removes punctuation" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("space, station!").should eq(["space", "station"])
    tok.tokenize("space,station").should eq(["space", "station"])
    tok.tokenize("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~").should eq([] of String)
  end

  it "stems words" do
    tok = Bm25::DefaultTokenizer.new
    tokens = tok.tokenize("connection connections connective connected connecting connect")
    tokens.each { |t| t.should eq("connect") }
  end

  it "converts unicode to ascii" do
    tok = Bm25::DefaultTokenizer.new(stemming: false)
    tok.tokenize("gemüse, Gießen").should eq(["gemuse", "giessen"])
  end

  it "does not convert unicode when normalization disabled" do
    tok = Bm25::DefaultTokenizer.new(stemming: false, normalization: false)
    tok.tokenize("étude").should eq(["étude"])
  end

  it "does not remove stopwords when stopwords disabled" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("i my myself we you have").should eq(["i", "my", "myself", "we", "you", "have"])
  end

  it "does not stem when stemming disabled" do
    tok = Bm25::DefaultTokenizer.new(stemming: false)
    tok.tokenize("connection connections connective connect").should eq(["connection", "connections", "connective", "connect"])
  end

  it "handles empty input" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("").should be_empty
  end

  it "works with builder pattern" do
    tok = Bm25::DefaultTokenizer.builder
      .stemming(false)
      .stopwords(false)
      .build
    tok.tokenize("can't you're won't let's").should eq(["can't", "you're", "won't", "let's"])
  end
end
