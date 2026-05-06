require "./spec_helper"
require "./support/recipe_loader"
require "yaml"

def tokenizer_snapshot_tokens(snapshot_file : String) : Array(Array(String))
  body = File.read("vendor/bm25/snapshots/#{snapshot_file}").split("---", 3)[2]
  YAML.parse(body).as_a.map { |row| row.as_a.map(&.as_s) }
end

def tokenize_recipe_methods(recipe_file : String, language_mode : Bm25::LanguageMode) : Array(Array(String))
  tokenizer = Bm25::DefaultTokenizer.new(language_mode)
  Bm25SpecData.read_recipes(recipe_file).map do |recipe|
    tokenizer.tokenize(recipe.recipe)
  end
end

def tokenize_recipe_methods(recipe_file : String, language : Bm25::Language) : Array(Array(String))
  tokenize_recipe_methods(recipe_file, Bm25.fixed(language))
end

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
    tok.tokenize("i me my myself we our ours ourselves can just will").should be_empty
  end

  it "keeps numbers" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("42 1337 3.14").should eq(["42", "1337", "3.14"])
  end

  it "removes sentence-final periods without breaking decimals" do
    tok = Bm25::DefaultTokenizer.new(stemming: false)
    tok.tokenize("one dish. Heat to 3.14.").should eq(["one", "dish", "heat", "3.14"])
  end

  it "keeps contracted words when stemming and stopwords disabled" do
    tok = Bm25::DefaultTokenizer.new(stemming: false, stopwords: false)
    tok.tokenize("can't you're won't let's couldn't've").should eq(["can't", "you're", "won't", "let's", "couldn't've"])
  end

  it "removes punctuation" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("space, station!").should eq(["space", "station"])
    tok.tokenize("space,station").should eq(["space", "station"])
    tok.tokenize("day-old").should eq(["day", "old"])
    tok.tokenize("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~").should eq([] of String)
  end

  it "stems words" do
    tok = Bm25::DefaultTokenizer.new
    tokens = tok.tokenize("connection connections connective connected connecting connect")
    tokens.each { |t| t.should eq("connect") }
  end

  it "applies Porter2 step 4 suffix removal" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("together relational").should eq(["togeth", "relat"])
  end

  it "preserves short words under Porter2 step 5" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("one").should eq(["one"])
  end

  it "does not treat final w x or Y as short-syllable endings" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("mixing").should eq(["mix"])
  end

  it "applies Porter2 step 1b replacements" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("coated dressing chopped troubling sizing").should eq(["coat", "dress", "chop", "troubl", "size"])
  end

  it "applies Porter2 step 2 li deletion" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("evenly thinly").should eq(["even", "thin"])
  end

  it "applies Porter2 exceptional forms" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("bubbly gently").should eq(["bubbl", "gentl"])
  end

  it "applies Porter2 special R1 prefixes" do
    tok = Bm25::DefaultTokenizer.new(stopwords: false)
    tok.tokenize("generously").should eq(["generous"])
  end

  it "tokenizes emojis as text" do
    tok = Bm25::DefaultTokenizer.new
    tok.tokenize("🍕 🚀 🍋").should eq(["pizza", "rocket", "lemon"])
  end

  it "converts unicode to ascii" do
    tok = Bm25::DefaultTokenizer.new(stemming: false)
    tok.tokenize("gemüse, Gießen").should eq(["gemuse", "giessen"])
  end

  it "normalizes degree symbols like deunicode" do
    tok = Bm25::DefaultTokenizer.new(stemming: false)
    tok.tokenize("400°F 200°C").should eq(["400degf", "200degc"])
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

  it "handles empty input with language detection" do
    tok = Bm25::DefaultTokenizer.new(Bm25.detect)
    tok.tokenize("").should be_empty
  end

  it "works with builder pattern" do
    tok = Bm25::DefaultTokenizer.builder
      .stemming(false)
      .stopwords(false)
      .build
    tok.tokenize("can't you're won't let's").should eq(["can't", "you're", "won't", "let's"])
  end

  it "accepts a fixed language mode in the builder" do
    tok = Bm25::DefaultTokenizer.builder
      .language_mode(Bm25.fixed(Bm25::Language::German))
      .stemming(false)
      .build

    tok.tokenize("gemüse, Gießen").should eq(["gemuse", "giessen"])
  end

  it "matches the upstream English recipe snapshot" do
    tokens = tokenize_recipe_methods("recipes_en.csv", Bm25::Language::English)
    snapshot = tokenizer_snapshot_tokens("bm25__default_tokenizer__tests__it_matches_snapshot_en.snap")

    tokens.should eq(snapshot)
  end

  it "matches the upstream German recipe snapshot" do
    tokens = tokenize_recipe_methods("recipes_de.csv", Bm25::Language::German)
    snapshot = tokenizer_snapshot_tokens("bm25__default_tokenizer__tests__it_matches_snapshot_de.snap")

    tokens.should eq(snapshot)
  end

  it "detects English recipes like upstream" do
    tokens_detected = tokenize_recipe_methods("recipes_en.csv", Bm25.detect)
    tokens_en = tokenize_recipe_methods("recipes_en.csv", Bm25::Language::English)

    tokens_detected.should eq(tokens_en)
  end

  it "detects German recipes like upstream" do
    tokens_detected = tokenize_recipe_methods("recipes_de.csv", Bm25.detect)
    tokens_de = tokenize_recipe_methods("recipes_de.csv", Bm25::Language::German)

    tokens_detected.should eq(tokens_de)
  end
end
