# frozen_string_literal: true

module Clustering
  # Serializes clusters in a ClusterSnapshot into a rich, structured,
  # token-budget-aware text digest for comparative LLM reporting.
  # Can embed prompt-guided ClusterReportSummary records when available.
  class SnapshotDigestBuilder
    DEFAULT_MAX_CHARS = 120_000

    def self.call(snapshot, report: nil, max_chars: nil)
      budget = max_chars || Llm::ModelRegistry.digest_char_budget
      new(snapshot, report: report, max_chars: budget).call
    end

    def self.format_full_group_detail(group, target_type:, max_chars: 50_000)
      memberships = group.cluster_memberships.to_a
      return "  (none)" if memberships.empty?

      lines = []
      memberships.each_with_index do |m, idx|
        record = m.record
        next unless record

        lines << case target_type
        when "StarSystem"
          format_full_star_system_member(record, idx + 1)
        when "CelestialBody"
          format_full_celestial_body_member(record, idx + 1)
        else
          "#{idx + 1}. Record ##{record.id}"
        end
      end

      full_text = lines.join("\n\n")
      if full_text.length > max_chars
        full_text.truncate(max_chars, omission: "\n\n... [Remaining members truncated to fit cluster analysis budget] ...")
      else
        full_text
      end
    end

    def initialize(snapshot, report: nil, max_chars: DEFAULT_MAX_CHARS)
      @snapshot = snapshot
      @report = report
      @max_chars = max_chars
    end

    def call
      groups = @snapshot.cluster_groups.by_size.includes(cluster_memberships: eager_associations)
      target_type = @snapshot.target_type

      # Preload report summaries if report is given
      summaries_by_group_id = if @report.present?
        @report.cluster_report_summaries.index_by(&:cluster_group_id)
      else
        {}
      end

      # Compute overall cosmic structure coverage
      structure_counts = Hash.new(0)
      groups.each do |group|
        group.cluster_memberships.each do |m|
          record = m.record
          next unless record

          c_name = record_cosmic_structure_name(record)
          structure_counts[c_name] += 1 if c_name.present?
        end
      end

      top_structures = structure_counts.sort_by { |_, c| -c }.first(12)
        .map { |name, count| "#{name} (#{count})" }.join(", ")

      header = <<~HEADER
        === CLUSTER SNAPSHOT OVERVIEW ===
        Title: #{@snapshot.title}
        Target Type: #{target_type}
        Clustering Level: #{@snapshot.level} (distance threshold <= #{@snapshot.distance_threshold})
        Total Clusters: #{@snapshot.clusters_count}
        Total Persisted Items: #{@snapshot.items_count}
        Represented Cosmic Structures: #{top_structures.presence || 'None'}
        Generated At: #{@snapshot.created_at.strftime('%Y-%m-%d %H:%M UTC')}
        Prompt-Guided Cluster Summaries Included: #{summaries_by_group_id.any? ? "Yes (#{summaries_by_group_id.size}/#{groups.size})" : "No"}
        =================================

        CLUSTERS (#{groups.size} total):
      HEADER

      char_budget_remaining = @max_chars - header.length
      cluster_blocks = []

      # Allocate per-cluster member details budget
      budget_per_group = [ (char_budget_remaining / [ groups.size, 1 ].max).to_i, 500 ].max

      groups.each_with_index do |group, idx|
        summary = summaries_by_group_id[group.id]
        cluster_blocks << format_cluster(
          group,
          rank: idx + 1,
          target_type: target_type,
          summary: summary,
          member_budget: budget_per_group
        )
      end

      full_digest = ([ header.strip ] + cluster_blocks).join("\n\n")
      if full_digest.length > @max_chars
        full_digest.truncate(@max_chars, omission: "\n\n... [Digest truncated to fit context budget] ...")
      else
        full_digest
      end
    end

    private

    def eager_associations
      case @snapshot.target_type
      when "StarSystem"
        { record: :cosmic_structure }
      when "CelestialBody"
        { record: { star_system: :cosmic_structure } }
      else
        :record
      end
    end

    def record_cosmic_structure_name(record)
      case record
      when StarSystem then record.cosmic_structure&.name
      when CelestialBody then record.star_system&.cosmic_structure&.name
      end
    end

    def format_cluster(group, rank:, target_type:, summary:, member_budget:)
      group_structures = Hash.new(0)
      memberships = group.cluster_memberships.to_a

      memberships.each do |m|
        next unless m.record

        c_name = record_cosmic_structure_name(m.record)
        group_structures[c_name] += 1 if c_name.present?
      end

      structure_dist = group_structures.sort_by { |_, c| -c }
        .map { |name, count| "#{name}: #{count}" }.join(", ")

      themes_str = group.shared_themes.presence ? group.shared_themes.join(", ") : "None specified"

      lines = [
        "### Cluster ##{rank}: \"#{group.name}\"",
        "Size: #{group.size} #{target_type.pluralize.underscore.humanize.downcase}",
        "Dominant Galaxies/Clusters: #{structure_dist.presence || 'None'}",
        "Shared Themes: #{themes_str}"
      ]

      if summary.present? && summary.content.present?
        lines << "Prompt-Guided Cluster Analysis:"
        lines << summary.content.strip
      end

      lines << "Members:"
      members_text = format_members(memberships, target_type: target_type, budget: member_budget)
      lines << members_text

      lines.join("\n")
    end

    def format_members(memberships, target_type:, budget:)
      return "  (none)" if memberships.empty?

      member_lines = []
      used_chars = 0

      memberships.each_with_index do |m, idx|
        record = m.record
        next unless record

        line = case target_type
        when "StarSystem"
          format_star_system_member(record)
        when "CelestialBody"
          format_celestial_body_member(record)
        else
          "  - #{record.id}"
        end

        if used_chars + line.length > budget && idx < memberships.size - 1
          remaining = memberships.size - idx
          member_lines << "  - ... and #{remaining} more #{target_type.pluralize.underscore.humanize.downcase}"
          break
        end

        member_lines << line
        used_chars += line.length
      end

      member_lines.join("\n")
    end

    def format_star_system_member(star_system)
      cs_name = star_system.cosmic_structure&.name || "Unknown Galaxy/Cluster"
      themes_str = star_system.themes.presence ? " [themes: #{star_system.themes.first(4).join(', ')}]" : ""
      desc_snippet = star_system.description.to_s.squish.truncate(100)
      "  - #{star_system.name} (#{cs_name})#{themes_str}: #{desc_snippet}"
    end

    def format_celestial_body_member(body)
      system_name = body.star_system&.name || "Unknown Star System"
      cs_name = body.star_system&.cosmic_structure&.name || "Unknown Galaxy/Cluster"
      themes_str = body.themes.presence ? " [themes: #{body.themes.first(4).join(', ')}]" : ""
      desc_snippet = body.description.to_s.squish.truncate(100)

      "  - #{body.name} (#{system_name}, #{cs_name})#{themes_str}: #{desc_snippet}"
    end

    def self.format_full_star_system_member(star_system, index)
      cs_name = star_system.cosmic_structure&.name || "Unknown Galaxy/Cluster"
      themes_str = star_system.themes.presence ? star_system.themes.join(", ") : "None"
      <<~SYSTEM.strip
        [#{index}] #{star_system.name} (#{cs_name})
        Themes: #{themes_str}
        Description: #{star_system.description}
      SYSTEM
    end

    def self.format_full_celestial_body_member(body, index)
      system_name = body.star_system&.name || "Unknown Star System"
      cs_name = body.star_system&.cosmic_structure&.name || "Unknown Galaxy/Cluster"
      themes_str = body.themes.presence ? body.themes.join(", ") : "None"

      <<~BODY.strip
        [#{index}] #{body.name} (#{system_name}, #{cs_name})
        Themes: #{themes_str}
        Description: #{body.description}
      BODY
    end
  end
end
