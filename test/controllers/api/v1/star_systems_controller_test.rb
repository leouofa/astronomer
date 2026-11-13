# frozen_string_literal: true

require "test_helper"

class Api::V1::CountriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @star_system = StarSystem.create!(
      cosmic_structure: @cosmic_structure,
      name: "France",
      description: "Western European republic.",
      themes: [ "republic", "nuclear", "diplomacy" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/star_systems returns list with filtering" do
    get api_v1_star_systems_url, params: { cosmic_structure_id: @cosmic_structure.id, theme: "nuclear" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "France", json["data"].first["name"]
    assert_equal false, json["data"].first.key?("embedding")
  end

  test "GET /api/v1/star_systems/:id returns star_system with cosmic_structure details" do
    get api_v1_star_system_url(@star_system), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "France", json.dig("data", "name")
    assert_equal "Europe", json.dig("data", "cosmic_structure", "name")
  end

  test "GET /api/v1/star_systems/:id with include_embedding=true returns raw vector" do
    get api_v1_star_system_url(@star_system), params: { include_embedding: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "embedding").is_a?(Array)
    assert_equal 1024, json.dig("data", "embedding").size
  end

  test "POST /api/v1/star_systems creates a star_system" do
    assert_difference("StarSystem.count", 1) do
      post api_v1_star_systems_url, params: {
        star_system: {
          cosmic_structure_id: @cosmic_structure.id,
          name: "Germany",
          description: "Central European federal state.",
          themes: [ "federal", "manufacturing" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Germany", response.parsed_body.dig("data", "name")
  end

  test "PATCH /api/v1/star_systems/:id updates star_system" do
    patch api_v1_star_system_url(@star_system), params: { star_system: { description: "Updated France description" } }, as: :json
    assert_response :success
    assert_equal "Updated France description", @star_system.reload.description
  end

  test "DELETE /api/v1/star_systems/:id deletes star_system" do
    assert_difference("StarSystem.count", -1) do
      delete api_v1_star_system_url(@star_system), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/star_systems/:id/neighbors finds nearest star_systems" do
    other = StarSystem.create!(
      cosmic_structure: @cosmic_structure,
      name: "United Kingdom",
      description: "Island monarchy.",
      themes: [ "monarchy", "maritime" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_star_system_url(@star_system), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "United Kingdom", json["data"].first["name"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/star_systems/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_star_system_url(@star_system), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
