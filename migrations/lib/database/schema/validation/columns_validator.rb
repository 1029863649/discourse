# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class ColumnsValidator < BaseValidator
    def validate(table_name)
      @table_name = table_name
      columns = @schema_config[:tables][table_name.to_sym][:columns]

      @existing_column_names = @db.columns(@table_name).map { |c| c.name }
      @added_column_names = columns[:add]&.map { |column| column[:name] } || []
      @included_column_names = columns[:include] || []
      @excluded_column_names = columns[:exclude] || []
      @modified_column_names = columns[:modify]&.map { |column| column[:name] } || []

      validated_added_columns
      validate_included_columns
      validate_excluded_columns
      validate_modified_columns
      validate_column_usage
    end

    private

    def validated_added_columns
      if (column_names = @existing_column_names & @added_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.added_columns_exist",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_included_columns
      if (column_names = @included_column_names - @existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.included_columns_missing",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_excluded_columns
      if (column_names = @excluded_column_names - @existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.excluded_columns_missing",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_modified_columns
      if (column_names = @modified_column_names - @existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_missing",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = @modified_column_names & @included_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_included",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = @modified_column_names & @excluded_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_excluded",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_column_usage
      global = ::Migrations::Database::Schema::GlobalConfig.new(@schema_config)

      column_names =
        if @excluded_column_names.empty?
          @existing_column_names - @included_column_names - @modified_column_names -
            global.excluded_column_names.to_a + @added_column_names
        else
          @existing_column_names - @excluded_column_names + @modified_column_names -
            global.excluded_column_names.to_a + @added_column_names
        end

      if column_names.empty?
        @errors << I18n.t(
          "schema.validator.tables.no_columns_configured",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      else
        @errors << I18n.t(
          "schema.validator.tables.not_all_columns_configured",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end
  end
end
