# frozen_string_literal: true

class UserCustomField < ActiveRecord::Base
  belongs_to :user

  scope :searchable, -> { joins("INNER JOIN user_fields ON user_fields.id = REPLACE(user_custom_fields.name, 'user_field_', '')::INTEGER AND user_fields.searchable IS TRUE AND user_custom_fields.name like 'user_field_%'") }
end

# == Schema Information
#
# Table name: user_custom_fields
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  idx_user_custom_fields_last_reminded_at          (name,user_id) UNIQUE WHERE ((name)::text = 'last_reminded_at'::text)
#  idx_user_custom_fields_remind_assigns_frequency  (name,user_id) UNIQUE WHERE ((name)::text = 'remind_assigns_frequency'::text)
#  idx_user_custom_fields_user_notes_count          (name,user_id) UNIQUE WHERE ((name)::text = 'user_notes_count'::text)
#  index_user_custom_fields_on_user_id_and_name     (user_id,name)
#
