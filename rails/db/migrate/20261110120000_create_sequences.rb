class CreateSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :sequences do |t|
      t.string :title, null: false, default: ""
      t.text :notes, null: false, default: ""
      # The template's kind and its own settings (spec 3.3), so the editor
      # reopens the same form. The intervals are rebuilt from them.
      t.string :kind, null: false
      t.json :settings, null: false, default: {}
      t.integer :rounds, null: false, default: 1
      t.float :prep_seconds, null: false, default: 10
      t.json :sound, null: false, default: {}
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :sequences, :position
  end
end
