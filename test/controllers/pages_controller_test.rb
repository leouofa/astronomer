# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders empty state and populate button when no cosmic_structures exist" do
    get root_url

    assert_response :success
    assert_select "h1", "Galaxies / Clusters"
    assert_select "button", /Discover|Populate/
    assert_match "No cosmic structures yet", response.body
  end

  test "home lists all cosmic_structures ordered by name" do
    CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Asia"), :<, response.body.index("Europe")
    assert_match "European cosmic_structure.", response.body
    assert_match "Asian cosmic_structure.", response.body
  end

  test "star_systems renders empty state and populate button when no star_systems exist" do
    get star_systems_url

    assert_response :success
    assert_select "h1", "Star Systems"
    assert_select "button", /Discover Star Systems/
    assert_match "No star systems yet", response.body
  end

  test "star_systems lists all star_systems in a table grouped by cosmic_structure headers with themes" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")

    StarSystem.create!(cosmic_structure: asia, name: "Japan", description: "East Asian state.", themes: [ "island", "tech" ])
    StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.", themes: [ "republic", "nuclear" ])
    StarSystem.create!(cosmic_structure: europe, name: "Germany", description: "Central European republic.", themes: [ "federal", "manufacturing" ])

    get star_systems_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Asia/
    assert_select "table tbody tr th", /Europe/
    assert_operator response.body.index("Asia"), :<, response.body.index("Europe")
    assert_operator response.body.index("France"), :<, response.body.index("Germany")
    assert_match "East Asian state.", response.body
    assert_match "nuclear", response.body
    assert_match "republic", response.body
    assert_match "tech", response.body
  end

  test "celestial_bodies renders empty state, populate button, and top navbar link when no celestial_bodies exist" do
    get celestial_bodies_url

    assert_response :success
    assert_select "nav a[href=?]", celestial_bodies_path, text: "Planets / Celestial Bodies"
    assert_select "h1", "Planets / Celestial Bodies"
    assert_select "button", /Discover Celestial Bodies/
    assert_match "No celestial bodies yet", response.body
  end

  test "celestial_bodies lists all celestial_bodies in a table grouped by star_system headers" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")

    france = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.")
    japan = StarSystem.create!(cosmic_structure: asia, name: "Japan", description: "East Asia.")

    CelestialBody.create!(star_system: france, name: "Paris", description: "French capital.", themes: [ "capital", "diplomacy" ])
    CelestialBody.create!(star_system: france, name: "Marseille", description: "Mediterranean port gateway.", themes: [ "port" ])
    CelestialBody.create!(star_system: japan, name: "Tokyo", description: "Megacelestial_body capital.", themes: [ "capital", "finance" ])

    get celestial_bodies_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Japan/
    assert_select "table tbody tr th", /France/
    assert_match "Paris", response.body
    assert_match "Marseille", response.body
    assert_match "Tokyo", response.body
    assert_match "Mediterranean port gateway.", response.body
  end
end
