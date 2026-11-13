# frozen_string_literal: true

require "test_helper"

class CelestialBodyDiscoveryAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! includes star_system context, cosmic_structure name, existing celestial_body names, and TRAPPIST-1e JSON example" do
    chat = CelestialBodyDiscoveryAgent.create!(
      star_system_name: "France",
      star_system_description: "Western European sovereign republic.",
      star_system_themes: [ "republic", "nuclear power", "diplomacy" ],
      cosmic_structure_name: "Europe",
      existing_names: [ "Paris", "Lyon" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "France"
    assert_includes system_message.content, "Europe"
    assert_includes system_message.content, "Western European sovereign republic."
    assert_includes system_message.content, "republic, nuclear power, diplomacy"
    assert_includes system_message.content, "Paris, Lyon"
    assert_includes system_message.content, "TRAPPIST-1e"
    assert_includes system_message.content, '"celestial_bodies"'
    assert_includes system_message.content, '"themes"'
  end
end
