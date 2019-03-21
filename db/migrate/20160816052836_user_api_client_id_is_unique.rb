class UserApiClientIdIsUnique < ActiveRecord::Migration[4.2]
  def change
    remove_index :user_api_keys, %i[client_id]
    add_index :user_api_keys, %i[client_id], unique: true
  end
end
