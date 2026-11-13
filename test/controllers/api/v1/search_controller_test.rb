# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cosmic_structure = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")
    @vector = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }

    @star_system = StarSystem.create!(
      cosmic_structure: @cosmic_structure,
      name: "Japan",
      description: "East Asian island state with high technology and industrial power.",
      themes: [ "island", "tech", "export" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @celestial_body = CelestialBody.create!(
      star_system: @star_system,
      name: "Tokyo",
      description: "Megacelestial_body capital and global financial center.",
      themes: [ "capital", "finance", "megacelestial_body" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/search requires q parameter" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    assert_equal "blank_query", response.parsed_body.dig("error", "code")
  end

  test "GET /api/v1/search returns results for keyword search" do
    get api_v1_search_url, params: { q: "megacelestial_body", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "keyword", json.dig("meta", "mode")
  end

  test "GET /api/v1/star_systems/search performs keyword search" do
    get search_api_v1_star_systems_url, params: { q: "Japan", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Japan", json["data"].first["name"]
  end

  test "GET /api/v1/celestial_bodies/search performs keyword search" do
    get search_api_v1_celestial_bodies_url, params: { q: "financial", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @celestial_body.id, json["data"].first["id"]
  end
end
