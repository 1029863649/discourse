# frozen_string_literal: true

# A cool class
class Chat::ChannelDestroyer
  include ChatService

  DELETE_CHANNEL_LOG_KEY = "chat_channel_delete"

  before_contract { guardian(:can_delete_chat_channel?) }

  contract do
    attribute :channel
    validates :channel, presence: true
  end

  service do
    ChatChannel.transaction do
      prevents_slug_collision
      soft_delete_channel
      log_channel_deletion
    end

    enqueue_delete_channel_relations_job
  end

  private

  def soft_delete_channel
    context.channel.trash!(context.guardian.user)
  end

  def enqueue_delete_channel_relations_job
    Jobs.enqueue(:chat_channel_delete, chat_channel_id: context.channel.id)
  end

  def log_channel_deletion
    StaffActionLogger.new(context.guardian.user).log_custom(
      DELETE_CHANNEL_LOG_KEY,
      {
        chat_channel_id: context.channel.id,
        chat_channel_name: context.channel.title(context.guardian.user),
      },
    )
  end

  def prevents_slug_collision
    context.channel.update!(slug: generate_deleted_slug)
  end

  def generate_deleted_slug
    "#{Time.now.strftime("%Y%m%d-%H%M")}-#{context.channel.slug}-deleted".truncate(
      SiteSetting.max_topic_title_length,
      omission: "",
    )
  end
end
