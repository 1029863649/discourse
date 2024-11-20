# frozen_string_literal: true

require "migration/base_dropper"

class DbHelper
  REMAP_SQL = <<~SQL
    SELECT table_name::text, column_name::text, character_maximum_length
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND is_updatable = 'YES'
       AND (data_type LIKE 'char%' OR data_type LIKE 'text%')
  ORDER BY table_name, column_name
  SQL

  TRIGGERS_SQL = <<~SQL
    SELECT trigger_name::text
      FROM information_schema.triggers
     WHERE trigger_name LIKE '%_readonly'
  SQL

  TRUNCATABLE_COLUMNS = ["topic_links.url"]

  def self.remap(
    from,
    to,
    anchor_left: false,
    anchor_right: false,
    excluded_tables: [],
    verbose: false,
    skip_max_length_violations: false
  )
    text_columns = find_text_columns(excluded_tables)

    return if text_columns.empty?

    pattern = "#{anchor_left ? "" : "%"}#{from}#{anchor_right ? "" : "%"}"

    text_columns.each do |table, columns|
      query_parts = build_remap_query_parts(table, columns, skip_max_length_violations)

      begin
        rows_updated = DB.exec(<<~SQL, from: from, to: to, pattern: pattern)
          UPDATE \"#{table}\"
            SET #{query_parts[:updates].join(", ")}
          WHERE #{query_parts[:conditions].join(" OR ")}
        SQL
      rescue PG::StringDataRightTruncation => e
        # Provide more context in the exeption message
        raise_contextualized_remap_exception(e, table, query_parts[:length_constrained_columns])
      end

      if verbose
        skipped_counts =
          skipped_remap_counts(table, from, to, pattern, query_parts, skip_max_length_violations)

        log_remap_message(table, rows_updated, skipped_counts)
      end
    end

    finish!
  end

  def self.regexp_replace(
    pattern,
    replacement,
    flags: "gi",
    match: "~*",
    excluded_tables: [],
    verbose: false
  )
    text_columns = find_text_columns(excluded_tables)

    text_columns.each do |table, columns|
      set =
        columns
          .map do |column|
            replace = "REGEXP_REPLACE(\"#{column[:name]}\", :pattern, :replacement, :flags)"
            replace = truncate(replace, table, column)
            "\"#{column[:name]}\" = #{replace}"
          end
          .join(", ")

      where =
        columns
          .map do |column|
            "\"#{column[:name]}\" IS NOT NULL AND \"#{column[:name]}\" #{match} :pattern"
          end
          .join(" OR ")

      rows = DB.exec(<<~SQL, pattern: pattern, replacement: replacement, flags: flags, match: match)
        UPDATE \"#{table}\"
           SET #{set}
         WHERE #{where}
      SQL

      puts "#{table}=#{rows}" if verbose && rows > 0
    end

    finish!
  end

  def self.find(needle, anchor_left: false, anchor_right: false, excluded_tables: [])
    found = {}
    like = "#{anchor_left ? "" : "%"}#{needle}#{anchor_right ? "" : "%"}"

    DB
      .query(REMAP_SQL)
      .each do |r|
        next if excluded_tables.include?(r.table_name)

        rows = DB.query(<<~SQL, like: like)
        SELECT \"#{r.column_name}\"
          FROM \"#{r.table_name}\"
         WHERE \"#{r.column_name}\" LIKE :like
      SQL

        if rows.size > 0
          found["#{r.table_name}.#{r.column_name}"] = rows.map do |row|
            row.public_send(r.column_name)
          end
        end
      end

    found
  end

  private

  def self.finish!
    SiteSetting.refresh!
    Theme.expire_site_cache!
    SiteIconManager.ensure_optimized!
    ApplicationController.banner_json_cache.clear
  end

  def self.find_text_columns(excluded_tables)
    triggers = DB.query(TRIGGERS_SQL).map(&:trigger_name).to_set
    text_columns = Hash.new { |h, k| h[k] = [] }

    DB
      .query(REMAP_SQL)
      .each do |r|
        if excluded_tables.include?(r.table_name) ||
             triggers.include?(
               Migration::BaseDropper.readonly_trigger_name(r.table_name, r.column_name),
             ) || triggers.include?(Migration::BaseDropper.readonly_trigger_name(r.table_name))
          next
        end

        text_columns[r.table_name] << {
          name: r.column_name,
          max_length: r.character_maximum_length,
        }
      end

    text_columns
  end

  def self.truncate(sql, table, column)
    if column[:max_length] && TRUNCATABLE_COLUMNS.include?("#{table}.#{column[:name]}")
      "LEFT(#{sql}, #{column[:max_length]})"
    else
      sql
    end
  end

  def self.build_remap_query_parts(table, columns, skip_max_length_violations)
    columns.each_with_object(
      { updates: [], conditions: [], skipped_sums: [], length_constrained_columns: [] },
    ) do |column, parts|
      replace = %|REPLACE("#{column[:name]}", :from, :to)|
      replace = truncate(replace, table, column)

      if column[:max_length].present?
        # Keep track of columns with length constraints for error messages
        parts[:length_constrained_columns] << "#{column[:name]}(#{column[:max_length]})"
      end

      # Build SQL update statements for each column
      parts[:updates] << %("#{column[:name]}" = #{replace})

      # Build the base SQL condition clause for each column
      basic_condition = %("#{column[:name]}" IS NOT NULL AND "#{column[:name]}" LIKE :pattern)

      if skip_max_length_violations && column[:max_length].present?
        # Extend base condition to skip updates that would violate the column length constraint
        parts[
          :conditions
        ] << "(#{basic_condition} AND LENGTH(#{replace}) <= #{column[:max_length]})"

        # Build SQL sum statements for each column to count skipped updates.
        # This will helps us know the number of updates skipped due to length constraints
        # violations on this column
        parts[:skipped_sums] << <<~SQL
          SUM (
            CASE
              WHEN #{basic_condition} AND LENGTH(#{replace}) > #{column[:max_length]} THEN 1 ELSE 0
            END
          ) AS #{column[:name]}_skipped
        SQL
      else
        parts[:conditions] << "(#{basic_condition})"
      end
    end
  end

  def self.log_remap_message(table, rows_updated, skipped_counts)
    return if rows_updated == 0 && skipped_counts.blank?

    message = +"#{table}=#{rows_updated}"

    if skipped_counts&.any?
      message << " SKIPPED: "
      message << skipped_counts
        .map do |column, count|
          "#{column.delete_suffix("_skipped")}: #{count} #{"update".pluralize(count)}"
        end
        .join(", ")
    end

    puts message
  end

  def self.skipped_remap_counts(table, from, to, pattern, query_parts, skip_max_length_violations)
    return unless skip_max_length_violations && query_parts[:skipped_sums].any?

    skipped = DB.query_hash(<<~SQL, from: from, to: to, pattern: pattern).first
      SELECT #{query_parts[:skipped_sums].join(", ")}
      FROM \"#{table}\"
    SQL

    skipped.select { |_, count| count.to_i > 0 }
  end

  def self.raise_contextualized_remap_exception(error, table, columns)
    details = "columns with length constraints: #{columns.join(", ")}"

    raise PG::StringDataRightTruncation, " #{error.message.strip} (table: #{table}, #{details})"
  end
end
