# frozen_string_literal: true

# On initialize, reset flags cache
Rails.application.config.to_prepare do
  if Discourse.cache.is_a?(Cache) && ActiveRecord::Base.connection.table_exists?(:flags)
    Flag.reset_flag_settings!
  end
end
