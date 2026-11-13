# frozen_string_literal: true

require "test_helper"

class CelestialBodyTest < ActiveSupport::TestCase
  test "validates presence of name, description, and star_system" do
    celestial_body = CelestialBody.new(name: " ", description: " ")
    assert_not celestial_body.valid?
    assert_includes celestial_body.errors[:star_system], "must exist"
    assert_includes celestial_body.errors[:name], "can't be blank"
    assert_includes celestial_body.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: cosmic_structure, name: "France", description: "French Republic.")
    celestial_body = CelestialBody.create!(
      star_system: star_system,
      name: "  Paris   CelestialBody ",
      description: "  Capital and financial center.  ",
      themes: [ " diplomacy ", "Finance", "DIPLOMACY", "", nil ]
    )

    assert_equal "Paris CelestialBody", celestial_body.name
    assert_equal "Capital and financial center.", celestial_body.description
    assert_equal [ "diplomacy", "Finance" ], celestial_body.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    cosmic_structure = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: cosmic_structure, name: "Japan", description: "East Asian state.")
    celestial_body = CelestialBody.create!(
      star_system: star_system,
      name: "Tokyo",
      description: "Capital of Japan.",
      themes: "megacelestial_body, global finance, robotics, Megacelestial_body"
    )

    assert_equal [ "megacelestial_body", "global finance", "robotics" ], celestial_body.themes
  end

  test "enforces case-insensitive uniqueness scoped per star_system" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    france = StarSystem.create!(cosmic_structure: cosmic_structure, name: "France", description: "French Republic.")
    usa_cosmic_structure = CosmicStructure.create!(name: "North America", description: "North American cosmic_structure.")
    usa = StarSystem.create!(cosmic_structure: usa_cosmic_structure, name: "United States", description: "Federal Republic.")

    CelestialBody.create!(star_system: france, name: "Paris", description: "French capital.")

    same_star_system_dup = CelestialBody.new(star_system: france, name: "paris", description: "Duplicate.")
    assert_not same_star_system_dup.valid?
    assert_includes same_star_system_dup.errors[:name], "has already been taken"

    other_star_system_celestial_body = CelestialBody.new(star_system: usa, name: "Paris", description: "Paris, Texas.")
    assert other_star_system_celestial_body.valid?
  end

  test "upsert_batch! inserts new celestial_bodies and updates existing ones within a star_system" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    france = StarSystem.create!(cosmic_structure: cosmic_structure, name: "France", description: "French Republic.")
    germany = StarSystem.create!(cosmic_structure: cosmic_structure, name: "Germany", description: "Federal Republic.")

    CelestialBody.create!(star_system: france, name: "Paris", description: "Old description", themes: [ "capital" ])
    CelestialBody.create!(star_system: germany, name: "Paris", description: "Different Paris", themes: [ "town" ])

    results = CelestialBody.upsert_batch!(france, [
      { "name" => "  paris ", "description" => "Global diplomatic hub.", "themes" => [ "capital", "diplomacy" ] },
      { "name" => "Marseille", "description" => "Port celestial_body.", "themes" => [ "maritime", "trade" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Lyon", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, france.celestial_bodies.count
    assert_equal 1, germany.celestial_bodies.count

    france_paris = france.celestial_bodies.find_by!("LOWER(name) = ?", "paris")
    assert_equal "paris", france_paris.name
    assert_equal "Global diplomatic hub.", france_paris.description
    assert_equal [ "capital", "diplomacy" ], france_paris.themes

    marseille = france.celestial_bodies.find_by!(name: "Marseille")
    assert_equal [ "maritime", "trade" ], marseille.themes
  end

  test "grouped_by_star_system returns star_system groups and celestial_bodies sorted alphabetically" do
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")

    japan = StarSystem.create!(cosmic_structure: asia, name: "Japan", description: "East Asia.")
    france = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.")

    CelestialBody.create!(star_system: japan, name: "Tokyo", description: "Capital.", themes: [ "capital" ])
    CelestialBody.create!(star_system: japan, name: "Osaka", description: "Commercial center.", themes: [ "commerce" ])
    CelestialBody.create!(star_system: france, name: "Paris", description: "Capital.", themes: [ "capital" ])
    CelestialBody.create!(star_system: france, name: "Lyon", description: "Gastronomy center.", themes: [ "culinary" ])

    groups = CelestialBody.grouped_by_star_system
    assert_equal [ "Japan", "France" ], groups.map { |star_system, _| star_system.name }
    assert_equal [ "Osaka", "Tokyo" ], groups[0][1].map(&:name)
    assert_equal [ "Lyon", "Paris" ], groups[1][1].map(&:name)
  end

  test "destroying a star_system destroys its associated celestial_bodies" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    france = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.")
    CelestialBody.create!(star_system: france, name: "Paris", description: "Capital.", themes: [ "capital" ])

    assert_difference "CelestialBody.count", -1 do
      france.destroy
    end
  end

  test "embedding_input formats celestial_body, star_system, cosmic_structure, description, and themes" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: cosmic_structure, name: "France", description: "French Republic.")
    celestial_body = CelestialBody.new(
      star_system: star_system,
      name: "Paris",
      description: "Center of state power.",
      themes: [ "governance", "diplomacy" ]
    )

    expected = <<~TXT.strip
      Celestial Body: Paris (France, Europe)
      Description: Center of state power.
      Themes: governance, diplomacy
    TXT

    assert_equal expected, celestial_body.embedding_input
  end
end
