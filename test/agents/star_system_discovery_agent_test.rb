# frozen_string_literal: true

require "test_helper"

class StarSystemDiscoveryAgentTest < ActiveSupport::TestCase
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

  test "create! includes cosmic_structure context, existing star_system names, and JSON schema instructions" do
    chat = StarSystemDiscoveryAgent.create!(
      cosmic_structure_name: "Europe",
      cosmic_structure_description: "European cosmic_structure with diverse sovereign states.",
      existing_names: [ "France", "Germany" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Europe"
    assert_includes system_message.content, "European cosmic_structure with diverse sovereign states."
    assert_includes system_message.content, "France, Germany"
    assert_includes system_message.content, '"star_systems"'
    assert_includes system_message.content, '"themes"'
  end
end
