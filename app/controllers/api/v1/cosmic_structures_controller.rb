# frozen_string_literal: true

module Api
  module V1
    class CosmicStructuresController < BaseController
      before_action :set_cosmic_structure, only: %i[show update destroy populate_star_systems]

      def index
        scope = CosmicStructure.all
        scope = scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        records, meta = paginate(scope.order("name ASC"))
        include_star_systems = boolean_param(:include_star_systems, default: false)

        data = records.map do |c|
          Serializer.cosmic_structure(c, include_star_systems: include_star_systems)
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.cosmic_structure(@cosmic_structure, include_star_systems: boolean_param(:include_star_systems, default: true))
        )
      end

      def create
        cosmic_structure = CosmicStructure.create!(cosmic_structure_params)
        render_success(Serializer.cosmic_structure(cosmic_structure), status: :created)
      end

      def update
        @cosmic_structure.update!(cosmic_structure_params)
        render_success(Serializer.cosmic_structure(@cosmic_structure))
      end

      def destroy
        @cosmic_structure.destroy!
        render_success({ id: @cosmic_structure.id, name: @cosmic_structure.name, deleted: true })
      end

      def populate_star_systems
        if sync_requested?
          result = PopulateStarSystemsJob.new.perform(cosmic_structure_id: @cosmic_structure.id)
          render_success({ message: "Star systems populated for #{@cosmic_structure.name}", result: result })
        else
          job = PopulateStarSystemsJob.perform_later(cosmic_structure_id: @cosmic_structure.id)
          render_success({ job_id: job.job_id, status: "queued", cosmic_structure_id: @cosmic_structure.id }, status: :accepted)
        end
      end

      def populate
        if sync_requested?
          result = PopulateCosmicStructuresJob.new.perform
          render_success({ message: "Cosmic structures populated", result: result })
        else
          job = PopulateCosmicStructuresJob.perform_later
          render_success({ job_id: job.job_id, status: "queued" }, status: :accepted)
        end
      end

      def upsert_batch
        entries = params.require(:cosmic_structures).map do |entry|
          entry.permit(:name, :description).to_h
        end
        upserted = CosmicStructure.upsert_batch!(entries)
        render_success(
          upserted.map { |c| Serializer.cosmic_structure(c) },
          meta: { count: upserted.size }
        )
      end

      private

      def set_cosmic_structure
        @cosmic_structure = CosmicStructure.find(params[:id])
      end

      def cosmic_structure_params
        params.require(:cosmic_structure).permit(:name, :description)
      end
    end
  end
end
