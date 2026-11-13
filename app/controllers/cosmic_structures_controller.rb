# frozen_string_literal: true

class CosmicStructuresController < ApplicationController
  def populate
    PopulateCosmicStructuresJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_controls",
            action_path: populate_cosmic_structures_path,
            idle_label: "Populate Cosmic Structures",
            running_label: "Discovering Cosmic Structures...",
            running: true,
            status_message: "Asking the agent to discover major galaxies and clusters...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to root_path, notice: "Asking the agent to discover major galaxies and clusters..." }
    end
  end
end
