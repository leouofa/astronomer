# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @cosmic_structures = CosmicStructure.ordered
  end

  def star_systems
    @cosmic_structure_groups = StarSystem.grouped_by_cosmic_structure
    @total_star_systems_count = StarSystem.count
    @cosmic_structures_count = CosmicStructure.count
  end

  def celestial_bodies
    @star_system_groups = CelestialBody.grouped_by_star_system
    @total_celestial_bodies_count = CelestialBody.count
    @star_systems_count = StarSystem.count
  end
end
