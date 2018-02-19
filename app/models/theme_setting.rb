class ThemeSetting < ActiveRecord::Base
  belongs_to :theme

  validates_presence_of :name, :theme
  validates :data_type, numericality: { only_integer: true }
  validates :name, length: { maximum: 255 }

  after_save do
    theme.clear_cached_settings!
  end

  def self.types
    @types ||= Enum.new(integer: 0, string: 1, bool: 2, list: 3, enum: 4)
  end

  def self.acceptable_value_for_type?(value, type)
    case type
    when self.types[:integer]
      value.is_a?(Integer)
    when self.types[:bool]
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    when self.types[:list]
      value.is_a?(String)
    else
      true
    end
  end

  def self.value_in_range?(value, range, type)
    if type == self.types[:integer]
      range.include? value
    elsif type == self.types[:string]
      range.include? value.to_s.length
    end
  end

  def self.guess_type(value)
    case value
    when Integer
      types[:integer]
    when String
      types[:string]
    when TrueClass, FalseClass
      types[:bool]
    end
  end
end

# == Schema Information
#
# Table name: theme_settings
#
#  id         :integer          not null, primary key
#  name       :string(255)      not null
#  data_type  :integer          not null
#  value      :string
#  theme_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_theme_settings_on_theme_id  (theme_id)
#
