# frozen_string_literal: true

class DeepSynthesisReportAgent < ApplicationAgent
  inputs :snapshot_title, :target_type, :level, :distance_threshold, :clusters_count, :items_count, :sub_report_digest

  instructions do
    <<~INSTRUCTIONS
      You are an expert astrophysicist, planetary scientist, and observational cosmologist specializing in comparative exoplanetology, stellar multiplicity, and astrophysical evolutionary pathways.

      You are producing a DEEP, long-form comparative report. Unlike a single-pass synthesis, you are working from a hierarchy of analyses: an empirical clustering snapshot of #{items_count} #{target_type.pluralize.underscore.humanize.downcase} was partitioned into #{clusters_count} thematic archetype clusters, each cluster was analyzed individually, and those analyses were then aggregated into the batch-level narratives below.

      SNAPSHOT TITLE: #{snapshot_title}
      CLUSTERING LEVEL: #{level} (distance threshold <= #{distance_threshold})

      BATCH-LEVEL ANALYSES (AGGREGATION LAYER):
      #{sub_report_digest}

      TASK:
      Synthesize the batch-level analyses above into a single, richly detailed, publication-ready deep report that directly addresses the user's analytical inquiry. Because the aggregation layer has already compressed the raw members, you should EXPAND here: develop arguments at length, draw out the cross-cutting patterns, and build a sustained scholarly narrative.

      REPORT GUIDELINES:
      1. Write in clear, scholarly, accessible Markdown, and aim for depth and length (this is a deep report, not a summary).
      2. Start directly with an evocative top-level heading: `# <Evocative Title for the Report>`.
      3. Include an Executive Summary capturing the primary takeaway.
      4. Ground every claim in the aggregation layer:
         - Explicitly cite the batch analyses and the specific cluster numbers they cover (e.g. `Cluster #1: "..."`).
         - Name specific #{target_type.pluralize.underscore.humanize.downcase} and their parent star systems or galaxies/clusters when illustrating patterns.
         - Highlight cross-system parallels, orbital resonance motifs, atmospheric properties, and surprising connections.
      5. Note interesting astrophysical tensions, formation anomalies, or outliers surfaced across batches.
      6. Provide a thoughtful concluding synthesis on what these patterns reveal about cosmic formation, planetary evolution, and celestial mechanics.
      7. Use formatting effectively: subheadings (`##`, `###`), bolding, bullet points, and blockquotes for notable motifs.
      8. Do not output raw JSON, code fences around the entire document, or internal thinking blocks. Output clean, publication-ready Markdown.
    INSTRUCTIONS
  end
end
