# frozen_string_literal: true

class DirectoryColumnsController < ApplicationController
  requires_login

  def index
    raise Discourse::InvalidAccess unless guardian.is_staff?

    ensure_user_fields_have_columns

    columns = DirectoryColumn.includes(:user_field).all
    render_json_dump(directory_columns: serialize_data(columns, DirectoryColumnSerializer))
  end

  private

  def ensure_user_fields_have_columns
    user_fields_without_column =
      UserField.left_outer_joins(:directory_column).where(directory_column: { user_field_id: nil })

    return unless user_fields_without_column.count > 0

    next_position = DirectoryColumn.maximum("position") + 1

    new_directory_column_attrs = []
    user_fields_without_column.each do |user_field|
      new_directory_column_attrs.push({
        user_field_id: user_field.id,
        enabled: false,
        automatic: false,
        position: next_position
      })

      next_position += 1
    end

    DirectoryColumn.insert_all(new_directory_column_attrs)
  end
end
