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

def html_for_section(group)
  icons =
    group["icons"].map do |icon|
      class_attr = icon["diversity"] ? " class=\"diversity\"" : ""
      "    {{replace-emoji \":#{icon["name"]}:\" (hash lazy=true#{class_attr} tabIndex=\"0\")}}"
    end

  <<~HTML
    <div class="section" data-section="#{group["name"]}">
      <div class="section-header">
        <span class="title">{{i18n "emoji_picker.#{group["name"]}"}}</span>
      </div>
      <div class="section-group">
        #{icons.join("\n").strip}
      </div>
    </div>
  HTML
end

def write_template(path, task_name, template)
  header = <<~JS
    // DO NOT EDIT THIS FILE!!!
    // Update it by running `rake javascript:#{task_name}`
  JS

  basename = File.basename(path)
  output_path = "#{Rails.root}/app/assets/javascripts/#{path}"

  File.write(output_path, "#{header}\n\n#{template}")
  puts "#{basename} created"
  `yarn run prettier --write #{output_path}`
  puts "#{basename} prettified"
end

def write_hbs_template(path, task_name, template)
  header = <<~HBS
  {{!-- DO NOT EDIT THIS FILE!!! --}}
  {{!-- Update it by running `rake javascript:#{task_name}` --}}
  HBS

  basename = File.basename(path)
  output_path = "#{Rails.root}/app/assets/javascripts/#{path}"
  File.write(output_path, "#{header}\n#{template}")
  `yarn run prettier --write #{output_path}`
  puts "#{basename} created"
end

def dependencies
  [
    { source: "ace-builds/src-min-noconflict/ace.js", destination: "ace.js", public: true },
    {
      source: "@json-editor/json-editor/dist/jsoneditor.js",
      package_name: "@json-editor/json-editor",
      public: true,
    },
    { source: "chart.js/dist/chart.min.js", public: true },
    { source: "chartjs-plugin-datalabels/dist/chartjs-plugin-datalabels.min.js", public: true },
    { source: "diffhtml/dist/diffhtml.min.js", public: true },
    { source: "magnific-popup/dist/jquery.magnific-popup.min.js", public: true },
    { source: "pikaday/pikaday.js", public: true },
    { source: "@highlightjs/cdn-assets/.", destination: "highlightjs" },
    { source: "moment/moment.js" },
    { source: "moment/locale/.", destination: "moment-locale" },
    {
      source: "moment-timezone/builds/moment-timezone-with-data-10-year-range.js",
      destination: "moment-timezone-with-data.js",
    },
    {
      source: "@discourse/moment-timezone-names-translations/locales/.",
      destination: "moment-timezone-names-locale",
    },
    {
      source: "squoosh/codecs/mozjpeg/enc/mozjpeg_enc.js",
      destination: "squoosh",
      public: true,
      skip_versioning: true,
    },
    {
      source: "squoosh/codecs/mozjpeg/enc/mozjpeg_enc.wasm",
      destination: "squoosh",
      public: true,
      skip_versioning: true,
    },
    {
      source: "squoosh/codecs/resize/pkg/squoosh_resize.js",
      destination: "squoosh",
      public: true,
      skip_versioning: true,
    },
    {
      source: "squoosh/codecs/resize/pkg/squoosh_resize_bg.wasm",
      destination: "squoosh",
      public: true,
      skip_versioning: true,
    },
  ]
end

def node_package_name(f)
  f[:package_name] || f[:source].split("/").first
end

def public_path_name(f)
  f[:destination] || node_package_name(f)
end

def absolute_sourcemap(dest)
  File.open(dest) do |file|
    contents = file.read
    contents.gsub!(/sourceMappingURL=(.*)/, 'sourceMappingURL=/\1')
    File.open(dest, "w+") { |d| d.write(contents) }
  end
end

