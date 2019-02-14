# frozen_string_literal: true

require_dependency 'distributed_cache'

class Category < ActiveRecord::Base
  self.ignored_columns = %w{
    uploaded_meta_id
  }

  include Searchable
  include Positionable
  include HasCustomFields
  include CategoryHashtag
  include AnonCacheInvalidator
  include HasDestroyedWebHook

  REQUIRE_TOPIC_APPROVAL = 'require_topic_approval'
  REQUIRE_REPLY_APPROVAL = 'require_reply_approval'
  NUM_AUTO_BUMP_DAILY = 'num_auto_bump_daily'

  register_custom_field_type(REQUIRE_TOPIC_APPROVAL, :boolean)
  register_custom_field_type(REQUIRE_REPLY_APPROVAL, :boolean)
  register_custom_field_type(NUM_AUTO_BUMP_DAILY, :integer)

  belongs_to :topic, dependent: :destroy
  belongs_to :topic_only_relative_url,
              -> { select "id, title, slug" },
              class_name: "Topic",
              foreign_key: "topic_id"

  belongs_to :user
  belongs_to :latest_post, class_name: "Post"
  belongs_to :uploaded_logo, class_name: "Upload"
  belongs_to :uploaded_background, class_name: "Upload"

  has_many :topics
  has_many :category_users
  has_many :category_featured_topics
  has_many :featured_topics, through: :category_featured_topics, source: :topic

  has_many :category_groups, dependent: :destroy
  has_many :groups, through: :category_groups

  has_and_belongs_to_many :web_hooks

  validates :user_id, presence: true
  validates :name, if: Proc.new { |c| c.new_record? || c.will_save_change_to_name? },
                   presence: true,
                   uniqueness: { scope: :parent_category_id, case_sensitive: false },
                   length: { in: 1..50 }
  validates :num_featured_topics, numericality: { only_integer: true, greater_than: 0 }
  validate :parent_category_validator

  validate :email_in_validator

  validate :ensure_slug

  validate :permissions_compatibility_validator

  validates :auto_close_hours, numericality: { greater_than: 0, less_than_or_equal_to: 87600 }, allow_nil: true

  after_create :create_category_definition

  before_save :apply_permissions
  before_save :downcase_email
  before_save :downcase_name

  after_save :publish_discourse_stylesheet
  after_save :publish_category
  after_save :reset_topic_ids_cache
  after_save :clear_url_cache
  after_save :index_search

  after_destroy :reset_topic_ids_cache
  after_destroy :publish_category_deletion
  after_destroy :remove_site_settings

  after_create :delete_category_permalink

  after_update :rename_category_definition, if: :saved_change_to_name?
  after_update :create_category_permalink, if: :saved_change_to_slug?

  after_commit :trigger_category_created_event, on: :create
  after_commit :trigger_category_updated_event, on: :update
  after_commit :trigger_category_destroyed_event, on: :destroy

  belongs_to :parent_category, class_name: 'Category'
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id'

  has_many :category_tags, dependent: :destroy
  has_many :tags, through: :category_tags
  has_many :category_tag_groups, dependent: :destroy
  has_many :tag_groups, through: :category_tag_groups

  scope :latest, -> { order('topic_count DESC') }

  scope :secured, -> (guardian = nil) {
    ids = guardian.secure_category_ids if guardian

    if ids.present?
      where("NOT categories.read_restricted OR categories.id IN (:cats)", cats: ids).references(:categories)
    else
      where("NOT categories.read_restricted").references(:categories)
    end
  }

  TOPIC_CREATION_PERMISSIONS ||= [:full]
  POST_CREATION_PERMISSIONS  ||= [:create_post, :full]
  scope :topic_create_allowed, -> (guardian) { scoped_to_permissions(guardian, TOPIC_CREATION_PERMISSIONS) }
  scope :post_create_allowed,  -> (guardian) { scoped_to_permissions(guardian, POST_CREATION_PERMISSIONS) }

  delegate :post_template, to: 'self.class'

  # permission is just used by serialization
  # we may consider wrapping this in another spot
  attr_accessor :displayable_topics, :permission, :subcategory_ids, :notification_level, :has_children

  # Allows us to skip creating the category definition topic in tests.
  attr_accessor :skip_category_definition

  @topic_id_cache = DistributedCache.new('category_topic_ids')

  def self.topic_ids
    @topic_id_cache['ids'] || reset_topic_ids_cache
  end

  def self.reset_topic_ids_cache
    @topic_id_cache['ids'] = Set.new(Category.pluck(:topic_id).compact)
  end

  def reset_topic_ids_cache
    Category.reset_topic_ids_cache
  end

  def self.scoped_to_permissions(guardian, permission_types)
    if guardian.try(:is_admin?)
      all
    elsif !guardian || guardian.anonymous?
      if permission_types.include?(:readonly)
        where("NOT categories.read_restricted")
      else
        where("1 = 0")
      end
    else
      permissions = permission_types.map { |p| CategoryGroup.permission_types[p] }
      where("(:staged AND LENGTH(COALESCE(email_in, '')) > 0 AND email_in_allow_strangers)
          OR categories.id NOT IN (SELECT category_id FROM category_groups)
          OR categories.id IN (
                SELECT category_id
                  FROM category_groups
                 WHERE permission_type IN (:permissions)
                   AND (group_id = :everyone OR group_id IN (SELECT group_id FROM group_users WHERE user_id = :user_id))
             )",
        staged: guardian.is_staged?,
        permissions: permissions,
        user_id: guardian.user.id,
        everyone: Group[:everyone].id)
    end
  end

  def self.update_stats
    topics_with_post_count = Topic
      .select("topics.category_id, COUNT(*) topic_count, SUM(topics.posts_count) post_count")
      .where("topics.id NOT IN (select cc.topic_id from categories cc WHERE topic_id IS NOT NULL)")
      .group("topics.category_id")
      .visible.to_sql

    DB.exec <<~SQL
      UPDATE categories c
         SET topic_count = x.topic_count,
             post_count = x.post_count
        FROM (#{topics_with_post_count}) x
       WHERE x.category_id = c.id
         AND (c.topic_count <> x.topic_count OR c.post_count <> x.post_count)
    SQL

    # Yes, there are a lot of queries happening below.
    # Performing a lot of queries is actually faster than using one big update
    # statement with sub-selects on large databases with many categories,
    # topics, and posts.
    #
    # The old method with the one query is here:
    # https://github.com/discourse/discourse/blob/5f34a621b5416a53a2e79a145e927fca7d5471e8/app/models/category.rb
    #
    # If you refactor this, test performance on a large database.

    Category.all.each do |c|
      topics = c.topics.visible
      topics = topics.where(['topics.id <> ?', c.topic_id]) if c.topic_id
      c.topics_year  = topics.created_since(1.year.ago).count
      c.topics_month = topics.created_since(1.month.ago).count
      c.topics_week  = topics.created_since(1.week.ago).count
      c.topics_day   = topics.created_since(1.day.ago).count

      posts = c.visible_posts
      c.posts_year  = posts.created_since(1.year.ago).count
      c.posts_month = posts.created_since(1.month.ago).count
      c.posts_week  = posts.created_since(1.week.ago).count
      c.posts_day   = posts.created_since(1.day.ago).count

      c.save if c.changed?
    end
  end

  def visible_posts
    query = Post.joins(:topic)
      .where(['topics.category_id = ?', self.id])
      .where('topics.visible = true')
      .where('posts.deleted_at IS NULL')
      .where('posts.user_deleted = false')
    self.topic_id ? query.where(['topics.id <> ?', self.topic_id]) : query
  end

  # Internal: Generate the text of post prompting to enter category description.
  def self.post_template
    I18n.t("category.post_template", replace_paragraph: I18n.t("category.replace_paragraph"))
  end

  def create_category_definition
    return if skip_category_definition

    t = Topic.new(title: I18n.t("category.topic_prefix", category: name), user: user, pinned_at: Time.now, category_id: id)
    t.skip_callbacks = true
    t.ignore_category_auto_close = true
    t.delete_topic_timer(TopicTimer.types[:close])
    t.save!(validate: false)
    update_column(:topic_id, t.id)
    t.posts.create(raw: description || post_template, user: user)
  end

  def topic_url
    if has_attribute?("topic_slug")
      Topic.relative_url(topic_id, read_attribute(:topic_slug))
    else
      topic_only_relative_url.try(:relative_url)
    end
  end

  def description_text
    return nil unless self.description

    @@cache ||= LruRedux::ThreadSafeCache.new(1000)
    @@cache.getset(self.description) do
      Nokogiri::HTML.fragment(self.description).text.strip.html_safe
    end
  end

  def duplicate_slug?
    Category.where(slug: self.slug, parent_category_id: parent_category_id).where.not(id: id).any?
  end

  def ensure_slug
    return unless name.present?

    self.name.strip!

    if slug.present?
      # santized custom slug
      self.slug = Slug.sanitize(slug)
      errors.add(:slug, 'is already in use') if duplicate_slug?
    else
      # auto slug
      self.slug = Slug.for(name, '')
      self.slug = '' if duplicate_slug?
    end
    # only allow to use category itself id. new_record doesn't have a id.
    unless new_record?
      match_id = /^(\d+)-category/.match(self.slug)
      errors.add(:slug, :invalid) if match_id && match_id[1] && match_id[1] != self.id.to_s
    end
  end

  def slug_for_url
    slug.present? ? self.slug : "#{self.id}-category"
  end

  def publish_category
    group_ids = self.groups.pluck(:id) if self.read_restricted
    MessageBus.publish('/categories', { categories: ActiveModel::ArraySerializer.new([self]).as_json }, group_ids: group_ids)
  end

  def remove_site_settings
    SiteSetting.all_settings.each do |s|
      if s[:type] == 'category' && s[:value].to_i == self.id
        SiteSetting.send("#{s[:setting]}=", '')
      end
    end

  end

  def publish_category_deletion
    MessageBus.publish('/categories', deleted_categories: [self.id])
  end

  def parent_category_validator
    if parent_category_id
      errors.add(:base, I18n.t("category.errors.self_parent")) if parent_category_id == id
      errors.add(:base, I18n.t("category.errors.uncategorized_parent")) if uncategorized?

      grandfather_id = Category.where(id: parent_category_id).pluck(:parent_category_id).first
      errors.add(:base, I18n.t("category.errors.depth")) if grandfather_id
    end
  end

  def group_names=(names)
    # this line bothers me, destroying in AR can not seem to be queued, thinking of extending it
    category_groups.destroy_all unless new_record?
    ids = Group.where(name: names.split(",")).pluck(:id)
    ids.each do |id|
      category_groups.build(group_id: id)
    end
  end

  # will reset permission on a topic to a particular
  # set.
  #
  # Available permissions are, :full, :create_post, :readonly
  #   hash can be:
  #
  # :everyone => :full - everyone has everything
  # :everyone => :readonly, :staff => :full
  # 7 => 1  # you can pass a group_id and permission id
  def set_permissions(permissions)
    self.read_restricted, @permissions = Category.resolve_permissions(permissions)

    # Ideally we can just call .clear here, but it runs SQL, we only want to run it
    # on save.
  end

  def permissions=(permissions)
    set_permissions(permissions)
  end

  def permissions_params
    hash = {}
    category_groups.includes(:group).each do |category_group|
      if category_group.group.present?
        hash[category_group.group_name] = category_group.permission_type
      end
    end
    hash
  end

  def apply_permissions
    if @permissions
      category_groups.destroy_all
      @permissions.each do |group_id, permission_type|
        category_groups.build(group_id: group_id, permission_type: permission_type)
      end
      @permissions = nil
    end
  end

  def self.resolve_permissions(permissions)
    read_restricted = true

    everyone = Group::AUTO_GROUPS[:everyone]
    full = CategoryGroup.permission_types[:full]

    mapped = permissions.map do |group, permission|
      group_id = Group.group_id_from_param(group)
      permission = CategoryGroup.permission_types[permission] unless permission.is_a?(Integer)

      [group_id, permission]
    end

    mapped.each do |group, permission|
      if group == everyone && permission == full
        return [false, []]
      end

      read_restricted = false if group == everyone
    end

    [read_restricted, mapped]
  end

  def require_topic_approval?
    custom_fields[REQUIRE_TOPIC_APPROVAL]
  end

  def require_reply_approval?
    custom_fields[REQUIRE_REPLY_APPROVAL]
  end

  def num_auto_bump_daily
    custom_fields[NUM_AUTO_BUMP_DAILY]
  end

  def num_auto_bump_daily=(v)
    custom_fields[NUM_AUTO_BUMP_DAILY] = v
  end

  def auto_bump_limiter
    return nil if num_auto_bump_daily.to_i == 0
    RateLimiter.new(nil, "auto_bump_limit_#{self.id}", 1, 86400 / num_auto_bump_daily.to_i)
  end

  def clear_auto_bump_cache!
    auto_bump_limiter&.clear!
  end

  def self.auto_bump_topic!
    bumped = false

    auto_bumps = CategoryCustomField
      .where(name: Category::NUM_AUTO_BUMP_DAILY)
      .where('NULLIF(value, \'\')::int > 0')
      .pluck(:category_id)

    if (auto_bumps.length > 0)
      auto_bumps.shuffle.each do |category_id|
        bumped = Category.find_by(id: category_id)&.auto_bump_topic!
        break if bumped
      end
    end

    bumped
  end

  # will automatically bump a single topic
  # if number of automatically bumped topics is smaller than threshold
  def auto_bump_topic!
    return false if num_auto_bump_daily.to_i == 0

    limiter = auto_bump_limiter
    return false if !limiter.can_perform?

    filters = []
    DiscourseEvent.trigger(:filter_auto_bump_topics, self, filters)

    relation = Topic

    if filters.length > 0
      filters.each do |filter|
        relation = filter.call(relation)
      end
    end

    topic = relation
      .visible
      .listable_topics
      .where(category_id: self.id)
      .where('id <> ?', self.topic_id)
      .where('bumped_at < ?', 1.day.ago)
      .where('pinned_at IS NULL AND NOT closed AND NOT archived')
      .order('bumped_at ASC')
      .limit(1)
      .first

    if topic
      topic.add_small_action(Discourse.system_user, "autobumped", nil, bump: true)
      limiter.performed!
      true
    else
      false
    end

  end

  def allowed_tags=(tag_names_arg)
    DiscourseTagging.add_or_create_tags_by_name(self, tag_names_arg, unlimited: true)
  end

  def allowed_tag_groups=(group_names)
    self.tag_groups = TagGroup.where(name: group_names).all.to_a
  end

  def downcase_email
    self.email_in = (email_in || "").strip.downcase.presence
  end

  def email_in_validator
    return if self.email_in.blank?
    email_in.split("|").each do |email|

      escaped = Rack::Utils.escape_html(email)
      if !Email.is_valid?(email)
        self.errors.add(:base, I18n.t('category.errors.invalid_email_in', email: escaped))
      elsif group = Group.find_by_email(email)
        self.errors.add(:base, I18n.t('category.errors.email_already_used_in_group', email: escaped, group_name: Rack::Utils.escape_html(group.name)))
      elsif category = Category.where.not(id: self.id).find_by_email(email)
        self.errors.add(:base, I18n.t('category.errors.email_already_used_in_category', email: escaped, category_name: Rack::Utils.escape_html(category.name)))
      end
    end
  end

  def downcase_name
    self.name_lower = name.downcase if self.name
  end

  def visible_group_names(user)
    self.groups.visible_groups(user)
  end

  def secure_group_ids
    if self.read_restricted?
      groups.pluck("groups.id")
    end
  end

  def update_latest
    latest_post_id = Post
      .order("posts.created_at desc")
      .where("NOT hidden")
      .joins("join topics on topics.id = topic_id")
      .where("topics.category_id = :id", id: self.id)
      .limit(1)
      .pluck("posts.id")
      .first

    latest_topic_id = Topic
      .order("topics.created_at desc")
      .where("visible")
      .where("topics.category_id = :id", id: self.id)
      .limit(1)
      .pluck("topics.id")
      .first

    self.update_attributes(latest_topic_id: latest_topic_id, latest_post_id: latest_post_id)
  end

  def self.query_parent_category(parent_slug)
    self.where(slug: parent_slug, parent_category_id: nil).pluck(:id).first ||
    self.where(id: parent_slug.to_i).pluck(:id).first
  end

  def self.query_category(slug_or_id, parent_category_id)
    self.where(slug: slug_or_id, parent_category_id: parent_category_id).first ||
    self.where(id: slug_or_id.to_i, parent_category_id: parent_category_id).first
  end

  def self.find_by_email(email)
    self.where("string_to_array(email_in, '|') @> ARRAY[?]", Email.downcase(email)).first
  end

  def has_children?
    @has_children ||= (id && Category.where(parent_category_id: id).exists?) ? :true : :false
    @has_children == :true
  end

  def uncategorized?
    id == SiteSetting.uncategorized_category_id
  end

  @@url_cache = DistributedCache.new('category_url')

  def clear_url_cache
    @@url_cache.clear
  end

  def full_slug(separator = "-")
    start_idx = "#{Discourse.base_uri}/c/".length
    url[start_idx..-1].gsub("/", separator)
  end

  def url
    url = @@url_cache[self.id]
    unless url
      url = +"#{Discourse.base_uri}/c"
      url << "/#{parent_category.slug}" if parent_category_id
      url << "/#{slug}"
      @@url_cache[self.id] = -url
    end

    url
  end

  def url_with_id
    self.parent_category ? "#{url}/#{self.id}" : "#{Discourse.base_uri}/c/#{self.id}-#{self.slug}"
  end

  # If the name changes, try and update the category definition topic too if it's
  # an exact match
  def rename_category_definition
    old_name = saved_changes.transform_values(&:first)["name"]
    return unless topic.present?
    if topic.title == I18n.t("category.topic_prefix", category: old_name)
      topic.update_attribute(:title, I18n.t("category.topic_prefix", category: name))
    end
  end

  def create_category_permalink
    old_slug = saved_changes.transform_values(&:first)["slug"]
    url = +"#{Discourse.base_uri}/c"
    url << "/#{parent_category.slug}" if parent_category_id
    url << "/#{old_slug}"

    if Permalink.where(url: url).exists?
      Permalink.where(url: url).update_all(category_id: id)
    else
      Permalink.create(url: url, category_id: id)
    end
  end

  def delete_category_permalink
    if self.parent_category
      permalink = Permalink.find_by_url("c/#{self.parent_category.slug}/#{slug}")
    else
      permalink = Permalink.find_by_url("c/#{slug}")
    end
    permalink.destroy if permalink
  end

  def publish_discourse_stylesheet
    Stylesheet::Manager.cache.clear
  end

  def index_search
    SearchIndexer.index(self)
  end

  def self.find_by_slug(category_slug, parent_category_slug = nil)
    if parent_category_slug
      parent_category_id = self.where(slug: parent_category_slug, parent_category_id: nil).pluck(:id).first
      self.where(slug: category_slug, parent_category_id: parent_category_id).first
    else
      self.where(slug: category_slug, parent_category_id: nil).first
    end
  end

  def subcategory_list_includes_topics?
    subcategory_list_style.end_with?("with_featured_topics")
  end

  %i{
    category_created
    category_updated
    category_destroyed
  }.each do |event|
    define_method("trigger_#{event}_event") do
      DiscourseEvent.trigger(event, self)
      true
    end
  end

  def permissions_compatibility_validator
    # when saving subcategories
    if @permissions && parent_category_id.present?
      return if parent_category.category_groups.empty?

      parent_permissions = parent_category.category_groups.pluck(:group_id, :permission_type)
      child_permissions = @permissions.empty? ? [[Group[:everyone].id, CategoryGroup.permission_types[:full]]] : @permissions
      check_permissions_compatibility(parent_permissions, child_permissions)

    # when saving parent category
    elsif @permissions && subcategories.present?
      return if @permissions.empty?

      parent_permissions = @permissions
      child_permissions = subcategories_permissions.uniq

      check_permissions_compatibility(parent_permissions, child_permissions)
    end
  end

  private

  def check_permissions_compatibility(parent_permissions, child_permissions)
    parent_groups = parent_permissions.map(&:first)
    child_groups = child_permissions.map(&:first)
    only_in_subcategory = child_groups - parent_groups

    errors.add(:base, I18n.t("category.errors.permission_conflict")) if only_in_subcategory.present?
  end

  def subcategories_permissions
    CategoryGroup.joins(:category)
      .where(['categories.parent_category_id = ?', self.id])
      .pluck(:group_id, :permission_type)
      .uniq
  end
end

# == Schema Information
#
# Table name: categories
#
#  id                                :integer          not null, primary key
#  name                              :string(50)       not null
#  color                             :string(6)        default("0088CC"), not null
#  topic_id                          :integer
#  topic_count                       :integer          default(0), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  user_id                           :integer          not null
#  topics_year                       :integer          default(0)
#  topics_month                      :integer          default(0)
#  topics_week                       :integer          default(0)
#  slug                              :string           not null
#  description                       :text
#  text_color                        :string(6)        default("FFFFFF"), not null
#  read_restricted                   :boolean          default(FALSE), not null
#  auto_close_hours                  :float
#  post_count                        :integer          default(0), not null
#  latest_post_id                    :integer
#  latest_topic_id                   :integer
#  position                          :integer
#  parent_category_id                :integer
#  posts_year                        :integer          default(0)
#  posts_month                       :integer          default(0)
#  posts_week                        :integer          default(0)
#  email_in                          :string
#  email_in_allow_strangers          :boolean          default(FALSE)
#  topics_day                        :integer          default(0)
#  posts_day                         :integer          default(0)
#  allow_badges                      :boolean          default(TRUE), not null
#  name_lower                        :string(50)       not null
#  auto_close_based_on_last_post     :boolean          default(FALSE)
#  topic_template                    :text
#  contains_messages                 :boolean
#  sort_order                        :string
#  sort_ascending                    :boolean
#  uploaded_logo_id                  :integer
#  uploaded_background_id            :integer
#  topic_featured_link_allowed       :boolean          default(TRUE)
#  all_topics_wiki                   :boolean          default(FALSE), not null
#  show_subcategory_list             :boolean          default(FALSE)
#  num_featured_topics               :integer          default(3)
#  default_view                      :string(50)
#  subcategory_list_style            :string(50)       default("rows_with_featured_topics")
#  default_top_period                :string(20)       default("all")
#  mailinglist_mirror                :boolean          default(FALSE), not null
#  suppress_from_latest              :boolean          default(FALSE)
#  minimum_required_tags             :integer          default(0), not null
#  navigate_to_first_post_after_read :boolean          default(FALSE), not null
#
# Indexes
#
#  index_categories_on_email_in     (email_in) UNIQUE
#  index_categories_on_topic_count  (topic_count)
#  unique_index_categories_on_name  (COALESCE(parent_category_id, '-1'::integer), name) UNIQUE
#
