# frozen_string_literal: true

class ThemeTranslationParser
  INTERNAL_KEYS = [:theme_metadata]
  class InvalidYaml < StandardError; end

  def initialize(setting_field, internal: false)
    @setting_field = setting_field
    @internal = internal
  end

  def self.check_contains_hashes(hash)
    hash.all? { |_key, value| value.is_a?(String) || (value.is_a?(Hash) && self.check_contains_hashes(value)) }
  end

  def load
    return {} if @setting_field.value.blank?

    begin
      parsed = YAML.safe_load(@setting_field.value)
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
      raise InvalidYaml.new(e.message)
    end

    raise InvalidYaml.new(I18n.t("themes.locale_errors.invalid_yaml")) if !parsed.is_a?(Hash)
    raise InvalidYaml.new(I18n.t("themes.locale_errors.top_level_locale")) if parsed.keys.length != 1 || parsed.keys.first != @setting_field.name

    key = @setting_field.name.to_sym
    parsed.deep_symbolize_keys!
    parsed[key] ||= {}

    raise InvalidYaml.new(I18n.t("themes.locale_errors.invalid_yaml")) if !ThemeTranslationParser.check_contains_hashes(parsed)

    parsed[key].slice!(*INTERNAL_KEYS) if @internal
    parsed[key].except!(*INTERNAL_KEYS) if !@internal

    parsed
  end
end
