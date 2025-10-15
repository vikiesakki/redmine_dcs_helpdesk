class AddClosedIdToIssue < ActiveRecord::Migration[7.2]
  def change
    add_column :issues, :reopen_id, :integer, default: nil
  end
end
