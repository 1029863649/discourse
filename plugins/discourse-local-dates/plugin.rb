# name: discourse-local-dates
# about: Display a date in your local timezone
# version: 0.1
# author: Joffrey Jaffeux
hide_plugin if self.respond_to?(:hide_plugin)

register_asset "javascripts/discourse-local-dates.js"
register_asset "stylesheets/common/discourse-local-dates.scss"
register_asset "moment.js", :vendored_core_pretty_text
register_asset "moment-timezone.js", :vendored_core_pretty_text

enabled_site_setting :discourse_local_dates_enabled

after_initialize do
  module ::DiscourseLocalDates
    PLUGIN_NAME ||= "discourse-local-dates".freeze
    POST_CUSTOM_FIELD ||= "local_dates".freeze
  end

  [
    "../lib/discourse_local_dates/engine.rb",
  ].each { |path| load File.expand_path(path, __FILE__) }

  register_post_custom_field_type(DiscourseLocalDates::POST_CUSTOM_FIELD, :json)

  on(:post_process_cooked) do |doc, post|
    dates = doc.css('span.discourse-local-date').map do |cooked_date|
      date = {}
      cooked_date.attributes.values.each do |attribute|
        if attribute.name && ['data-date', 'data-time'].include?(attribute.name)
          unless attribute.value == 'undefined'
            date[attribute.name.gsub('data-', '')] = CGI.escapeHTML(attribute.value || "")
          end
        end
      end
      date
    end

    if dates.present?
      post.custom_fields[DiscourseLocalDates::POST_CUSTOM_FIELD] = dates.to_json
      post.save_custom_fields
    elsif post.custom_fields[DiscourseLocalDates::POST_CUSTOM_FIELD].present?
      PostCustomField.where(post_id: post.id, name: DiscourseLocalDates::POST_CUSTOM_FIELD).destroy_all
    end
  end

  add_to_class(:post, :local_dates) do
    custom_fields[DiscourseLocalDates::POST_CUSTOM_FIELD] || []
  end

  on(:reduce_cooked) do |fragment|
    container = fragment.css(".discourse-local-date").first

    if container && container.attributes["data-email-preview"]
      preview = container.attributes["data-email-preview"].value
      container.content = preview
    end
  end
end
