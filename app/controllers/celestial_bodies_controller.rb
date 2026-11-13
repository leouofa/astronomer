# frozen_string_literal: true

class CelestialBodiesController < ApplicationController
  include EmbeddableActions

  def show
    @celestial_body = CelestialBody.includes(star_system: :cosmic_structure).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "celestial_bodies/modal",
          locals: { celestial_body: @celestial_body }
        )
      end
    end
  end

  def generate_embedding
    @celestial_body = CelestialBody.find(params[:id])
    enqueue_embedding_generation(@celestial_body)
  end

  def populate
    PopulateCelestialBodiesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_celestial_bodies_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_celestial_bodies_controls",
            action_path: populate_celestial_bodies_path,
            idle_label: "Discover Celestial Bodies",
            running_label: "Discovering Celestial Bodies...",
            running: true,
            status_message: "Asking the agent to discover celestial bodies across star systems...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to celestial_bodies_path, notice: "Asking the agent to discover celestial bodies across star systems..." }
    end
  end

  private

  def find_embeddable_record
    CelestialBody.find(params[:id])
  end
end
