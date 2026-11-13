# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for StarSystem snapshot" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system1 = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.", themes: [ "republic", "nuclear" ])
    star_system2 = StarSystem.create!(cosmic_structure: europe, name: "Germany", description: "Central European federal state.", themes: [ "federal", "manufacturing" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "StarSystem",
      level: 5,
      distance_threshold: 0.20,
      title: "European Powers",
      clusters_count: 1,
      items_count: 2
    )

    group = snapshot.cluster_groups.create!(name: "CosmicStructureal Heavyweights", shared_themes: [ "federal", "republic" ], size: 2)
    group.cluster_memberships.create!(record: star_system1)
    group.cluster_memberships.create!(record: star_system2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "European Powers"
    assert_includes digest, "Target Type: StarSystem"
    assert_includes digest, "CosmicStructureal Heavyweights"
    assert_includes digest, "France (Europe)"
    assert_includes digest, "Germany (Europe)"
  end

  test "builds digest for CelestialBody snapshot" do
    europe = CosmicStructure.create!(name: "Europe", description: "European cosmic_structure.")
    star_system = StarSystem.create!(cosmic_structure: europe, name: "France", description: "Western European republic.")
    celestial_body = CelestialBody.create!(star_system: star_system, name: "Marseille", description: "Mediterranean port gateway.", themes: [ "port", "trade" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "CelestialBody",
      level: 10,
      distance_threshold: 0.25,
      title: "CelestialBody Clusters",
      clusters_count: 1,
      items_count: 1
    )

    group = snapshot.cluster_groups.create!(name: "Maritime Trade Gateways", shared_themes: [ "port" ], size: 1)
    group.cluster_memberships.create!(record: celestial_body)

    report = snapshot.cluster_reports.create!(prompt: "Analyze trade hubs")
    report.cluster_report_summaries.create!(
      cluster_group: group,
      content: "This cluster focuses on sovereign deepwater ports and trade logistics.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: CelestialBody"
    assert_includes digest, "Marseille (France, Europe)"
    assert_includes digest, "Mediterranean port gateway"
    assert_includes digest, "Prompt-Guided Cluster Analysis:"
    assert_includes digest, "sovereign deepwater ports and trade logistics"
  end
end
