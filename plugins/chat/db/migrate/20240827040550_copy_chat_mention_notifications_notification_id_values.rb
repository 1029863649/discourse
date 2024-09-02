# frozen_string_literal: true
class CopyChatMentionNotificationsNotificationIdValues < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    min_id, max_id =
      execute("SELECT MIN(notification_id), MAX(notification_id) FROM chat_mention_notifications")[
        0
      ].values
    batch_size = 10_000

    (min_id..max_id).step(batch_size) { |start_id| execute <<~SQL.squish } if min_id && max_id
        UPDATE chat_mention_notifications
        SET new_notification_id = notification_id
        WHERE notification_id >= #{start_id} AND notification_id < #{start_id + batch_size} AND new_notification_id != notification_id
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
