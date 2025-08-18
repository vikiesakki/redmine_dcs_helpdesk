class AddColumnNameOnIssueCustomers < ActiveRecord::Migration[7.2]
  def change
    add_column :issue_customers, :name, :string
  end
end
