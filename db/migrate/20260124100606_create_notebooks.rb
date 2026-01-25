class CreateNotebooks < ActiveRecord::Migration[8.0]
  def change
    create_table :notebooks do |t|
      t.string :file_path, null: false
      t.string :title, null: false, default: "Untitled notebook"
      t.string :format, null: false, default: "runemd"
      t.integer :version, null: false, default: 1
      t.boolean :dirty, null: false, default: false
      t.integer :autosave_interval, default: 30000
      t.datetime :last_saved_at

      t.timestamps
    end

    add_index :notebooks, :file_path, unique: true
  end
end
