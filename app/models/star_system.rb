# frozen_string_literal: true

class StarSystem < ApplicationRecord
  include Embeddable

  belongs_to :cosmic_structure
  has_many :celestial_bodies, dependent: :destroy

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.strip }
  normalizes :themes, with: ->(value) { normalize_themes(value) }

  validates :name, presence: true, uniqueness: { scope: :cosmic_structure_id, case_sensitive: false }
  validates :description, presence: true
  validate :themes_must_be_string_array

  scope :ordered, -> { order(:name) }

  def embedding_input
    lines = [
      "Star System: #{name} (#{cosmic_structure.name})",
      "Description: #{description}"
    ]
    lines << "Themes: #{themes.join(', ')}" if themes.any?
    lines.join("\n")
  end

  # Returns [cosmic_structure, Array<StarSystem>] pairs ordered by cosmic structure name then star system name.
  def self.grouped_by_cosmic_structure
    includes(:cosmic_structure)
      .joins(:cosmic_structure)
      .order("cosmic_structures.name ASC, star_systems.name ASC")
      .group_by(&:cosmic_structure)
      .to_a
  end

  # Upserts an enumerable of { name:, description:, themes: } entries scoped to
  # the given cosmic structure, matching case-insensitively on normalized name.
  def self.upsert_batch!(cosmic_structure, entries)
    raise ArgumentError, "cosmic_structure must be present" if cosmic_structure.nil?

    transaction do
      Array(entries).filter_map do |entry|
        attrs = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : {}
        name = attrs[:name].to_s.squish
        description = attrs[:description].to_s.strip
        next if name.blank? || description.blank?

        themes = normalize_themes(attrs[:themes])
        upsert_one!(cosmic_structure: cosmic_structure, name: name, description: description, themes: themes)
      end
    end
  end

  def self.normalize_themes(value)
    items =
      case value
      when Array
        value
      when String
        value.split(",")
      else
        []
      end

    items.filter_map { |item| item.to_s.squish.presence }.uniq(&:downcase)
  end

  def self.upsert_one!(cosmic_structure:, name:, description:, themes:)
    scope = cosmic_structure.star_systems
    record = scope.where("LOWER(name) = ?", name.downcase).first_or_initialize
    record.assign_attributes(name: name, description: description, themes: themes)
    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = scope.where("LOWER(name) = ?", name.downcase).first!
    record.update!(name: name, description: description, themes: themes)
    record
  end
  private_class_method :upsert_one!

  private

  def themes_must_be_string_array
    unless themes.is_a?(Array) && themes.all? { |item| item.is_a?(String) && item.present? }
      errors.add(:themes, "must be a list of non-empty strings")
    end
  end
end
