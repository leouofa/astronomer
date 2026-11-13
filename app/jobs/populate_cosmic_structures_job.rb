# frozen_string_literal: true

class PopulateCosmicStructuresJob < ApplicationJob
  queue_as :default

  STREAM_NAME = "populate_cosmic_structures"
  DISCOVERY_PROMPT = "Identify major galaxies, dwarf galaxies, and galaxy clusters (e.g. Milky Way, Andromeda Galaxy, Large Magellanic Cloud, Small Magellanic Cloud, Triangulum Galaxy, Centaurus A, Virgo Cluster) and return their canonical names and astrophysical descriptions as JSON."

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    existing_names = CosmicStructure.ordered.pluck(:name)
    chat = CosmicStructureDiscoveryAgent.create!(existing_names: existing_names)
    response = chat.ask(DISCOVERY_PROMPT)

    entries = Llm::JsonResponseParser.extract_list(response, key: "cosmic_structures")
    upserted = CosmicStructure.upsert_batch!(entries)
    raise "LLM response did not contain any valid cosmic structures." if upserted.empty?

    message = "Upserted #{upserted.size} #{'galaxy / cluster'.pluralize(upserted.size)} (#{CosmicStructure.count} total)."
    track_completed(message: message, result: { upserted_count: upserted.size, total_count: CosmicStructure.count })

    broadcast_state(
      status_message: message,
      status_kind: :success,
      running: false
    )
    { upserted_count: upserted.size, total_count: CosmicStructure.count }
  rescue StandardError => e
    Rails.logger.error("[PopulateCosmicStructuresJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate cosmic structures: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate cosmic structures: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def broadcast_state(status_message:, status_kind:, running:)
    cosmic_structures = CosmicStructure.ordered.to_a

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_cosmic_structures_path,
        idle_label: "Populate Galaxies / Clusters",
        running_label: "Discovering Galaxies / Clusters...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "cosmic_structures_list",
      partial: "pages/cosmic_structures_list",
      locals: { cosmic_structures: cosmic_structures }
    )
  end
end
