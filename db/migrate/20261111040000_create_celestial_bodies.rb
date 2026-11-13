# frozen_string_literal: true

class CreateCelestialBodies < ActiveRecord::Migration[8.1]
  def change
    create_table :celestial_bodies do |t|
      t.references :star_system, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :celestial_bodies, "star_system_id, lower((name)::text)", name: "index_celestial_bodies_on_star_system_id_and_lower_name", unique: true
  end
end
