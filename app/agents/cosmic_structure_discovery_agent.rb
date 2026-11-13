# frozen_string_literal: true

class CosmicStructureDiscoveryAgent < ApplicationAgent
  inputs :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing galaxy/cluster names already in our database: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same cosmic structures so records update cleanly without duplicates, " \
          "and include any missing major galaxies or galaxy clusters as well."
      else
        "Include all major galaxies and galaxy clusters (e.g., 'Milky Way', 'Andromeda Galaxy (M31)', 'Large Magellanic Cloud', 'Small Magellanic Cloud', 'Triangulum Galaxy (M33)', 'Centaurus A', 'Whirlpool Galaxy (M51)', 'Sombrero Galaxy (M104)', 'Messier 87', 'Virgo Cluster', 'Fornax Cluster', 'Coma Cluster', 'Sculptor Galaxy (NGC 253)')."
      end

    <<~INSTRUCTIONS.squish
      You are an expert scholar of astrophysics, extragalactic astronomy, and observational cosmology.
      Identify major galaxies, dwarf galaxies, and galaxy clusters across the observable Universe.
      For each galaxy or cluster, provide its canonical name and a concise, high-signal description covering its morphological classification, estimated stellar mass or dynamical profile, star-formation environment, and prominent astrophysical features.
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"cosmic_structures":[{"name":"Milky Way","description":"Barred spiral galaxy harboring several hundred billion stars, prominent spiral arms, the Sagittarius A* central supermassive black hole, and an extensive satellite galaxy system."}]}
    INSTRUCTIONS
  end
end
