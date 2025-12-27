class RemoveFailedImportsFromImportRun < ActiveRecord::Migration[8.0]
  def change
    remove_column :import_runs, :failed_imports, :integer
  end
end
