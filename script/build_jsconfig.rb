# frozen_string_literal: true

require "pathname"
require "json"

Dir.chdir("#{__dir__}/..") # rubocop:disable Discourse/NoChdir because this is not part of the app

CORE_NAMESPACES = {
  "discourse/*" => ["app/assets/javascripts/discourse/app"],
  "discourse/tests/*" => ["app/assets/javascripts/discourse/tests"],
  "admin/*" => ["app/assets/javascripts/admin/addon"],
  "pretty-text/*" => ["app/assets/javascripts/pretty-text/addon"],
  "select-kit/*" => ["app/assets/javascripts/select-kit/addon"],
  "float-kit/*" => ["app/assets/javascripts/float-kit/addon"],
  "truth-helpers/*" => ["app/assets/javascripts/truth-helpers/addon"],
  "dialog-holder/*" => ["app/assets/javascripts/dialog-holder/addon"],
}

def relative(from, to)
  relative_path = Pathname.new(to).relative_path_from(from).to_s
  relative_path = "./#{relative_path}" if !relative_path.start_with?(".")
  relative_path
end

def write_config(package_dir, extras: {})
  package_dir = Pathname.new(package_dir)
  namespaces = { **CORE_NAMESPACES, **extras }
  config = {
    "compilerOptions" => {
      "target" => "es2021",
      "module" => "esnext",
      "moduleResolution" => "bundler",
      "experimentalDecorators" => true,
      "paths" => {
        **namespaces
          .map { |ns, paths| [ns, paths.map { |p| "#{relative(package_dir, p)}/*" }] }
          .to_h,
      },
    },
    "include" => namespaces.flat_map { |ns, paths| paths.map { |p| relative(package_dir, p) } },
    "exclude" => [
      "app/assets/javascripts/discourse/tests/unit/utils/decorators-test.js", # Native class decorators - unsupported by ts/glint
      "app/assets/javascripts/discourse/tests/integration/component-templates-test.gjs", # hbs`` tagged templates - https://github.com/typed-ember/glint/issues/705
      "**/*.hbs",
    ],
    "glint" => {
      "environment" => %w[ember-loose ember-template-imports],
      "checkStandaloneTemplates" => false,
    },
  }

  output = <<~JSON
    // This file was generated by scripts/build_jsconfig.rb
    #{JSON.pretty_generate(config)}
  JSON

  File.write("#{package_dir}/jsconfig.json", output)
end

core_plugins = `git ls-files plugins/*/plugin.rb`.lines.map { |path| path.split("/")[1] }
plugin_configs =
  core_plugins
    .map do |name|
      [
        "discourse/plugins/#{name}/*",
        ["plugins/#{name}/assets/javascripts", "plugins/#{name}/test/javascripts"],
      ]
    end
    .to_h

write_config ".", extras: { **plugin_configs }
