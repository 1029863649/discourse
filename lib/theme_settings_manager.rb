class ThemeSettingsManager
  attr_reader :name, :theme, :default

  def self.types
    ThemeSetting.types
  end

  def self.create(name, default, type, theme, opts = {})
    type_name = self.types.invert[type].downcase.capitalize
    klass = "ThemeSettingsManager::#{type_name}".constantize
    klass.new(name, default, theme, opts)
  end

  def initialize(name, default, theme, opts = {})
    @name = name.to_sym
    @default = default
    @theme = theme
    @opts = opts
  end

  def value
    has_record? ? db_record.value : @default
  end

  def type_name
    self.class.name.demodulize.downcase.to_sym
  end

  def type
    ThemeSetting.types[type_name]
  end

  def description
    @opts[:description]
  end

  def db_record
    ThemeSetting.where(name: @name, data_type: type, theme: @theme).first
  end

  def has_record?
    db_record.present?
  end

  def create_record!
    record = ThemeSetting.new(name: @name, data_type: type, theme: @theme)
    record.save!
    record
  end

  def value=(new_value)
    ensure_is_valid_value!(new_value)

    record = has_record? ? db_record : create_record!
    record.value = new_value.to_s
    record.save!
    record.value
  end

  def is_valid_value?(new_value)
    true
  end

  def invalid_value_error_message
    primary_key = "themes.settings_errors.#{self.type_name}_value_not_valid"
    secondary_key = primary_key

    min = @opts[:min]
    max = @opts[:max]

    secondary_key += "_min" if min.is_a?(::Integer)
    secondary_key += "_max" if max.is_a?(::Integer)

    translation = I18n.t(primary_key)
    translation += " #{I18n.t(secondary_key, min: min, max: max)}" if secondary_key != primary_key
    translation
  end

  def ensure_is_valid_value!(new_value)
    unless is_valid_value?(new_value)
      raise Discourse::InvalidParameters.new invalid_value_error_message
    end
  end

  class List    < self; end
  class String  < self
    def is_valid_value?(new_value)
      (@opts[:min]..@opts[:max]).include? new_value.to_s.length
    end
  end

  class Bool < self
    def value
      [true, "true"].include?(super)
    end

    def value=(new_value)
      new_value = ([true, "true"].include?(new_value)).to_s
      super(new_value)
    end
  end

  class Integer < self
    def value
      super.to_i
    end

    def value=(new_value)
      super(new_value.to_i)
    end

    def is_valid_value?(new_value)
      (@opts[:min]..@opts[:max]).include? new_value.to_i
    end
  end

  class Enum < self
    def value
      val = super
      match = choices.find { |choice| choice == val || choice.to_s == val }
      match || val
    end

    def is_valid_value?(new_value)
      choices.include?(new_value) || choices.map(&:to_s).include?(new_value)
    end

    def choices
      @opts[:choices]
    end
  end
end
