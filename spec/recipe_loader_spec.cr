require "./spec_helper"
require "./support/recipe_loader"

describe Bm25SpecData do
  describe ".read_recipes" do
    it "raises if the file does not exist" do
      expect_raises(File::NotFoundError) do
        Bm25SpecData.read_recipes("non_existent_file.csv")
      end
    end

    it "reads recipes from a CSV file" do
      recipes = Bm25SpecData.read_recipes("recipes_en.csv")

      recipes.size.should eq(50)
      recipes[0].title.should eq("French Toast")
    end
  end
end
