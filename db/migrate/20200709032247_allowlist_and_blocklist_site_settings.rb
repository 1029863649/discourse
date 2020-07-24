# frozen_string_literal: true

class AllowlistAndBlocklistSiteSettings < ActiveRecord::Migration[6.0]
  NAMES_MAP = {
    'email_domains_blacklist': 'blocked_email_domains',
    'email_domains_whitelist': 'allowed_email_domains',
    'unicode_username_character_whitelist': 'allowed_unicode_username_characters',
    'user_website_domains_whitelist': 'allowed_user_website_domains',
    'whitelisted_link_domains': 'allowed_link_domains',
    'embed_whitelist_selector': 'allowed_embed_selectors',
    'auto_generated_whitelist': 'auto_generated_allowlist',
    'attachment_content_type_blacklist': 'blocked_attachment_content_types',
    'attachment_filename_blacklist': 'blocked_attachment_filenames',
    'use_admin_ip_whitelist': 'use_admin_ip_allowlist',
    'blacklist_ip_blocks': 'blocked_ip_blocks',
    'whitelist_internal_hosts': 'allowed_internal_hosts',
    'whitelisted_crawler_user_agents': 'allowed_crawler_user_agents',
    'blacklisted_crawler_user_agents': 'blocked_crawler_user_agents',
    'onebox_domains_blacklist': 'blocked_onebox_domains',
    'inline_onebox_domains_whitelist': 'allowed_inline_onebox_domains',
    'white_listed_spam_host_domains': 'allowed_spam_host_domains',
    'embed_blacklist_selector': 'blocked_embed_selectors',
    'embed_classname_whitelist': 'allowed_embed_classnames',
  }

  def up
    NAMES_MAP.each_pair do |key, value|
      DB.exec <<~SQL
        UPDATE site_settings
        SET name = '#{value}'
        WHERE name = '#{key}'
      SQL
    end
  end

  def down
    NAMES_MAP.each_pair do |key, value|
      DB.exec <<~SQL
        UPDATE site_settings
        SET name = '#{key}'
        WHERE name = '#{value}'
      SQL
    end
  end
end
