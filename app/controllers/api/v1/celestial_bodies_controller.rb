# frozen_string_literal: true

module Api
  module V1
    class CelestialBodiesController < BaseController
      before_action :set_celestial_body, only: %i[show update destroy neighbors generate_embedding]

      def index
        scope = CelestialBody.includes(star_system: :cosmic_structure)
        scope = scope.where(star_system_id: params[:star_system_id]) if params[:star_system_id].present?
        if params[:cosmic_structure_id].present?
          scope = scope.joins(:star_system).where(star_systems: { cosmic_structure_id: params[:cosmic_structure_id] })
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(celestial_bodies.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.joins(:star_system).where("celestial_bodies.name ILIKE :q OR celestial_bodies.description ILIKE :q OR star_systems.name ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("celestial_bodies.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        data = records.map do |b|
          Serializer.celestial_body(b, include_embedding: include_embedding, include_star_system: true)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = CelestialBody.includes(star_system: :cosmic_structure)
        scope = scope.where(star_system_id: params[:star_system_id]) if params[:star_system_id].present?
        if params[:cosmic_structure_id].present?
          scope = scope.joins(:star_system).where(star_systems: { cosmic_structure_id: params[:cosmic_structure_id] })
        end

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |celestial_body|
              dist = celestial_body.try(:neighbor_distance)
              Serializer.celestial_body(celestial_body, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.joins(:star_system)
                               .where("celestial_bodies.name ILIKE :q OR celestial_bodies.description ILIKE :q OR star_systems.name ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |b| Serializer.celestial_body(b) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.celestial_body(@celestial_body, include_embedding: boolean_param(:include_embedding, default: false), include_star_system: true)
        )
      end

      def create
        star_system = StarSystem.find(params.require(:celestial_body).require(:star_system_id))
        celestial_body = star_system.celestial_bodies.create!(celestial_body_params)
        render_success(Serializer.celestial_body(celestial_body), status: :created)
      end

      def update
        @celestial_body.update!(celestial_body_params)
        render_success(Serializer.celestial_body(@celestial_body))
      end

      def destroy
        @celestial_body.destroy!
        render_success({ id: @celestial_body.id, star_system_id: @celestial_body.star_system_id, deleted: true })
      end

      def neighbors
        unless @celestial_body.embedded?
          return render_error(code: "not_embedded", message: "Celestial body does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = CelestialBody.includes(star_system: :cosmic_structure).where.not(id: @celestial_body.id)
        scope = scope.where(star_system_id: params[:star_system_id]) if params[:star_system_id].present?
        if params[:cosmic_structure_id].present?
          scope = scope.joins(:star_system).where(star_systems: { cosmic_structure_id: params[:cosmic_structure_id] })
        end

        neighbors = scope.nearest_neighbors(:embedding, @celestial_body.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.celestial_body(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { celestial_body_id: @celestial_body.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @celestial_body.generate_embedding!
          render_success(Serializer.celestial_body(@celestial_body, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("CelestialBody", @celestial_body.id)
          render_success({ job_id: job.job_id, status: "queued", celestial_body_id: @celestial_body.id }, status: :accepted)
        end
      end

      def populate
        star_system_id = params[:star_system_id].presence
        if sync_requested?
          result = PopulateCelestialBodiesJob.new.perform(star_system_id: star_system_id)
          render_success({ message: "Celestial bodies populated", result: result })
        else
          job = PopulateCelestialBodiesJob.perform_later(star_system_id: star_system_id)
          render_success({ job_id: job.job_id, status: "queued", star_system_id: star_system_id }, status: :accepted)
        end
      end

      def upsert_batch
        star_system = StarSystem.find(params.require(:star_system_id))
        entries = params.require(:celestial_bodies).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = CelestialBody.upsert_batch!(star_system, entries)
        render_success(
          upserted.map { |b| Serializer.celestial_body(b) },
          meta: { star_system_id: star_system.id, count: upserted.size }
        )
      end

      private

      def set_celestial_body
        @celestial_body = CelestialBody.includes(star_system: :cosmic_structure).find(params[:id])
      end

      def celestial_body_params
        p = params.require(:celestial_body).permit(:star_system_id, :name, :description, themes: [])
        p[:themes] = CelestialBody.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
