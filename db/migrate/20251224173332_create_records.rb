class CreateRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :records do |t|
      t.references :import_run, null: false, foreign_key: true
      t.string :resource_id, null: false
      t.string :resource_type, null: false
      t.string :subject_reference
      t.jsonb :extracted_data, null: false, default: {}
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps

      t.index [ :resource_id, :resource_type ], unique: true, name: 'index_record_on_resource_id_and_type'

      # Composite indexes for common queries
      t.index [ :resource_type, :subject_reference ], name: 'index_record_on_type_and_subject'
      t.index :resource_type
      t.index :subject_reference
      t.index :extracted_data, using: :gin
    end
  end
end
