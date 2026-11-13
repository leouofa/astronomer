# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform generates embedding for StarSystem and broadcasts running and success states" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "French Republic.", themes: [ "republic", "nuclear" ])
    vector = Array.new(1024, 0.05)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(star_system), 2) do
        GenerateEmbeddingJob.perform_now("StarSystem", star_system.id)
      end
    end

    star_system.reload
    assert star_system.embedded?
    assert_equal "qwen3-embedding:0.6b", star_system.embedding_model
    assert_not_nil star_system.embedded_at
    assert_equal 1024, star_system.embedding.size
  end

  test "perform generates embedding for CelestialBody and broadcasts running and success states" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "French Republic.", themes: [ "republic" ])
    celestial_body = CelestialBody.create!(star_system: star_system, name: "Paris", description: "Capital celestial_body.", themes: [ "capital" ])
    vector = Array.new(1024, 0.02)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(celestial_body), 2) do
        GenerateEmbeddingJob.perform_now("CelestialBody", celestial_body.id)
      end
    end

    celestial_body.reload
    assert celestial_body.embedded?
    assert_equal "qwen3-embedding:0.6b", celestial_body.embedding_model
    assert_not_nil celestial_body.embedded_at
    assert_equal 1024, celestial_body.embedding.size
  end

  test "perform broadcasts error state when embedding generation fails" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "Germany", description: "Federal Republic.")

    with_stubbed_generator(->(_text) { raise "Connection refused" }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(star_system), 2) do
        GenerateEmbeddingJob.perform_now("StarSystem", star_system.id)
      end
    end

    assert_not star_system.reload.embedded?
  end

  private

  def with_stubbed_generator(replacement)
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call, &replacement)
    yield
  ensure
    singleton.define_method(:call, original)
  end
end
