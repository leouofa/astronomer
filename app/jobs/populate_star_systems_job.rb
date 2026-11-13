# frozen_string_literal: true

class PopulateStarSystemsJob < ApplicationJob
  STREAM_NAME = "star_systems"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(cosmic_structure_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    cosmic_structures = if cosmic_structure_id.present?
                          CosmicStructure.where(id: cosmic_structure_id).to_a
    else
                          CosmicStructure.ordered.to_a
    end

    if cosmic_structures.empty?
      msg = cosmic_structure_id.present? ? "Cosmic structure with ID #{cosmic_structure_id} not found." : "No galaxies / clusters found. Populate cosmic structures first before discovering star systems."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_structures: [] }
    end

    total_upserted, failed_structures = populate_across_structures(cosmic_structures)
    summary = build_summary(total_upserted: total_upserted, total_structures: cosmic_structures.size, failed_structures: failed_structures)

    if failed_structures.size == cosmic_structures.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_star_systems: StarSystem.count, failed_structures: failed_structures }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_structures: failed_structures }
  rescue StandardError => e
    Rails.logger.error("[PopulateStarSystemsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate star systems: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate star systems: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_cosmic_structure!(cosmic_structure)
    existing_names = cosmic_structure.star_systems.ordered.pluck(:name)
    chat = StarSystemDiscoveryAgent.create!(
      cosmic_structure_name: cosmic_structure.name,
      cosmic_structure_description: cosmic_structure.description,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(cosmic_structure))

    entries = Llm::JsonResponseParser.extract_list(response, key: "star_systems")
    upserted = StarSystem.upsert_batch!(cosmic_structure, entries)
    raise "LLM response did not contain any valid star systems for #{cosmic_structure.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_structures(cosmic_structures)
    total_upserted = 0
    failed_structures = []

    cosmic_structures.each_with_index do |structure, index|
      msg = "Discovering star systems for #{structure.name} (#{index + 1}/#{cosmic_structures.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: cosmic_structures.size, cosmic_structure: structure.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_cosmic_structure!(structure)
    rescue StandardError => e
      Rails.logger.error("[PopulateStarSystemsJob] CosmicStructure=#{structure.name} #{e.class}: #{e.message}")
      failed_structures << structure.name
    end

    [ total_upserted, failed_structures ]
  end

  def discovery_prompt_for(cosmic_structure)
    "Find prominent star systems, stellar remnants, pulsars, and binary systems belonging to #{cosmic_structure.name} and return their names, descriptions, and thematic tags as JSON."
  end

  def build_summary(total_upserted:, total_structures:, failed_structures:)
    total_star_systems = StarSystem.count
    if failed_structures.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'star system'.pluralize(total_upserted)} across #{total_structures} #{'galaxy / cluster'.pluralize(total_structures)} (#{total_star_systems} total)."
      }
    elsif failed_structures.size == total_structures
      {
        kind: :error,
        message: "Failed to populate star systems for all galaxies / clusters: #{failed_structures.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'star system'.pluralize(total_upserted)} (#{total_star_systems} total). Failed structures: #{failed_structures.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    cosmic_structure_groups = StarSystem.grouped_by_cosmic_structure
    total_star_systems_count = StarSystem.count
    cosmic_structures_count = CosmicStructure.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_star_systems_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_star_systems_controls",
        action_path: Rails.application.routes.url_helpers.populate_star_systems_path,
        idle_label: "Discover Star Systems",
        running_label: "Discovering Star Systems...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "star_systems_list",
      partial: "pages/star_systems_list",
      locals: {
        grouped_star_systems: cosmic_structure_groups,
        cosmic_structure_groups: cosmic_structure_groups,
        total_star_systems_count: total_star_systems_count,
        cosmic_structures_count: cosmic_structures_count
      }
    )
  end
end
