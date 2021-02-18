# frozen_string_literal: true

class AddIsFavoriteToUserBadge < ActiveRecord::Migration[6.0]
  def change
    add_column :user_badges, :is_favorite, :boolean
    add_index :user_badges, :is_favorite
  end
end
