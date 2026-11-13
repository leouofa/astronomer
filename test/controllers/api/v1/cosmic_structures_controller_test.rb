# frozen_string_literal: true

require "test_helper"

class Api::V1::CosmicStructuresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cosmic_structure = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
  end

  test "GET /api/v1/cosmic_structures returns list" do
    get api_v1_cosmic_structures_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert json["meta"].key?("total")
    names = json["data"].map { |p| p["name"] }
    assert_includes names, "Europe"
  end

  test "GET /api/v1/cosmic_structures/:id returns single cosmic_structure" do
    get api_v1_cosmic_structure_url(@cosmic_structure), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @cosmic_structure.name, json.dig("data", "name")
  end

  test "POST /api/v1/cosmic_structures creates a new cosmic_structure" do
    assert_difference("CosmicStructure.count", 1) do
      post api_v1_cosmic_structures_url, params: { cosmic_structure: { name: "Asia", description: "Asian cosmic_structure." } }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Asia", json.dig("data", "name")
  end

  test "PATCH /api/v1/cosmic_structures/:id updates a cosmic_structure" do
    patch api_v1_cosmic_structure_url(@cosmic_structure), params: { cosmic_structure: { description: "Updated description" } }, as: :json
    assert_response :success

    @cosmic_structure.reload
    assert_equal "Updated description", @cosmic_structure.description
  end

  test "DELETE /api/v1/cosmic_structures/:id removes a cosmic_structure" do
    assert_difference("CosmicStructure.count", -1) do
      delete api_v1_cosmic_structure_url(@cosmic_structure), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "POST /api/v1/cosmic_structures/upsert_batch upserts multiple cosmic_structures" do
    payload = {
      cosmic_structures: [
        { name: "Europe", description: "New Europe description" },
        { name: "Africa", description: "African cosmic_structure." }
      ]
    }

    assert_difference("CosmicStructure.count", 1) do
      post upsert_batch_api_v1_cosmic_structures_url, params: payload, as: :json
    end
    assert_response :success

    assert_equal "New Europe description", @cosmic_structure.reload.description
    assert CosmicStructure.find_by(name: "Africa")
  end

  test "POST /api/v1/cosmic_structures/populate enqueues PopulateCosmicStructuresJob by default" do
    assert_enqueued_with(job: PopulateCosmicStructuresJob) do
      post populate_api_v1_cosmic_structures_url, as: :json
    end
    assert_response :accepted
    assert response.parsed_body.dig("data", "job_id").present?
  end

  test "POST /api/v1/cosmic_structures/:id/populate_star_systems enqueues PopulateStarSystemsJob" do
    assert_enqueued_with(job: PopulateStarSystemsJob, args: [ { cosmic_structure_id: @cosmic_structure.id } ]) do
      post populate_star_systems_api_v1_cosmic_structure_url(@cosmic_structure), as: :json
    end
    assert_response :accepted
  end
end
