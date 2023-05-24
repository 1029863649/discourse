# frozen_string_literal: true

module Chat
  # Queries messages for a specific channel. This can be used in two modes:
  #
  # 1. Query messages around a target_message_id. This is used when a user
  #    needs to jump to the middle of a messages stream or load around their
  #    last read message ID. There is no pagination or direction here, just
  #    a limit on past and future messages.
  # 2. Query messages with paginations and direction. This is used for normal
  #    scrolling of the messages stream of a channel.
  #
  # In both scenarios a thread_id can be provided to only get messages related
  # to that thread within the channel.
  #
  # It is assumed that the user's permission to view the channel has already been
  # established by the caller.
  class MessagesQuery
    PAST_MESSAGE_LIMIT = 20
    FUTURE_MESSAGE_LIMIT = 20
    PAST = "past"
    FUTURE = "future"
    VALID_DIRECTIONS = [PAST, FUTURE]
    MAX_PAGE_SIZE = 100

    # @param channel [Chat::Channel] The channel to query messages within.
    # @param guardian [Guardian] The guardian to use for permission checks.
    # @param thread_id [Integer] (optional) The thread ID to filter messages by.
    # @param target_message_id [Integer] (optional) The message ID to query around.
    #   It is assumed that the caller already checked if this exists.
    # @param include_thread_messages [Boolean] (optional) Whether to include messages
    #   that are linked to a thread.
    # @param page_size [Integer] (optional) The number of messages to fetch when not
    #   using the target_message_id param.
    # @param direction [String] (optional) The direction to fetch messages in when not
    #   using the target_message_id param. Must be valid. If not provided, only the
    #   latest messages for the channel are loaded.
    def self.call(
      channel:,
      guardian:,
      thread_id: nil,
      target_message_id: nil,
      include_thread_messages: false,
      page_size: PAST_MESSAGE_LIMIT + FUTURE_MESSAGE_LIMIT,
      direction: nil
    )
      messages = base_query(channel: channel)
      messages = messages.with_deleted if guardian.can_moderate_chat?(channel.chatable)
      if thread_id.present?
        include_thread_messages = true
        messages = messages.where(thread_id: thread_id)
      end
      messages = messages.where(<<~SQL, channel_id: channel.id) if !include_thread_messages
        chat_messages.thread_id IS NULL OR chat_messages.id IN (
          SELECT original_message_id
          FROM chat_threads
          WHERE chat_threads.channel_id = :channel_id
        )
      SQL

      if target_message_id.present? && direction.blank?
        query_around_target(target_message_id, channel, messages)
      else
        query_paginated_messages(direction, page_size, channel, messages, target_message_id)
      end
    end

    def self.base_query(channel:)
      query =
        Chat::Message
          .includes(in_reply_to: [:user, chat_webhook_event: [:incoming_chat_webhook]])
          .includes(:revisions)
          .includes(user: :primary_group)
          .includes(chat_webhook_event: :incoming_chat_webhook)
          .includes(reactions: :user)
          .includes(:bookmarks)
          .includes(:uploads)
          .includes(chat_channel: :chatable)
          .includes(:thread)
          .where(chat_channel_id: channel.id)

      query = query.includes(user: :user_status) if SiteSetting.enable_user_status

      query
    end

    def self.query_around_target(target_message_id, channel, messages)
      target_message = base_query(channel: channel).with_deleted.find_by(id: target_message_id)

      past_messages =
        messages
          .where("created_at < ?", target_message.created_at)
          .order(created_at: :desc)
          .limit(PAST_MESSAGE_LIMIT)
          .to_a

      future_messages =
        messages
          .where("created_at > ?", target_message.created_at)
          .order(created_at: :asc)
          .limit(FUTURE_MESSAGE_LIMIT)
          .to_a

      can_load_more_past = past_messages.size == PAST_MESSAGE_LIMIT
      can_load_more_future = future_messages.size == FUTURE_MESSAGE_LIMIT

      {
        past_messages: past_messages,
        future_messages: future_messages,
        target_message: target_message,
        can_load_more_past: can_load_more_past,
        can_load_more_future: can_load_more_future,
      }
    end

    def self.query_paginated_messages(
      direction,
      page_size,
      channel,
      messages,
      target_message_id = nil
    )
      if target_message_id.present?
        condition = direction == PAST ? "<" : ">"
        messages = messages.where("id #{condition} ?", target_message_id.to_i)
      end

      order = direction == FUTURE ? "ASC" : "DESC"
      messages = messages.order("created_at #{order}, id #{order}").limit(page_size).to_a

      if direction == FUTURE
        can_load_more_future = messages.size == page_size
      elsif direction == PAST
        can_load_more_past = messages.size == page_size
      else
        # When direction is blank, we'll return the latest messages.
        can_load_more_future = false
        can_load_more_past = messages.size == page_size
      end

      {
        messages: direction == FUTURE ? messages : messages.reverse,
        can_load_more_past: can_load_more_past,
        can_load_more_future: can_load_more_future,
      }
    end
  end
end
