# frozen_string_literal: true

module EmberCli
  ASSETS = %w(
    discourse.js
    admin.js
    ember_jquery.js
    pretty-text-bundle.js
    start-discourse.js
    vendor.js
  )

  def self.script_chunks
    return @@chunk_infos if defined? @@chunk_infos

    raw_chunk_infos = JSON.parse(File.read("#{Rails.configuration.root}/app/assets/javascripts/discourse/dist/chunks.json"))

    chunk_infos = raw_chunk_infos["scripts"].map do |info|
      logical_name = info["afterFile"][/\Aassets\/(.*)\.js\z/, 1]
      chunks = info["scriptChunks"].map { |filename| filename[/\Aassets\/(.*)\.js\z/, 1] }
      [logical_name, chunks]
    end.to_h

    @@chunk_infos = chunk_infos if Rails.env.production?
    chunk_infos
  rescue Errno::ENOENT
    {}
  end

  # Some assets have changed name following the switch
  # to ember-cli. When the switch is complete, we can
  # drop this method and update all the references
  # to use the new names
  def self.is_ember_cli_asset?(name)
    ASSETS.include?(name) || name.start_with?("chunk.")
  end
end
