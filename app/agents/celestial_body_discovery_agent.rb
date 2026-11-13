# frozen_string_literal: true

class CelestialBodyDiscoveryAgent < ApplicationAgent
  inputs :star_system_name, :star_system_description, :star_system_themes, :cosmic_structure_name, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing celestial body names already in our database for this star system: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same celestial bodies so records update cleanly without duplicates, " \
          "and include any missing key bodies as well."
      else
        "Identify 6 to 10 major, scientifically prominent, or archetypal celestial bodies in this star system (planets, major moons, dwarf planets, stellar remnants, or circumstellar features)."
      end

    themes_list = Array(star_system_themes).compact_blank
    themes_clause = themes_list.any? ? "Star system thematic tags: #{themes_list.join(', ')}." : ""
    desc_clause = star_system_description.present? ? "Star system context: #{star_system_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert planetary scientist, astrophysicist, and comparative planetologist.
      Identify 6 to 10 major, scientifically significant, or archetypal celestial bodies (planets, exoplanets, major planetary moons, dwarf planets, substellar companions, or compact remnants) in #{star_system_name} (#{cosmic_structure_name}).
      Ensure representation of primary terrestrial worlds, gas or ice giants, ocean worlds or habitable-zone candidates, or notable compact companions.
      #{desc_clause}
      #{themes_clause}
      #{existing_clause}

      For each celestial body, provide:
      1. Its canonical common or astronomical designation (e.g., 'TRAPPIST-1e', 'Jupiter', 'Europa', 'Titan').
      2. A concise, informative description covering its physical composition, orbital parameters, atmospheric profile, surface/subsurface conditions, and planetary classification.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["temperate terrestrial planet", "habitable zone candidate", "tidally locked", "secondary atmosphere potential"]).

      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"celestial_bodies":[{"name":"TRAPPIST-1e","description":"Temperate Earth-sized terrestrial exoplanet orbiting within the liquid-water habitable zone with an Earth-like density and potential iron core.","themes":["temperate terrestrial planet","habitable zone candidate","rocky exoplanet","tidally locked"]}]}
    INSTRUCTIONS
  end
end
