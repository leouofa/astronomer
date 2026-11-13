# frozen_string_literal: true

class StarSystemsController < ApplicationController
  include EmbeddableActions

  def show
    @star_system = StarSystem.includes(:cosmic_structure, :celestial_bodies).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "star_systems/modal",
          locals: { star_system: @star_system }
        )
      end
    end
  end

  def generate_embedding
    @star_system = StarSystem.find(params[:id])
    enqueue_embedding_generation(@star_system)
  end

  def populate
    PopulateStarSystemsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_star_systems_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_star_systems_controls",
            action_path: populate_star_systems_path,
            idle_label: "Discover Star Systems",
            running_label: "Discovering Star Systems...",
            running: true,
            status_message: "Asking the agent to discover star systems across galaxies / clusters...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to star_systems_path, notice: "Asking the agent to discover star systems across galaxies / clusters..." }
    end
  end

  def populate_celestial_bodies
    @star_system = StarSystem.find(params[:id])
    PopulateCelestialBodiesJob.perform_later(star_system_id: @star_system.id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Discovering celestial bodies for #{@star_system.name}..."
        render turbo_stream: turbo_stream.replace(
          "star_system_celestial_bodies_section",
          partial: "star_systems/celestial_bodies_section",
          locals: { star_system: @star_system, status_message: flash.now[:notice], status_kind: :info }
        )
      end
      format.html { redirect_to star_system_path(@star_system), notice: "Discovering celestial bodies for #{@star_system.name}..." }
    end
  end

  private

  def find_embeddable_record
    StarSystem.find(params[:id])
  end
end
