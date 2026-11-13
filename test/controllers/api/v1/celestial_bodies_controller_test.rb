# frozen_string_literal: true

require "test_helper"

class Api::V1::CitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.98 : 0.02 }

    @star_system = StarSystem.create!(cosmic_structure: @cosmic_structure, name: "France", description: "French Republic.", themes: [ "republic" ])
    @other_star_system = StarSystem.create!(cosmic_structure: @cosmic_structure, name: "Germany", description: "Federal Republic.", themes: [ "federal" ])

    @celestial_body = CelestialBody.create!(
      star_system: @star_system,
      name: "Paris",
      description: "National capital and economic hub.",
      themes: [ "capital", "diplomacy" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/celestial_bodies returns list" do
    get api_v1_celestial_bodies_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal 1, json["data"].size
    assert_equal "Paris", json["data"].first["name"]
    assert_equal "France", json["data"].first.dig("star_system", "name")
  end

  test "GET /api/v1/celestial_bodies/:id returns celestial_body" do
    get api_v1_celestial_body_url(@celestial_body), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @celestial_body.id, json.dig("data", "id")
    assert_equal "Paris", json.dig("data", "name")
    assert_includes json.dig("data", "themes"), "capital"
  end

  test "POST /api/v1/celestial_bodies creates celestial_body for a star_system" do
    assert_difference("CelestialBody.count", 1) do
      post api_v1_celestial_bodies_url, params: {
        celestial_body: {
          star_system_id: @other_star_system.id,
          name: "Berlin",
          description: "Federal capital and cultural center.",
          themes: [ "capital", "culture" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Berlin", response.parsed_body.dig("data", "name")
    assert_equal @other_star_system.id, response.parsed_body.dig("data", "star_system_id")
  end

  test "PATCH /api/v1/celestial_bodies/:id updates celestial_body" do
    patch api_v1_celestial_body_url(@celestial_body), params: {
      celestial_body: {
        description: "Updated Paris description."
      }
    }, as: :json
    assert_response :success
    assert_equal "Updated Paris description.", @celestial_body.reload.description
  end

  test "DELETE /api/v1/celestial_bodies/:id deletes celestial_body" do
    assert_difference("CelestialBody.count", -1) do
      delete api_v1_celestial_body_url(@celestial_body), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/celestial_bodies/:id/neighbors finds nearest celestial_bodies" do
    other_celestial_body = CelestialBody.create!(
      star_system: @star_system,
      name: "Lyon",
      description: "Gastronomic and industrial hub.",
      themes: [ "industry", "culinary" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_celestial_body_url(@celestial_body), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal other_celestial_body.id, json["data"].first["id"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/celestial_bodies/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_celestial_body_url(@celestial_body), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
