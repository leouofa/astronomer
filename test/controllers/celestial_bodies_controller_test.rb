# frozen_string_literal: true

require "test_helper"

class CelestialBodiesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateCelestialBodiesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateCelestialBodiesJob) do
      post populate_celestial_bodies_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Celestial Bodies...", response.body
  end

  test "populate enqueues PopulateCelestialBodiesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateCelestialBodiesJob) do
      post populate_celestial_bodies_url
    end

    assert_redirected_to celestial_bodies_url
  end

  test "show renders celestial_body details and Generate Embedding button" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")
    celestial_body = CelestialBody.create!(star_system: star_system, name: "Paris", description: "National capital.", themes: [ "capital" ])

    get celestial_body_url(celestial_body)

    assert_response :success
    assert_match "Paris", response.body
    assert_match "France", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")
    celestial_body = CelestialBody.create!(star_system: star_system, name: "Paris", description: "National capital.", themes: [ "capital" ])

    get celestial_body_url(celestial_body), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Paris", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Celestial Body Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")
    celestial_body = CelestialBody.create!(star_system: star_system, name: "Paris", description: "National capital.", themes: [ "capital" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "CelestialBody", celestial_body.id ]) do
      post generate_embedding_celestial_body_url(celestial_body), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")
    celestial_body = CelestialBody.create!(star_system: star_system, name: "Paris", description: "National capital.", themes: [ "capital" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "CelestialBody", celestial_body.id ]) do
      post generate_embedding_celestial_body_url(celestial_body)
    end

    assert_redirected_to celestial_body_url(celestial_body)
  end
end
