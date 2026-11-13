# frozen_string_literal: true

require "test_helper"

class StarSystemsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateStarSystemsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateStarSystemsJob) do
      post populate_star_systems_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Star Systems...", response.body
  end

  test "populate enqueues PopulateStarSystemsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateStarSystemsJob) do
      post populate_star_systems_url
    end

    assert_redirected_to star_systems_url
  end

  test "show renders star_system details and Generate Embedding button" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.", themes: [ "republic" ])

    get star_system_url(star_system)

    assert_response :success
    assert_match "France", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.", themes: [ "republic" ])

    get star_system_url(star_system), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "France", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Star System Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "StarSystem", star_system.id ]) do
      post generate_embedding_star_system_url(star_system), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "StarSystem", star_system.id ]) do
      post generate_embedding_star_system_url(star_system)
    end

    assert_redirected_to star_system_url(star_system)
  end
end
