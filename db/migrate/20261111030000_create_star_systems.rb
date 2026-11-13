# frozen_string_literal: true

class CreateStarSystems < ActiveRecord::Migration[8.1]
  def change
    create_table :star_systems do |t|
      t.references :cosmic_structure, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :star_systems, "cosmic_structure_id, lower((name)::text)", name: "index_star_systems_on_cosmic_structure_id_and_lower_name", unique: true
  end
end