def generate_admin_sidebar_nav_map
  vague_categories = { "root" => [] }

  admin_routes =
    Rails
      .application
      .routes
      .routes
      .map do |route|
        next if route.verb != "GET"
        path = route.path.spec.to_s.gsub("(.:format)", "")
        next if !path.include?("admin")
        next if path.include?("/:") || path.include?("admin-login")
        path
      end
      .compact

  # TODO (martin): This will generate the engine routes based on installed plugins,
  # so it is not generic enough to use here. Need to think of another way to do
  # this and reconcile with the Ember routes from the client; maybe some button
  # that does it at runtime for this experiment?
  engine_routes = []
  # engine_routes =  Rails::Engine
  #     .subclasses
  #     .map do |engine|
  #       engine
  #         .routes
  #         .routes
  #         .map do |route|
  #           next if route.verb != "GET"
  #           path = route.path.spec.to_s.gsub("(.:format)", "")
  #           next if !path.include?("admin")
  #           next if path.include?("/:") || path.include?("admin-login")
  #           path
  #         end
  #         .compact
  #     end
  #     .flatten

  admin_routes = admin_routes.concat(engine_routes)

  admin_routes.each do |path|
    split_path = path.split("/")
    if split_path.length >= 3
      vague_categories[split_path[2]] ||= []
      vague_categories[split_path[2]] << { path: path }
    else
      vague_categories["root"] << { path: path }
    end
  end

  # Copy this JS to your browser to get the Ember routes.
  #
  <<~JS
  let routeMap = {}
  for (const [key, value] of Object.entries(
    Object.fromEntries(
      Object.entries(
        Discourse.__container__.lookup("service:router")._router._routerMicrolib
          .recognizer.names
      ).filter(([key]) => key.includes("admin"))
    )
  )) {
    let route = value.segments
      .map((s) => s.value)
      .join("/")
      .replace("//", "/");
    if (
      route.includes("dummy") ||
      route.includes("loading") ||
      route.includes("_id") ||
      route.includes("admin-invite")
    ) {
      continue;
    }
    routeMap[key] = route;
  }
  console.log(JSON.stringify(routeMap));
JS

  # Paste the output below between ROUTE_MAP.
  #
  ember_route_map = <<~ROUTE_MAP
    {"admin.dashboard.general":"/admin/","admin.dashboard":"/admin/","admin":"/admin/","admin.dashboardModeration":"/admin/dashboard/moderation","admin.dashboardSecurity":"/admin/dashboard/security","admin.dashboardReports":"/admin/dashboard/reports","adminSiteSettings.index":"/admin/site_settings/","adminSiteSettings":"/admin/site_settings/","adminEmail.sent":"/admin/email/sent","adminEmail.skipped":"/admin/email/skipped","adminEmail.bounced":"/admin/email/bounced","adminEmail.received":"/admin/email/received","adminEmail.rejected":"/admin/email/rejected","adminEmail.previewDigest":"/admin/email/preview-digest","adminEmail.advancedTest":"/admin/email/advanced-test","adminEmail.index":"/admin/email/","adminEmail":"/admin/email/","adminCustomize.colors.index":"/admin/customize/colors/","adminCustomize.colors":"/admin/customize/colors/","adminCustomizeThemes.index":"/admin/customize/themes/","adminCustomizeThemes":"/admin/customize/themes/","adminSiteText.edit":"/admin/customize/site_texts/id","adminSiteText.index":"/admin/customize/site_texts/","adminSiteText":"/admin/customize/site_texts/","adminUserFields":"/admin/customize/user_fields","adminEmojis":"/admin/customize/emojis","adminPermalinks":"/admin/customize/permalinks","adminEmbedding":"/admin/customize/embedding","adminCustomizeEmailTemplates.edit":"/admin/customize/email_templates/id","adminCustomizeEmailTemplates.index":"/admin/customize/email_templates/","adminCustomizeEmailTemplates":"/admin/customize/email_templates/","adminCustomizeRobotsTxt":"/admin/customize/robots","adminCustomizeEmailStyle.edit":"/admin/customize/email_style/field_name","adminCustomizeEmailStyle.index":"/admin/customize/email_style/","adminCustomizeEmailStyle":"/admin/customize/email_style/","adminCustomizeFormTemplates.new":"/admin/customize/form-templates/new","adminCustomizeFormTemplates.edit":"/admin/customize/form-templates/id","adminCustomizeFormTemplates.index":"/admin/customize/form-templates/","adminCustomizeFormTemplates":"/admin/customize/form-templates/","adminWatchedWords.index":"/admin/customize/watched_words/","adminWatchedWords":"/admin/customize/watched_words/","adminCustomize.index":"/admin/customize/","adminCustomize":"/admin/customize/","adminApiKeys.new":"/admin/api/keys/new","adminApiKeys.index":"/admin/api/keys/","adminApiKeys":"/admin/api/keys/","adminWebHooks.index":"/admin/api/web_hooks/","adminWebHooks":"/admin/api/web_hooks/","adminApi.index":"/admin/api/","adminApi":"/admin/api/","admin.backups.logs":"/admin/backups/logs","admin.backups.index":"/admin/backups/","admin.backups":"/admin/backups/","adminReports.show":"/admin/reports/type","adminReports.index":"/admin/reports/","adminReports":"/admin/reports/","adminLogs.staffActionLogs":"/admin/logs/staff_action_logs","adminLogs.screenedEmails":"/admin/logs/screened_emails","adminLogs.screenedIpAddresses":"/admin/logs/screened_ip_addresses","adminLogs.screenedUrls":"/admin/logs/screened_urls","adminSearchLogs.index":"/admin/logs/search_logs/","adminSearchLogs":"/admin/logs/search_logs/","adminSearchLogs.term":"/admin/logs/search_logs/term","adminLogs.index":"/admin/logs/","adminLogs":"/admin/logs/","adminUsersList.show":"/admin/users/list/filter","adminUsersList.index":"/admin/users/list/","adminUsersList":"/admin/users/list/","adminUsers.index":"/admin/users/","adminUsers":"/admin/users/","adminBadges.index":"/admin/badges/","adminBadges":"/admin/badges/","adminPlugins.index":"/admin/plugins/","adminPlugins":"/admin/plugins/","admin-revamp.lobby":"/admin-revamp/","admin-revamp":"/admin-revamp/","admin-revamp.config.area":"/admin-revamp/config/area","admin-revamp.config.index":"/admin-revamp/config/","admin-revamp.config":"/admin-revamp/config/"}
  ROUTE_MAP
  ember_route_map = JSON.parse(ember_route_map)

  # Match the Ember routes to the rails routes.
  vague_categories.each do |category, route_data|
    route_data.each do |rails_route|
      ember_route_map.each do |ember_route_name, ember_path|
        rails_route[:ember_route] = ember_route_name if ember_path == rails_route[:path] ||
          ember_path == rails_route[:path] + "/"
      end
    end
  end

  # Remove all rails routes that don't have an Ember equivalent.
  vague_categories.each do |category, route_data|
    vague_categories[category] = route_data.reject { |rails_route| !rails_route.key?(:ember_route) }
  end

  # Remove all categories that don't have any routes (meaning they are all rails-only).
  vague_categories.each do |category, route_data|
    vague_categories.delete(category) if route_data.length == 0
  end

  # Output in the format needed for sidebar sections and links.
  vague_categories.map do |category, route_data|
    category_text = category.titleize.gsub("Admin ", "")
    {
      name: category,
      text: category_text,
      links:
        route_data.map do |rails_route|
          {
            name: rails_route[:path].split("/").compact_blank.join("_").chomp,
            route: rails_route[:ember_route],
            text:
              rails_route[:path]
                .split("/")
                .compact_blank
                .join(" ")
                .chomp
                .titleize
                .gsub("Admin ", "")
                .gsub("#{category_text} ", ""),
          }
        end,
    }
  end
