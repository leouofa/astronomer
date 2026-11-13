# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        target_type = params[:target_type].to_s.downcase.presence || "all"
        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        star_systems_scope = StarSystem.includes(:cosmic_structure)
        celestial_bodies_scope = CelestialBody.includes(star_system: :cosmic_structure)

        if (mode == "semantic" || mode == "auto") && (star_systems_scope.where.not(embedding: nil).exists? || celestial_bodies_scope.where.not(embedding: nil).exists?)
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            star_system_results = []
            if %w[all star_system star_systems].include?(target_type)
              star_system_results = star_systems_scope.where.not(embedding: nil)
                                                      .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                                      .limit(limit)
                                                      .map do |sys|
                                                        {
                                                          type: "StarSystem",
                                                          score: 1.0 - sys.try(:neighbor_distance).to_f,
                                                          data: Serializer.star_system(sys, neighbor_distance: sys.try(:neighbor_distance))
                                                        }
                                                      end
            end

            celestial_body_results = []
            if %w[all celestial_body celestial_bodies].include?(target_type)
              celestial_body_results = celestial_bodies_scope.where.not(embedding: nil)
                                                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                                             .limit(limit)
                                                             .map do |body|
                                                               {
                                                                 type: "CelestialBody",
                                                                 score: 1.0 - body.try(:neighbor_distance).to_f,
                                                                 data: Serializer.celestial_body(body, neighbor_distance: body.try(:neighbor_distance))
                                                               }
                                                             end
            end

            combined = (star_system_results + celestial_body_results).sort_by { |item| -item[:score] }.take(limit)
            return render_success(combined, meta: { mode: "semantic", query: query, count: combined.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        # Keyword fallback
        star_system_kw = []
        if %w[all star_system star_systems].include?(target_type)
          star_system_kw = star_systems_scope.where("star_systems.name ILIKE :q OR star_systems.description ILIKE :q", q: "%#{query}%")
                                             .limit(limit)
                                             .map { |s| { type: "StarSystem", data: Serializer.star_system(s) } }
        end

        celestial_body_kw = []
        if %w[all celestial_body celestial_bodies].include?(target_type)
          celestial_body_kw = celestial_bodies_scope.joins(:star_system)
                                                    .where("celestial_bodies.name ILIKE :q OR celestial_bodies.description ILIKE :q OR star_systems.name ILIKE :q", q: "%#{query}%")
                                                    .limit(limit)
                                                    .map { |b| { type: "CelestialBody", data: Serializer.celestial_body(b) } }
        end

        combined = (star_system_kw + celestial_body_kw).take(limit)
        render_success(combined, meta: { mode: "keyword", query: query, count: combined.size })
      end
    end
  end
end
