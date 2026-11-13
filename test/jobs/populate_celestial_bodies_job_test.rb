# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateCelestialBodiesJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "perform iterates through star_systems, upserts celestial_bodies with themes, and streams progress" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    france = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.", themes: [ "republic" ])
    germany = StarSystem.create!(cosmic_structure: europe, name: "Germany", description: "Central Europe.", themes: [ "federal" ])
    CelestialBody.create!(star_system: france, name: "Paris", description: "Initial Paris description", themes: [ "capital" ])

    calls = []
    responses = {
      "France" => <<~TEXT,
        <think>Listing French celestial_bodies.</think>
        ```json
        {
          "celestial_bodies": [
            { "name": "Paris", "description": "National capital and economic hub.", "themes": ["capital", "diplomacy"] },
            { "name": "Marseille", "description": "Mediterranean port gateway.", "themes": ["port", "logistics"] }
          ]
        }
        ```
      TEXT
      "Germany" => {
        "celestial_bodies" => [
          { "name": "Berlin", "description": "Federal capital and cultural center.", "themes": [ "capital", "culture" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(star_system_name:, star_system_description:, star_system_themes:, cosmic_structure_name:, existing_names:) {
      calls << {
        star_system_name: star_system_name,
        star_system_description: star_system_description,
        star_system_themes: star_system_themes,
        cosmic_structure_name: cosmic_structure_name,
        existing_names: existing_names
      }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(star_system_name))
      end
      fake_chat
    }) do
      # 2 star_systems * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateCelestialBodiesJob::STREAM_NAME, 6) do
        PopulateCelestialBodiesJob.perform_now
      end
    end

    assert_equal [ "France", "Germany" ], calls.map { |c| c[:star_system_name] }
    assert_equal [ "Paris" ], calls.first[:existing_names]
    assert_equal [], calls.second[:existing_names]

    assert_equal 3, CelestialBody.count
    paris = france.celestial_bodies.find_by!(name: "Paris")
    assert_equal "National capital and economic hub.", paris.description
    assert_equal [ "capital", "diplomacy" ], paris.themes

    berlin = germany.celestial_bodies.find_by!(name: "Berlin")
    assert_equal [ "capital", "culture" ], berlin.themes
  end

  test "perform continues to remaining star_systems if one star_system fails" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    france = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western Europe.")
    germany = StarSystem.create!(cosmic_structure: europe, name: "Germany", description: "Central Europe.")

    with_stubbed_agent_create(->(star_system_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on France" if star_system_name == "France"

        OpenStruct.new(
          parsed: nil,
          content: {
            "celestial_bodies" => [
              { "name": "Berlin", "description": "Federal capital.", "themes": [ "capital" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateCelestialBodiesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateCelestialBodiesJob.perform_now }
      end
    end

    assert_equal 1, CelestialBody.count
    assert_equal "Berlin", CelestialBody.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = CelestialBodyDiscoveryAgent.singleton_class
    original = CelestialBodyDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
