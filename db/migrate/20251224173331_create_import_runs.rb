class CreateImportRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :import_runs do |t|
      t.integer :total_lines, null: false, default: 0
      t.integer :successful_imports, null: false, default: 0
      t.integer :failed_imports, null: false, default: 0
      t.jsonb :validation_errors, null: false, default: []
      t.jsonb :warnings, null: false, default: []
      t.jsonb :statistics, null: false, default: {}
      t.string :status, null: false, default: 'pending'

      t.timestamps

      t.index :status
      t.index :created_at
    end
  end
end
