# frozen_string_literal: true

def public_root
  "#{Rails.root}/public"
end

def public_js
  "#{public_root}/javascripts"
end

def vendor_js
  "#{Rails.root}/vendor/assets/javascripts"
end

def library_src
  "#{Rails.root}/node_modules"
end

def write_template(path, task_name, template)
  header = <<~HEADER
    // DO NOT EDIT THIS FILE!!!
    // Update it by running `rake javascript:#{task_name}`
  HEADER

  basename = File.basename(path)
  output_path = "#{Rails.root}/app/assets/javascripts/#{path}"

  File.write(output_path, "#{header}\n\n#{template}")
  puts "#{basename} created"
  %x{yarn run prettier --write #{output_path}}
  puts "#{basename} prettified"
end

def dependencies
  [
    {
      source: 'bootstrap/js/modal.js',
      destination: 'bootstrap-modal.js'
    }, {
      source: 'ace-builds/src-min-noconflict/ace.js',
      destination: 'ace.js',
      public: true
    }, {
      source: 'chart.js/dist/Chart.min.js',
      public: true
    }, {
      source: 'chartjs-plugin-datalabels/dist/chartjs-plugin-datalabels.min.js',
      public: true
    }, {
      source: 'light-gallery/lightgallery.min.js',
      public: true
    },
    {
      source: 'light-gallery/lg-zoom.min.js',
      public: true
    },
    {
      source: 'light-gallery/lightgallery.min.css',
      public: true
    }, {
      source: 'pikaday/pikaday.js',
      public: true
    }, {
      source: 'spectrum-colorpicker/spectrum.js',
      uglify: true,
      public: true
    }, {
      source: 'spectrum-colorpicker/spectrum.css',
      public: true
    }, {
      source: 'favcount/favcount.js'
    }, {
      source: 'handlebars/dist/handlebars.js'
    }, {
      source: 'handlebars/dist/handlebars.runtime.js'
    }, {
      source: 'highlight.js/build/.',
      destination: 'highlightjs'
    }, {
      source: 'jquery-resize/jquery.ba-resize.js'
    }, {
      source: 'jquery.autoellipsis/src/jquery.autoellipsis.js',
      destination: 'jquery.autoellipsis-1.0.10.js'
    }, {
      source: 'jquery-color/dist/jquery.color.js'
    }, {
      source: 'blueimp-file-upload/js/jquery.fileupload.js',
    }, {
      source: 'blueimp-file-upload/js/jquery.iframe-transport.js',
    }, {
      source: 'blueimp-file-upload/js/vendor/jquery.ui.widget.js',
    }, {
      source: 'jquery/dist/jquery.js'
    }, {
      source: 'jquery-tags-input/src/jquery.tagsinput.js'
    }, {
      source: 'markdown-it/dist/markdown-it.js'
    }, {
      source: 'mousetrap/mousetrap.js'
    }, {
      source: 'moment/moment.js'
    }, {
      source: 'moment/locale/.',
      destination: 'moment-locale',
    }, {
      source: 'moment-timezone/builds/moment-timezone-with-data-10-year-range.js',
      destination: 'moment-timezone-with-data.js'
    }, {
      source: 'lodash.js',
      destination: 'lodash.js'
    }, {
      source: 'moment-timezone-names-translations/locales/.',
      destination: 'moment-timezone-names-locale'
    }, {
      source: 'mousetrap/plugins/global-bind/mousetrap-global-bind.js'
    }, {
      source: 'resumablejs/resumable.js'
    }, {
      # TODO: drop when we eventually drop IE11, this will land in iOS in version 13
      source: 'intersection-observer/intersection-observer.js'
    }, {
      source: 'workbox-sw/build/.',
      destination: 'workbox',
      public: true,
      skip_versioning: true
    }, {
      source: 'workbox-routing/build/.',
      destination: 'workbox',
      public: true,
      skip_versioning: true
    }, {
      source: 'workbox-core/build/.',
      destination: 'workbox',
      public: true,
      skip_versioning: true
    }, {
      source: 'workbox-strategies/build/.',
      destination: 'workbox',
      public: true,
      skip_versioning: true
    }, {
      source: 'workbox-expiration/build/.',
      destination: 'workbox',
      public: true,
      skip_versioning: true
    }, {
      source: '@popperjs/core/dist/umd/popper.js'
    }, {
      source: '@popperjs/core/dist/umd/popper.js.map',
      public_root: true
    },
    {
      source: 'route-recognizer/dist/route-recognizer.js'
    }, {
      source: 'route-recognizer/dist/route-recognizer.js.map',
      public_root: true
    },

  ]
end

def node_package_name(f)
  f[:source].split('/').first
end

def public_path_name(f)
  f[:destination] || node_package_name(f)
end

task 'javascript:update_constants' => :environment do
  task_name = 'update_constants'

  write_template("discourse/app/lib/constants.js", task_name, <<~JS)
    export const SEARCH_PRIORITIES = #{Searchable::PRIORITIES.to_json};

    export const SEARCH_PHRASE_REGEXP = '#{Search::PHRASE_MATCH_REGEXP_PATTERN}';
  JS

  pretty_notifications = Notification.types.map do |n|
    "  #{n[0]}: #{n[1]},"
  end.join("\n")

  write_template("discourse/tests/fixtures/concerns/notification-types.js", task_name, <<~JS)
    export const NOTIFICATION_TYPES = {
    #{pretty_notifications}
    };
  JS

  write_template("pretty-text/addon/emoji/data.js", task_name, <<~JS)
    export const emojis = #{Emoji.standard.map(&:name).flatten.inspect};
    export const tonableEmojis = #{Emoji.tonable_emojis.flatten.inspect};
    export const aliases = #{Emoji.aliases.inspect.gsub("=>", ":")};
    export const searchAliases = #{Emoji.search_aliases.inspect.gsub("=>", ":")};
    export const translations = #{Emoji.translations.inspect.gsub("=>", ":")};
    export const replacements = #{Emoji.unicode_replacements_json};
  JS

  write_template("pretty-text/addon/emoji/version.js", task_name, <<~JS)
    export const IMAGE_VERSION = "#{Emoji::EMOJI_VERSION}";
  JS
end

task 'javascript:update' => 'clean_up' do
  require 'uglifier'

  yarn = system("yarn install")
  abort('Unable to run "yarn install"') unless yarn

  versions = {}
  start = Time.now

  dependencies.each do |f|
    src = "#{library_src}/#{f[:source]}"

    unless f[:destination]
      filename = f[:source].split("/").last
    else
      filename = f[:destination]
    end

    # Highlight.js needs building
    if src.include? "highlight.js"
      puts "Install Highlight.js dependencies"
      system("cd node_modules/highlight.js && yarn install")

      puts "Build Highlight.js"
      system("cd node_modules/highlight.js && node tools/build.js -t cdn")

      puts "Cleanup unused styles folder"
      system("rm -rf node_modules/highlight.js/build/styles")

      # We don't need every language for tests
      langs = ['javascript', 'sql', 'ruby']
      test_bundle_dest = 'vendor/assets/javascripts/highlightjs/highlight-test-bundle.min.js'
      File.write(test_bundle_dest, HighlightJs.bundle(langs))
    end

    if f[:public_root]
      dest = "#{public_root}/#{filename}"
    elsif f[:public]
      if f[:skip_versioning]
        dest = "#{public_js}/#{filename}"
      else
        package_dir_name = public_path_name(f)
        package_version = JSON.parse(File.read("#{library_src}/#{node_package_name(f)}/package.json"))["version"]
        versions[filename] = "#{package_dir_name}/#{package_version}/#{filename}"

        path = "#{public_js}/#{package_dir_name}/#{package_version}"
        dest = "#{path}/#{filename}"

        FileUtils.mkdir_p(path) unless File.exists?(path)
      end
    else
      dest = "#{vendor_js}/#{filename}"
    end

    if src.include? "ace.js"
      versions["ace/ace.js"] = versions.delete("ace.js")
      ace_root = "#{library_src}/ace-builds/src-min-noconflict/"
      addtl_files = [ "ext-searchbox", "mode-html", "mode-scss", "mode-sql", "theme-chrome", "worker-html"]
      dest_path = dest.split('/')[0..-2].join('/')
      addtl_files.each do |file|
        FileUtils.cp_r("#{ace_root}#{file}.js", dest_path)
      end
    end

    # lodash.js needs building
    if src.include? "lodash.js"
      puts "Building custom lodash.js build"
      system('yarn run lodash include="each,filter,map,range,first,isEmpty,chain,extend,every,omit,merge,union,sortBy,uniq,intersection,reject,compact,reduce,debounce,throttle,values,pick,keys,flatten,min,max,isArray,delay,isString,isEqual,without,invoke,clone,findIndex,find,groupBy" minus="template" -d -o "node_modules/lodash.js"')
    end

    unless File.exists?(dest)
      STDERR.puts "New dependency added: #{dest}"
    end

    if f[:uglify]
      File.write(dest, Uglifier.new.compile(File.read(src)))
    else
      FileUtils.cp_r(src, dest)
    end
  end

  write_template("discourse/app/lib/public-js-versions.js", "update", <<~JS)
    export const PUBLIC_JS_VERSIONS = #{versions.to_json};
  JS

  STDERR.puts "Completed copying dependencies: #{(Time.now - start).round(2)} secs"
end

task 'javascript:clean_up' do
  processed = []
  dependencies.each do |f|
    next unless f[:public] && !f[:skip_versioning]

    package_dir_name = public_path_name(f)
    next if processed.include?(package_dir_name)

    versions = Dir["#{File.join(public_js, package_dir_name)}/*"].collect { |p| p.split('/').last }
    next unless versions.present?

    versions = versions.sort { |a, b| Gem::Version.new(a) <=> Gem::Version.new(b) }
    puts "Keeping #{package_dir_name} version: #{versions[-1]}"

    # Keep the most recent version
    versions[0..-2].each do |version|
      remove_path = File.join(public_js, package_dir_name, version)
      puts "Removing: #{remove_path}"
      FileUtils.remove_dir(remove_path)
    end

    processed << package_dir_name
  end
end
