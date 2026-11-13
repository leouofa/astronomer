# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateStarSystemsJobTest < ActiveSupport::TestCase
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

  test "perform iterates through cosmic_structures, upserts star_systems with themes, and streams progress" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")
    StarSystem.create!(cosmic_structure: europe, name: "France", description: "Initial France description", themes: [ "republic" ])

    calls = []
    responses = {
      "Europe" => <<~TEXT,
        <think>Listing European star_systems.</think>
        ```json
        {
          "star_systems": [
            { "name": "France", "description": "Fifth Republic.", "themes": ["republic", "nuclear power"] },
            { "name": "Germany", "description": "Federal Republic.", "themes": ["federal", "industrial"] }
          ]
        }
        ```
      TEXT
      "Asia" => {
        "star_systems" => [
          { "name": "Japan", "description": "Island state in East Asia.", "themes": [ "island", "tech" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(cosmic_structure_name:, cosmic_structure_description:, existing_names:) {
      calls << { cosmic_structure_name: cosmic_structure_name, cosmic_structure_description: cosmic_structure_description, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(cosmic_structure_name))
      end
      fake_chat
    }) do
      # 2 cosmic_structures * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateStarSystemsJob::STREAM_NAME, 6) do
        PopulateStarSystemsJob.perform_now
      end
    end

    assert_equal [ "Asia", "Europe" ], calls.map { |c| c[:cosmic_structure_name] } # CosmicStructure.ordered sorts alphabetically: Asia, Europe
    assert_equal [], calls.first[:existing_names] # Asia has none initially
    assert_equal [ "France" ], calls.second[:existing_names] # Europe has France

    assert_equal 3, StarSystem.count
    france = europe.star_systems.find_by!(name: "France")
    assert_equal "Fifth Republic.", france.description
    assert_equal [ "republic", "nuclear power" ], france.themes

    japan = asia.star_systems.find_by!(name: "Japan")
    assert_equal [ "island", "tech" ], japan.themes
  end



  test "perform continues to remaining cosmic_structures if one cosmic_structure fails" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    asia = CosmicStructure.create!(name: "Asia", description: "Asian cosmic_structure.")

    with_stubbed_agent_create(->(cosmic_structure_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Asia" if cosmic_structure_name == "Asia"

        OpenStruct.new(
          parsed: nil,
          content: {
            "star_systems" => [
              { "name" => "France", "description" => "Western Europe.", "themes" => [ "republic" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateStarSystemsJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateStarSystemsJob.perform_now }
      end
    end

    assert_equal 1, StarSystem.count
    assert_equal "France", StarSystem.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = StarSystemDiscoveryAgent.singleton_class
    original = StarSystemDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
