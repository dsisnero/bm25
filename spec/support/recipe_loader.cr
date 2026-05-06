require "csv"

module Bm25SpecData
  record Recipe, title : String, recipe : String

  def self.read_recipes(recipe_file_name : String) : Array(Recipe)
    CSV.parse(File.read("vendor/bm25/data/#{recipe_file_name}"))[1..].map do |row|
      Recipe.new(row[0], row[1])
    end
  end
end
