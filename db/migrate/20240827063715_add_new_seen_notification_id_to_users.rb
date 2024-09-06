# frozen_string_literal: true
class AddNewSeenNotificationIdToUsers < ActiveRecord::Migration[7.1]
  def up
    # Create new column
    execute "ALTER TABLE users ADD COLUMN new_seen_notification_id BIGINT NOT NULL DEFAULT(0)"

    # Mirror new `seen_notification_id` values to `new_seen_notification_id`
    execute <<~SQL.squish
      CREATE FUNCTION mirror_users_seen_notification_id()
      RETURNS trigger AS
      $$
      BEGIN
        NEW.new_seen_notification_id = NEW.seen_notification_id;
        RETURN NEW;
      END;
      $$
      LANGUAGE plpgsql
    SQL

    execute <<~SQL.squish
      CREATE TRIGGER users_seen_notification_id_trigger BEFORE INSERT OR UPDATE ON users
      FOR EACH ROW EXECUTE PROCEDURE mirror_users_seen_notification_id()
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
