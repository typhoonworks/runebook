class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :notebook, null: false, foreign_key: true
      t.string :token, null: false
      t.string :status, null: false, default: "open"
      t.integer :pid
      t.datetime :started_at
      t.datetime :last_evaluation_at
      t.integer :evaluation_count, default: 0
      t.boolean :setup_cell_evaluated, default: false

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, :last_evaluation_at
  end
end
