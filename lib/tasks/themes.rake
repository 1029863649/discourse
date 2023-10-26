# frozen_string_literal: true

require "yaml"

#
# 2 different formats are accepted:
#
# == JSON format
#
# bin/rake themes:install -- '--{"discourse-something": "https://github.com/discourse/discourse-something"}'
# OR
# bin/rake themes:install -- '--{"discourse-something": {"url": "https://github.com/discourse/discourse-something", default: true}}'
#
# == YAML file formats
#
# theme_name: https://github.com/example/theme.git
# OR
# theme_name:
#   url: https://github.com/example/theme_name.git
#   branch: "master"
#   private_key: ""
#   default: false
#   add_to_all_themes: false  # only for components - install on every theme
#
# In the first form, only the url is required.
#
desc "Install themes & theme components"
task "themes:install" => :environment do |task, args|
  theme_args = (STDIN.tty?) ? "" : STDIN.read
  use_json = theme_args == ""

  theme_args =
    begin
      use_json ? JSON.parse(ARGV.last.gsub("--", "")) : YAML.safe_load(theme_args)
    rescue StandardError
      puts use_json ? "Invalid JSON input. \n#{ARGV.last}" : "Invalid YML: \n#{theme_args}"
      exit 1
    end

  log, counts = ThemesInstallTask.install(theme_args)

  puts log

  puts
  puts "Results:"
  puts " Installed: #{counts[:installed]}"
  puts " Updated:   #{counts[:updated]}"
  puts " Errors:    #{counts[:errors]}"
  puts " Skipped:   #{counts[:skipped]}"

  exit 1 if counts[:errors] > 0
end

desc "Install themes & theme components from an archive"
task "themes:install:archive" => :environment do |task, args|
  filename = ENV["THEME_ARCHIVE"]
  RemoteTheme.update_zipped_theme(filename, File.basename(filename))
end

def update_themes
  Theme
    .includes(:remote_theme)
    .where(enabled: true, auto_update: true)
    .find_each do |theme|
      theme.transaction do
        remote_theme = theme.remote_theme
        next if remote_theme.blank? || remote_theme.remote_url.blank?

        print "Checking '#{theme.name}' for '#{RailsMultisite::ConnectionManagement.current_db}'... "
        remote_theme.update_remote_version
        if remote_theme.out_of_date?
          puts "updating from #{remote_theme.local_version[0..7]} to #{remote_theme.remote_version[0..7]}"
          remote_theme.update_from_remote(already_in_transaction: true)
        else
          puts "up to date"
        end

        if remote_theme.last_error_text.present?
          raise RemoteTheme::ImportError.new(remote_theme.last_error_text)
        end
      rescue => e
        STDERR.puts "Failed to update '#{theme.name}': #{e}"
        raise if ENV["RAISE_THEME_ERRORS"] == "1"
      end
    end

  true
end

desc "Update themes & theme components"
task "themes:update": %w[environment assets:precompile:theme_transpiler] do
  if ENV["RAILS_DB"].present?
    update_themes
  else
    RailsMultisite::ConnectionManagement.each_connection { update_themes }
  end
end

desc "List all the installed themes on the site"
task "themes:audit" => :environment do
  components = Set.new
  puts "Selectable themes"
  puts "-----------------"

  Theme
    .where("(enabled OR user_selectable) AND NOT component")
    .each do |theme|
      puts theme.remote_theme&.remote_url || theme.name
      theme.child_themes.each do |child|
        if child.enabled
          repo = child.remote_theme&.remote_url || child.name
          components << repo
        end
      end
    end

  puts
  puts "Selectable components"
  puts "---------------------"
  components.each { |repo| puts repo }
end

desc "Run QUnit tests of a theme/component"
task "themes:qunit", :type, :value do |t, args|
  type = args[:type]
  value = args[:value]
  raise <<~TEXT if !%w[name url id].include?(type) || value.blank?
      Wrong arguments type:#{type.inspect}, value:#{value.inspect}"
      Usage:
        `bundle exec rake "themes:qunit[url,<theme_url>]"`
        OR
        `bundle exec rake "themes:qunit[name,<theme_name>]"`
        OR
        `bundle exec rake "themes:qunit[id,<theme_id>]"`
    TEXT
  ENV["THEME_#{type.upcase}"] = value.to_s
  ENV["QUNIT_RAILS_ENV"] ||= "development" # qunit:test will switch to `test` by default
  Rake::Task["qunit:test"].reenable
  Rake::Task["qunit:test"].invoke(1_200_000, "/theme-qunit")
end

desc "Install a theme/component on a temporary DB and run QUnit tests"
task "themes:isolated_test" => :environment do |t, args|
  # This task can be called in a production environment that likely has a bunch
  # of DISCOURSE_* env vars that we don't want to be picked up by the Unicorn
  # server that will be spawned for the tests. So we need to unset them all
  # before we proceed.
  # Make this behavior opt-in to make it very obvious.
  if ENV["UNSET_DISCOURSE_ENV_VARS"] == "1"
    ENV.keys.each do |key|
      next if !key.start_with?("DISCOURSE_")
      next if ENV["DONT_UNSET_#{key}"] == "1"
      ENV[key] = nil
    end
  end

  redis = TemporaryRedis.new
  redis.start
  Discourse.redis = redis.instance
  db = TemporaryDb.new
  db.start
  db.migrate
  ActiveRecord::Base.establish_connection(
    adapter: "postgresql",
    database: "discourse",
    port: db.pg_port,
    host: "localhost",
  )

  seeded_themes = Theme.pluck(:id)
  Rake::Task["themes:install"].invoke
  themes = Theme.pluck(:name, :id)

  ENV["PGPORT"] = db.pg_port.to_s
  ENV["PGHOST"] = "localhost"
  ENV["QUNIT_RAILS_ENV"] = "development"
  ENV["DISCOURSE_DEV_DB"] = "discourse"
  ENV["DISCOURSE_REDIS_PORT"] = redis.port.to_s

  count = 0
  themes.each do |(name, id)|
    if seeded_themes.include?(id)
      puts "Skipping seeded theme #{name} (id: #{id})"
      next
    end
    puts "Running tests for theme #{name} (id: #{id})..."
    Rake::Task["themes:qunit"].reenable
    Rake::Task["themes:qunit"].invoke("id", id)
    count += 1
  end
  raise "Error: No themes were installed" if count == 0
ensure
  db&.stop
  db&.remove
  redis&.remove
end

desc "Installs all official themes. This should only be used in the test environment."
task "themes:install_all_official" => :environment do |task, args|
  FileUtils.rm_rf("tmp/themes")

  official_themes =
    Set
      .new(
        %w[
          discourse-brand-header
          discourse-category-banners
          discourse-clickable-topic
          discourse-color-scheme-toggle
          discourse-custom-header-links
          Discourse-easy-footer
          discourse-gifs
          discourse-topic-thumbnails
          discourse-search-banner
          discourse-unanswered-filter
          discourse-versatile-banner
          DiscoTOC
          unformatted-code-detector
        ],
      )
      .each do |theme_name|
        repo = "https://github.com/discourse/#{theme_name}"
        path = File.expand_path("tmp/themes/#{theme_name}")

        attempts = 0

        begin
          attempts += 1
          system("git clone #{repo} #{path}", exception: true)
        rescue StandardError
          abort("Failed to clone #{repo}") if attempts >= 3
          STDERR.puts "Failed to clone #{repo}... trying again..."
          retry
        end

        RemoteTheme.import_theme_from_directory(path)
      end
end
