class WebHook < ActiveRecord::Base
  has_and_belongs_to_many :web_hook_event_types
  has_and_belongs_to_many :groups
  has_and_belongs_to_many :categories

  has_many :web_hook_events, dependent: :destroy

  default_scope { order('id ASC') }

  validates :payload_url, presence: true, format: URI::regexp(%w(http https))
  validates :secret, length: { minimum: 12 }, allow_blank: true
  validates_presence_of :content_type
  validates_presence_of :last_delivery_status
  validates_presence_of :web_hook_event_types, unless: :wildcard_web_hook?

  def self.content_types
    @content_types ||= Enum.new('application/json' => 1,
                                'application/x-www-form-urlencoded' => 2)
  end

  def self.last_delivery_statuses
    @last_delivery_statuses ||= Enum.new(inactive: 1,
                                         failed: 2,
                                         successful: 3)
  end

  def self.default_event_types
    [WebHookEventType.find(WebHookEventType::POST)]
  end

  def self.find_by_type(type)
    WebHook.where(active: true)
           .joins(:web_hook_event_types)
           .where("web_hooks.wildcard_web_hook = ? OR web_hook_event_types.name = ?", true, type.to_s)
  end

  def self.enqueue_hooks(type, opts = {})
    find_by_type(type).each do |w|
      Jobs.enqueue(:emit_web_hook_event, opts.merge(web_hook_id: w.id, event_type: type.to_s))
    end
  end

  TOPIC_HOOK_2_ARGS = Proc.new do |topic, user|
    WebHook.enqueue_hooks(:topic, topic_id: topic.id, user_id: user&.id, category_id: topic&.category&.id)
  end

  TOPIC_HOOK_3_ARGS = Proc.new do |topic, _, user|
    WebHook.enqueue_hooks(:topic, topic_id: topic.id, user_id: user&.id, category_id: topic&.category&.id)
  end

  POST_HOOK = Proc.new do |post, _, user|
    WebHook.enqueue_hooks(:post, post_id: post.id, topic_id: post&.topic&.id, user_id: user&.id, category_id: post.topic&.category&.id)
  end

  %i(topic_destroyed topic_recovered).each { |event| DiscourseEvent.on(event, &TOPIC_HOOK_2_ARGS) }

  DiscourseEvent.on(:topic_created, &TOPIC_HOOK_3_ARGS)

  %i(post_created
     post_destroyed
     post_recovered
     validate_post).each { |event| DiscourseEvent.on(event, &POST_HOOK) }
end

# == Schema Information
#
# Table name: web_hooks
#
#  id                   :integer          not null, primary key
#  payload_url          :string           not null
#  content_type         :integer          default(1), not null
#  last_delivery_status :integer          default(1), not null
#  secret               :string           default("")
#  wildcard_web_hook    :boolean          default(FALSE), not null
#  verify_certificate   :boolean          default(TRUE), not null
#  active               :boolean          default(FALSE), not null
#  created_at           :datetime
#  updated_at           :datetime
#
