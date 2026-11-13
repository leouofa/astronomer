# frozen_string_literal: true

class PopulateCelestialBodiesJob < ApplicationJob
  STREAM_NAME = "celestial_bodies"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(star_system_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    star_systems = if star_system_id.present?
                     StarSystem.where(id: star_system_id).includes(:cosmic_structure).to_a
    else
                     StarSystem.includes(:cosmic_structure).joins(:cosmic_structure).order("cosmic_structures.name ASC, star_systems.name ASC").to_a
    end

    if star_systems.empty?
      msg = star_system_id.present? ? "Star system with ID #{star_system_id} not found." : "No star systems found. Populate star systems first before discovering celestial bodies."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_star_systems: [] }
    end

    total_upserted, failed_star_systems = populate_across_star_systems(star_systems)
    summary = build_summary(total_upserted: total_upserted, total_star_systems: star_systems.size, failed_star_systems: failed_star_systems)

    if failed_star_systems.size == star_systems.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_celestial_bodies: CelestialBody.count, failed_star_systems: failed_star_systems }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_star_systems: failed_star_systems }
  rescue StandardError => e
    Rails.logger.error("[PopulateCelestialBodiesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate celestial bodies: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate celestial bodies: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_star_system!(star_system)
    existing_names = star_system.celestial_bodies.ordered.pluck(:name)
    chat = CelestialBodyDiscoveryAgent.create!(
      star_system_name: star_system.name,
      star_system_description: star_system.description,
      star_system_themes: star_system.themes,
      cosmic_structure_name: star_system.cosmic_structure.name,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(star_system))

    entries = Llm::JsonResponseParser.extract_list(response, key: "celestial_bodies")
    upserted = CelestialBody.upsert_batch!(star_system, entries)
    raise "LLM response did not contain any valid celestial bodies for #{star_system.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_star_systems(star_systems)
    total_upserted = 0
    failed_star_systems = []

    star_systems.each_with_index do |star_system, index|
      msg = "Discovering celestial bodies for #{star_system.name} (#{index + 1}/#{star_systems.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: star_systems.size, star_system: star_system.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_star_system!(star_system)
    rescue StandardError => e
      Rails.logger.error("[PopulateCelestialBodiesJob] StarSystem=#{star_system.name} #{e.class}: #{e.message}")
      failed_star_systems << star_system.name
    end

    [ total_upserted, failed_star_systems ]
  end

  def discovery_prompt_for(star_system)
    "Identify 8 to 10 major, scientifically prominent celestial bodies (planets, major moons, dwarf planets, stellar remnants) in #{star_system.name} (#{star_system.cosmic_structure.name}) and return them as a JSON list with name, description, and thematic tags."
  end

  def build_summary(total_upserted:, total_star_systems:, failed_star_systems:)
    total_celestial_bodies = CelestialBody.count
    if failed_star_systems.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'celestial body'.pluralize(total_upserted)} across #{total_star_systems} #{'star system'.pluralize(total_star_systems)} (#{total_celestial_bodies} total)."
      }
    elsif failed_star_systems.size == total_star_systems
      {
        kind: :error,
        message: "Failed to populate celestial bodies for all star systems: #{failed_star_systems.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'celestial body'.pluralize(total_upserted)} (#{total_celestial_bodies} total). Failed star systems: #{failed_star_systems.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    star_system_groups = CelestialBody.grouped_by_star_system
    total_celestial_bodies_count = CelestialBody.count
    star_systems_count = StarSystem.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_celestial_bodies_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_celestial_bodies_controls",
        action_path: Rails.application.routes.url_helpers.populate_celestial_bodies_path,
        idle_label: "Discover Celestial Bodies",
        running_label: "Discovering Celestial Bodies...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "celestial_bodies_list",
      partial: "pages/celestial_bodies_list",
      locals: {
        grouped_celestial_bodies: star_system_groups,
        star_system_groups: star_system_groups,
        total_celestial_bodies_count: total_celestial_bodies_count,
        star_systems_count: star_systems_count
      }
    )
  end
end
