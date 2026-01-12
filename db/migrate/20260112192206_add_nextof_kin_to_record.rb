class AddNextofKinToRecord < ActiveRecord::Migration[8.0]
  def change
    add_column :records, :next_of_kin, :jsonb, default: {}
  end
end
