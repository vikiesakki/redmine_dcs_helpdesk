class CreateChatEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :chat_emails do |t|
      t.integer :issue_id
      t.string :customer_email
      t.string :added_str
      t.string :name
      
      t.timestamps
    end
  end
end
