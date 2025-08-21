class AddIcIdToJournals < ActiveRecord::Migration[7.2]
  def change
    add_column :journals, :ic_id, :integer, default: nil
  end
end
