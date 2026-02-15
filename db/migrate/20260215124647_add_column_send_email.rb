class AddColumnSendEmail < ActiveRecord::Migration[7.2]
  def change
    add_column :issue_customers, :send_email, :boolean, default: false
  end
end
