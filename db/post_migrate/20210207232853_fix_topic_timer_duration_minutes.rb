# frozen_string_literal: true
class FixTopicTimerDurationMinutes < ActiveRecord::Migration[6.0]
  def up
    DB.exec("UPDATE topic_timers SET duration_minutes = (duration * 60 * 24) WHERE duration_minutes IS NULL AND status_type = 7 AND duration IS NOT NULL")
    DB.exec("UPDATE topic_timers SET duration_minutes = (duration * 60) WHERE duration_minutes IS NULL AND status_type != 7 AND duration IS NOT NULL")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