end

task "javascript:update_constants" => :environment do
  task_name = "update_constants"

  auto_groups =
    Group::AUTO_GROUPS.inject({}) do |result, (group_name, group_id)|
      result.merge(
        group_name => {
          id: group_id,
          automatic: true,
          name: group_name,
          display_name: group_name,
        },
      )
    end

  write_template("discourse/app/lib/constants.js", task_name, <<~JS)
    export const SEARCH_PRIORITIES = #{Searchable::PRIORITIES.to_json};

    export const SEARCH_PHRASE_REGEXP = '#{Search::PHRASE_MATCH_REGEXP_PATTERN}';

    export const SIDEBAR_URL = {
      max_icon_length: #{SidebarUrl::MAX_ICON_LENGTH},
      max_name_length: #{SidebarUrl::MAX_NAME_LENGTH},
      max_value_length: #{SidebarUrl::MAX_VALUE_LENGTH}
    }

    export const SIDEBAR_SECTION = {
      max_title_length: #{SidebarSection::MAX_TITLE_LENGTH},
    }

    export const AUTO_GROUPS = #{auto_groups.to_json};
  JS

  write_template("discourse/app/lib/sidebar/admin-nav-map.js", task_name, <<~JS)
    export const ADMIN_NAV_MAP = #{generate_admin_sidebar_nav_map.to_json}
  JS

  pretty_notifications = Notification.types.map { |n| "  #{n[0]}: #{n[1]}," }.join("\n")

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

  langs = []
  Dir
    .glob("vendor/assets/javascripts/highlightjs/languages/*.min.js")
    .each { |f| langs << File.basename(f, ".min.js") }
  bundle = HighlightJs.bundle(langs)

  ctx = MiniRacer::Context.new
  hljs_aliases = ctx.eval(<<~JS)
    #{bundle}

    let aliases = {};
    hljs.listLanguages().forEach((lang) => {
      if (hljs.getLanguage(lang).aliases) {
        aliases[lang] = hljs.getLanguage(lang).aliases;
      }
    });

    aliases;
  JS

  write_template("pretty-text/addon/highlightjs-aliases.js", task_name, <<~JS)
    export const HLJS_ALIASES = #{hljs_aliases.to_json};
  JS

  ctx.dispose

  write_template("pretty-text/addon/emoji/version.js", task_name, <<~JS)
    export const IMAGE_VERSION = "#{Emoji::EMOJI_VERSION}";
  JS

  groups_json = JSON.parse(File.read("lib/emoji/groups.json"))

  emoji_buttons = groups_json.map { |group| <<~HTML }
			<button type="button" data-section="#{group["name"]}" {{on "click" (fn this.onCategorySelection "#{group["name"]}")}} class="btn btn-default category-button emoji">
				 {{replace-emoji ":#{group["tabicon"]}:"}}
			</button>
    HTML

  emoji_sections = groups_json.map { |group| html_for_section(group) }

  components_dir = "discourse/app/components"
  write_hbs_template("#{components_dir}/emoji-group-buttons.hbs", task_name, emoji_buttons.join)
  write_hbs_template("#{components_dir}/emoji-group-sections.hbs", task_name, emoji_sections.join)
