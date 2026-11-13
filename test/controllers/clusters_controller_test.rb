# frozen_string_literal: true

require "test_helper"

class ClustersControllerTest < ActionDispatch::IntegrationTest
  test "GET /clusters returns success for star_systems" do
    get clusters_path
    assert_response :success
    assert_select "h1", "Embedding Clusters"
    assert_select "input#similarity_level[value='5']"
  end

  test "GET /clusters with tab=celestial_bodies returns success" do
    get clusters_path(tab: "celestial_bodies", level: 3)
    assert_response :success
    assert_select "h1", "Embedding Clusters"
  end

  test "GET /clusters with turbo_stream format returns frame stream" do
    get clusters_path(tab: "star_systems", level: 4), as: :turbo_stream
    assert_response :success
    assert_includes response.body, %(turbo-stream action="update" target="clusters_content_frame")
  end

  test "GET /clusters with level=15 renders complete coverage without singletons" do
    get clusters_path(level: 15)
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters with full_coverage=true returns complete coverage" do
    get clusters_path(level: 6, full_coverage: "true")
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters renders entity links targeting cluster_modal frame" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    v = Array.new(1024, 0.1)
    StarSystem.create!(cosmic_structure: europe, name: "France Modal Test", description: "French Republic", embedding: v)
    StarSystem.create!(cosmic_structure: europe, name: "Germany Modal Test", description: "Federal Republic", embedding: v)

    get clusters_path(tab: "star_systems", level: 5)
    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "France Modal Test"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "View details →"
  end

  test "GET /clusters with celestial_bodies tab renders celestial_body links targeting cluster_modal frame" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "French Republic")
    v = Array.new(1024, 0.1)
    CelestialBody.create!(star_system: star_system, name: "Paris Modal Test", description: "Capital", themes: [ "capital" ], embedding: v)
    CelestialBody.create!(star_system: star_system, name: "Marseille Modal Test", description: "Port", themes: [ "port" ], embedding: v)

    get clusters_path(tab: "celestial_bodies", level: 5)
    assert_response :success
    assert_select "a[data-turbo-frame='cluster_modal']", text: "Paris Modal Test"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "View details →"
  end

  test "POST /clusters/snapshot creates snapshot and redirects to it" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    v = Array.new(1024, 0.2)
    StarSystem.create!(cosmic_structure: europe, name: "Snap StarSystem 1", description: "D1", themes: [ "republic" ], embedding: v)
    StarSystem.create!(cosmic_structure: europe, name: "Snap StarSystem 2", description: "D2", themes: [ "republic" ], embedding: v)

    assert_difference "ClusterSnapshot.count", 1 do
      post snapshot_clusters_path, params: { tab: "star_systems", level: 5, title: "Test Controller Snapshot" }
    end

    snapshot = ClusterSnapshot.last
    assert_equal "Test Controller Snapshot", snapshot.title
    assert_redirected_to cluster_snapshot_path(snapshot)
    follow_redirect!
    assert_response :success
  end
end
