# frozen_string_literal: true

require "test_helper"

class StarSystemTest < ActiveSupport::TestCase
  test "validates presence of name, description, and cosmic_structure" do
    star_system = StarSystem.new(name: " ", description: " ")
    assert_not star_system.valid?
    assert_includes star_system.errors[:cosmic_structure], "must exist"
    assert_includes star_system.errors[:name], "can't be blank"
    assert_includes star_system.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(
      cosmic_structure: cosmic_structure,
      name: "  France   Republic ",
      description: "  Western European state.  ",
      themes: [ " nuclear ", "Maritime", "NUCLEAR", "", nil ]
    )

    assert_equal "France Republic", star_system.name
    assert_equal "Western European state.", star_system.description
    assert_equal [ "nuclear", "Maritime" ], star_system.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    cosmic_structure = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")
    star_system = StarSystem.create!(
      cosmic_structure: cosmic_structure,
      name: "Japan",
      description: "East Asian island state.",
      themes: "island nation, industrial export, high tech, Island Nation"
    )

    assert_equal [ "island nation", "industrial export", "high tech" ], star_system.themes
  end

  test "enforces case-insensitive uniqueness scoped per cosmic_structure" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    africa = CosmicStructure.create!(name: "Africa", description: "African cosmic_structure.")

    StarSystem.create!(cosmic_structure: europe, name: "Georgia", description: "Transcaucasian state.")

    same_cosmic_structure_dup = StarSystem.new(cosmic_structure: europe, name: "georgia", description: "Duplicate.")
    assert_not same_cosmic_structure_dup.valid?
    assert_includes same_cosmic_structure_dup.errors[:name], "has already been taken"

    other_cosmic_structure_star_system = StarSystem.new(cosmic_structure: africa, name: "Georgia", description: "Different region.")
    assert other_cosmic_structure_star_system.valid?
  end

  test "upsert_batch! inserts new star_systems and updates existing ones within a cosmic_structure" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")

    StarSystem.create!(cosmic_structure: europe, name: "France", description: "Old description", themes: [ "republic" ])
    StarSystem.create!(cosmic_structure: asia, name: "France", description: "Unrelated namesake", themes: [ "test" ])

    results = StarSystem.upsert_batch!(europe, [
      { "name" => "  france ", "description" => "Fifth Republic.", "themes" => [ "republic", "nuclear power" ] },
      { "name" => "Germany", "description" => "Federal republic.", "themes" => [ "manufacturing", "export" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Italy", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, europe.star_systems.count
    assert_equal 1, asia.star_systems.count

    europe_france = europe.star_systems.find_by!("LOWER(name) = ?", "france")
    assert_equal "france", europe_france.name
    assert_equal "Fifth Republic.", europe_france.description
    assert_equal [ "republic", "nuclear power" ], europe_france.themes

    germany = europe.star_systems.find_by!(name: "Germany")
    assert_equal [ "manufacturing", "export" ], germany.themes
  end

  test "grouped_by_cosmic_structure returns cosmic_structure groups and star_systems sorted alphabetically" do
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    CosmicStructure.create!(name: "Africa", description: "Empty cosmic_structure.")

    StarSystem.create!(cosmic_structure: asia, name: "Japan", description: "East Asia.", themes: [ "island" ])
    StarSystem.create!(cosmic_structure: asia, name: "China", description: "East Asia.", themes: [ "manufacturing" ])
    StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.", themes: [ "republic" ])
    StarSystem.create!(cosmic_structure: europe, name: "Germany", description: "Central Europe.", themes: [ "federal" ])

    groups = StarSystem.grouped_by_cosmic_structure
    assert_equal [ "Asia", "Europe" ], groups.map { |cosmic_structure, _| cosmic_structure.name }
    assert_equal [ "China", "Japan" ], groups[0][1].map(&:name)
    assert_equal [ "France", "Germany" ], groups[1][1].map(&:name)
  end

  test "destroying a cosmic_structure destroys its associated star_systems" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.", themes: [ "republic" ])

    assert_difference("StarSystem.count", -1) do
      europe.destroy!
    end
  end

  test "embedding_input formats cosmic_structure, name, description, and themes" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe state.", themes: [ "republic", "nuclear" ])

    expected = <<~TEXT.chomp
      Star System: France (Europe)
      Description: Western Europe state.
      Themes: republic, nuclear
    TEXT

    assert_equal expected, star_system.embedding_input
    assert_not star_system.embedded?
  end
end
