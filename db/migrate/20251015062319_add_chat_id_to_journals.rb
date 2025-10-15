class AddChatIdToJournals < ActiveRecord::Migration[7.2]
  def change
    add_column :journals, :chat_id, :integer, default: nil
  end
end
