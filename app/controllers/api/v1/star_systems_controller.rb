# frozen_string_literal: true

module Api
  module V1
    class StarSystemsController < BaseController
      before_action :set_star_system, only: %i[show update destroy neighbors generate_embedding populate_celestial_bodies]

      def index
        scope = StarSystem.includes(:cosmic_structure)
        scope = scope.where(cosmic_structure_id: params[:cosmic_structure_id]) if params[:cosmic_structure_id].present?
        if params[:cosmic_structure].present?
          scope = scope.joins(:cosmic_structure).where("cosmic_structures.name ILIKE ?", "%#{params[:cosmic_structure]}%")
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(star_systems.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.where("star_systems.name ILIKE :q OR star_systems.description ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("star_systems.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        include_celestial_bodies = boolean_param(:include_celestial_bodies, default: false)

        data = records.map do |s|
          Serializer.star_system(s, include_embedding: include_embedding, include_celestial_bodies: include_celestial_bodies)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = StarSystem.includes(:cosmic_structure)
        scope = scope.where(cosmic_structure_id: params[:cosmic_structure_id]) if params[:cosmic_structure_id].present?

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |star_system|
              dist = star_system.try(:neighbor_distance)
              Serializer.star_system(star_system, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.where("star_systems.name ILIKE :q OR star_systems.description ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |star_system| Serializer.star_system(star_system) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.star_system(
            @star_system,
            include_embedding: boolean_param(:include_embedding, default: false),
            include_celestial_bodies: boolean_param(:include_celestial_bodies, default: true)
          )
        )
      end

      def create
        star_system = StarSystem.create!(star_system_params)
        render_success(Serializer.star_system(star_system), status: :created)
      end

      def update
        @star_system.update!(star_system_params)
        render_success(Serializer.star_system(@star_system))
      end

      def destroy
        @star_system.destroy!
        render_success({ id: @star_system.id, name: @star_system.name, deleted: true })
      end

      def neighbors
        unless @star_system.embedded?
          return render_error(code: "not_embedded", message: "Star system '#{@star_system.name}' does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = StarSystem.includes(:cosmic_structure).where.not(id: @star_system.id)
        scope = scope.where(cosmic_structure_id: params[:cosmic_structure_id]) if params[:cosmic_structure_id].present?

        neighbors = scope.nearest_neighbors(:embedding, @star_system.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.star_system(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { star_system_id: @star_system.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @star_system.generate_embedding!
          render_success(Serializer.star_system(@star_system, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("StarSystem", @star_system.id)
          render_success({ job_id: job.job_id, status: "queued", star_system_id: @star_system.id }, status: :accepted)
        end
      end

      def populate_celestial_bodies
        if sync_requested?
          result = PopulateCelestialBodiesJob.new.perform(star_system_id: @star_system.id)
          render_success({ message: "Celestial bodies populated for #{@star_system.name}", result: result })
        else
          job = PopulateCelestialBodiesJob.perform_later(star_system_id: @star_system.id)
          render_success({ job_id: job.job_id, status: "queued", star_system_id: @star_system.id }, status: :accepted)
        end
      end

      def populate
        cosmic_structure_id = params[:cosmic_structure_id].presence
        if sync_requested?
          result = PopulateStarSystemsJob.new.perform(cosmic_structure_id: cosmic_structure_id)
          render_success({ message: "Star systems populated", result: result })
        else
          job = PopulateStarSystemsJob.perform_later(cosmic_structure_id: cosmic_structure_id)
          render_success({ job_id: job.job_id, status: "queued", cosmic_structure_id: cosmic_structure_id }, status: :accepted)
        end
      end

      def upsert_batch
        cosmic_structure = CosmicStructure.find(params.require(:cosmic_structure_id))
        entries = params.require(:star_systems).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = StarSystem.upsert_batch!(cosmic_structure, entries)
        render_success(
          upserted.map { |s| Serializer.star_system(s) },
          meta: { cosmic_structure_id: cosmic_structure.id, count: upserted.size }
        )
      end

      private

      def set_star_system
        @star_system = StarSystem.includes(:cosmic_structure, :celestial_bodies).find(params[:id])
      end

      def star_system_params
        p = params.require(:star_system).permit(:cosmic_structure_id, :name, :description, themes: [])
        p[:themes] = StarSystem.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
