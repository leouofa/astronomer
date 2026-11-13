# frozen_string_literal: true

class CreateCosmicStructures < ActiveRecord::Migration[8.1]
  def change
    create_table :cosmic_structures do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :cosmic_structures, "lower((name)::text)", name: "index_cosmic_structures_on_lower_name", unique: true
  end
end
