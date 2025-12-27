class RenameSuccessfulImportsToSuccessfulRecordsInImportRun < ActiveRecord::Migration[8.0]
  def change
    rename_column :import_runs, :successful_imports, :successful_records
  end
end
