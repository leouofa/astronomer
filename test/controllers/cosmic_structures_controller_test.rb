# frozen_string_literal: true

require "test_helper"

class CosmicStructuresControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateCosmicStructuresJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateCosmicStructuresJob) do
      post populate_cosmic_structures_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Cosmic Structures...", response.body
  end

  test "populate enqueues PopulateCosmicStructuresJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateCosmicStructuresJob) do
      post populate_cosmic_structures_url
    end

    assert_redirected_to root_url
  end
end
