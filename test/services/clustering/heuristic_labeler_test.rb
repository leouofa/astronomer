# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for star_systems" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    c1 = StarSystem.create!(cosmic_structure: cosmic_structure, name: "France", description: "Western Europe", themes: %w[nuclear maritime republic])
    c2 = StarSystem.create!(cosmic_structure: cosmic_structure, name: "United Kingdom", description: "Island state", themes: %w[nuclear maritime monarchy])

    result = Clustering::HeuristicLabeler.label([ c1, c2 ])
    assert_includes result[:shared_themes], "Nuclear"
    assert_includes result[:shared_themes], "Maritime"
    assert_includes result[:title], "Archetype"
  end

  test "extracts shared themes for celestial_bodies" do
    cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: cosmic_structure, name: "France", description: "Western Europe")
    celestial_body1 = CelestialBody.create!(star_system: star_system, name: "Marseille", description: "Port", themes: [ "port", "trade" ])
    celestial_body2 = CelestialBody.create!(star_system: star_system, name: "Le Havre", description: "Northern port", themes: [ "port", "logistics" ])

    result = Clustering::HeuristicLabeler.label([ celestial_body1, celestial_body2 ])
    assert_includes result[:shared_themes], "Port"
    assert_includes result[:title], "Archetype"
  end
end
