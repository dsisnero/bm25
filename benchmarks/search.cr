require "benchmark"
require "csv"
require "../src/bm25"

record Recipe, title : String, recipe : String

record BenchmarkRecipe, recipe : Recipe do
  def to_document : Bm25::Document(String)
    Bm25::Document(String).new(recipe.title, recipe.recipe)
  end
end

def read_recipes(recipe_file_name : String) : Array(Recipe)
  CSV.parse(File.read("vendor/bm25/data/#{recipe_file_name}"))[1..].map do |row|
    Recipe.new(row[0], row[1])
  end
end

def create_recipe_search_engine(language_mode : Bm25::LanguageMode) : Bm25::SearchEngine(String, UInt32, Bm25::DefaultTokenizer)
  recipes = read_recipes("recipes_en.csv").map { |recipe| BenchmarkRecipe.new(recipe).to_document }

  Bm25::SearchEngineBuilder(String, UInt32, Bm25::DefaultTokenizer)
    .with_documents(language_mode, recipes, Bm25::U32Embedder.new)
    .build
end

def bench_recipes_index_creation(language_mode : Bm25::LanguageMode) : Nil
  recipes = read_recipes("recipes_en.csv").map { |recipe| BenchmarkRecipe.new(recipe) }
  corpus = recipes.map { |recipe| recipe.recipe.recipe }
  avgdl = Bm25::EmbedderBuilder(UInt32, Bm25::DefaultTokenizer)
    .with_fit_to_corpus(language_mode, corpus, Bm25::U32Embedder.new)
    .build
    .avgdl

  engine = Bm25::SearchEngineBuilder(String, UInt32, Bm25::DefaultTokenizer)
    .with_avgdl(avgdl, Bm25::U32Embedder.new)
    .language_mode(language_mode)
    .build

  recipes.each { |recipe| engine.upsert(recipe.to_document) }
end

def bench_search(language_mode : Bm25::LanguageMode) : Nil
  search_engine = create_recipe_search_engine(language_mode)
  search_engine.search("bacon sandwich", 20)
end

language_modes = {
  "detect"  => Bm25.detect,
  "english" => Bm25.fixed(Bm25::Language::English),
}

Benchmark.bm do |x|
  language_modes.each do |name, language_mode|
    x.report("recipes_index_creation_language_mode/#{name}") do
      bench_recipes_index_creation(language_mode)
    end

    x.report("search_language_mode/#{name}") do
      bench_search(language_mode)
    end
  end
end
