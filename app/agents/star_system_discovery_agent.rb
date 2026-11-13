# frozen_string_literal: true

class StarSystemDiscoveryAgent < ApplicationAgent
  inputs :cosmic_structure_name, :cosmic_structure_description, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing star system names already in our database for this cosmic structure: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same star systems so records update cleanly without duplicates, " \
          "and include any missing notable stellar systems as well."
      else
        "Use clear, canonical star system names (e.g., 'Solar System', 'TRAPPIST-1', 'Alpha Centauri', 'Kepler-90', 'Proxima Centauri', 'Cygnus X-1', 'PSR B1257+12', 'Betelgeuse', 'M51-ULS-1')."
      end

    context_clause = cosmic_structure_description.present? ? "Cosmic structure context: #{cosmic_structure_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert scholar of astrophysics, stellar astrophysics, and exoplanetary systems.
      Identify major and notable star systems, exoplanet host stars, binary or multiple stellar configurations, pulsar systems, X-ray binaries, or extreme stellar systems belonging to or associated with #{cosmic_structure_name}.
      #{context_clause}
      For each star system, provide:
      1. Its canonical common or astronomical catalog name.
      2. A concise, informative description covering its stellar spectral type(s), multiplicity, evolutionary stage, notable circumstellar architectures, and exoplanetary or high-energy characteristics.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["ultra-cool red dwarf", "compact resonant chain", "habitable zone exoplanets", "high-flare activity"]).
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"star_systems":[{"name":"TRAPPIST-1","description":"Ultra-cool red dwarf star hosting a resonant compact system of seven Earth-sized terrestrial exoplanets with high transit-timing variations.","themes":["ultra-cool red dwarf","compact resonant chain","habitable zone exoplanets","transit spectroscopy"]}]}
    INSTRUCTIONS
  end
end
