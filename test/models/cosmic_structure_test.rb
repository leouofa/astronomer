# frozen_string_literal: true

require "test_helper"

class CosmicStructureTest < ActiveSupport::TestCase
  test "validates presence of name and description" do
    cosmic_structure = CosmicStructure.new(name: " ", description: " ")
    assert_not cosmic_structure.valid?
    assert_includes cosmic_structure.errors[:name], "can't be blank"
    assert_includes cosmic_structure.errors[:description], "can't be blank"
  end

  test "normalizes name whitespace and enforces case-insensitive uniqueness" do
    first = CosmicStructure.create!(name: "  North   America ", description: "Northern cosmic_structure.")
    assert_equal "North America", first.name

    duplicate = CosmicStructure.new(name: "north america", description: "Duplicate.")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end



  test "upsert_batch! inserts new cosmic_structures and updates existing ones case-insensitively" do
    CosmicStructure.create!(name: "Europe", description: "Old description")

    results = CosmicStructure.upsert_batch!([
      { "name" => "  europe ", "description" => "Updated European cosmic_structure." },
      { "name" => "Asia", "description" => "Largest world cosmic_structure." },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Africa", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, CosmicStructure.count

    europe = CosmicStructure.find_by!("LOWER(name) = ?", "europe")
    assert_equal "europe", europe.name
    assert_equal "Updated European cosmic_structure.", europe.description

    asia = CosmicStructure.find_by!(name: "Asia")
    assert_equal "Largest world cosmic_structure.", asia.description
  end
end