end

task "javascript:update" => "clean_up" do
  require "uglifier"

  yarn = system("yarn install")
  abort('Unable to run "yarn install"') unless yarn

  versions = {}
  start = Time.now

  dependencies.each do |f|
    src = "#{library_src}/#{f[:source]}"

    if f[:destination]
      filename = f[:destination]
    else
      filename = f[:source].split("/").last
    end

    if src.include? "highlightjs"
      puts "Cleanup highlightjs styles and install smaller test bundle"
      system("rm -rf node_modules/@highlightjs/cdn-assets/styles")

      # We don't need every language for tests
      langs = %w[javascript sql ruby]
      test_bundle_dest = "vendor/assets/javascripts/highlightjs/highlight-test-bundle.min.js"
      File.write(test_bundle_dest, HighlightJs.bundle(langs))
    end

    if f[:public_root]
      dest = "#{public_root}/#{filename}"
    elsif f[:public]
      if f[:skip_versioning]
        dest = "#{public_js}/#{filename}"
      else
        package_dir_name = public_path_name(f)
        package_version =
          JSON.parse(File.read("#{library_src}/#{node_package_name(f)}/package.json"))["version"]
        versions[filename.downcase] = "#{package_dir_name}/#{package_version}/#{filename}"

        path = "#{public_js}/#{package_dir_name}/#{package_version}"
        dest = "#{path}/#{filename}"

        FileUtils.mkdir_p(path) unless File.exist?(path)
      end
    else
      dest = "#{vendor_js}/#{filename}"
    end

    if src.include? "ace.js"
      versions["ace/ace.js"] = versions.delete("ace.js")
      ace_root = "#{library_src}/ace-builds/src-min-noconflict/"
      addtl_files = %w[
        ext-searchbox
        mode-html
        mode-scss
        mode-sql
        mode-yaml
        theme-chrome
        theme-chaos
        worker-html
      ]
      dest_path = dest.split("/")[0..-2].join("/")
      addtl_files.each { |file| FileUtils.cp_r("#{ace_root}#{file}.js", dest_path) }
    end

    STDERR.puts "New dependency added: #{dest}" unless File.exist?(dest)

    FileUtils.cp_r(src, dest)
  end

  write_template("discourse/app/lib/public-js-versions.js", "update", <<~JS)
    export const PUBLIC_JS_VERSIONS = #{versions.to_json};
  JS

  STDERR.puts "Completed copying dependencies: #{(Time.now - start).round(2)} secs"
end

task "javascript:clean_up" do
  processed = []
  dependencies.each do |f|
    next unless f[:public] && !f[:skip_versioning]

    package_dir_name = public_path_name(f)
    next if processed.include?(package_dir_name)

    versions = Dir["#{File.join(public_js, package_dir_name)}/*"].collect { |p| p.split("/").last }
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
