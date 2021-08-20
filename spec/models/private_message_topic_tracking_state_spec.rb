# frozen_string_literal: true

require 'rails_helper'

describe PrivateMessageTopicTrackingState do
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  fab!(:group) do
    Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
      g.add(user_2)
    end
  end

  fab!(:group_message) do
    create_post(
      user: user,
      target_group_names: [group.name],
      archetype: Archetype.private_message
    ).topic
  end

  fab!(:private_message) do
    create_post(
      user: user,
      target_usernames: [user_2.username],
      archetype: Archetype.private_message
    ).topic
  end

  fab!(:private_message_2) do
    create_post(
      user: user,
      target_usernames: [Fabricate(:user).username],
      archetype: Archetype.private_message
    ).topic
  end

  describe '.report' do
    it 'returns the right tracking state' do
      TopicUser.find_by(user: user_2, topic: group_message).update!(
        last_read_post_number: 1
      )

      expect(described_class.report(user_2).map(&:topic_id))
        .to contain_exactly(private_message.id)

      create_post(user: user, topic: group_message)

      report = described_class.report(user_2)

      expect(report.map(&:topic_id)).to contain_exactly(
        group_message.id,
        private_message.id
      )

      state = report.first

      expect(state.topic_id).to eq(private_message.id)
      expect(state.user_id).to eq(user_2.id)
      expect(state.last_read_post_number).to eq(nil)
      expect(state.notification_level).to eq(NotificationLevels.all[:watching])
      expect(state.highest_post_number).to eq(1)
      expect(state.group_ids).to eq([])

      expect(report.last.group_ids).to contain_exactly(group.id)
    end

    it 'returns the right tracking state when topics contain whispers' do
      TopicUser.find_by(user: user_2, topic: private_message).update!(
        last_read_post_number: 1
      )

      create_post(
        raw: "this is a test post",
        topic: private_message,
        post_type: Post.types[:whisper],
        user: Fabricate(:admin)
      )

      expect(described_class.report(user_2).map(&:topic_id))
        .to contain_exactly(group_message.id)

      user_2.grant_admin!

      tracking_state = described_class.report(user_2)

      expect(tracking_state.map { |topic| [topic.topic_id, topic.highest_post_number] })
        .to contain_exactly(
          [group_message.id, 1],
          [private_message.id, 2]
        )
    end

    it 'returns the right tracking state when topics have been dismissed' do
      DismissedTopicUser.create!(
        user_id: user_2.id,
        topic_id: group_message.id
      )

      expect(described_class.report(user_2).map(&:topic_id))
        .to contain_exactly(private_message.id)
    end

    it 'does not include unread topics which are too old' do

    end
  end

  describe '.publish_new' do
    it 'should publish the right message_bus message' do
      messages = MessageBus.track_publish do
        described_class.publish_new(private_message)
      end

      expect(messages.map(&:channel)).to contain_exactly(
        "#{described_class::CHANNEL_PREFIX}/#{user.id}",
        "#{described_class::CHANNEL_PREFIX}/#{user_2.id}"
      )

      data = messages.first.data

      expect(data['message_type']).to eq(described_class::NEW_MESSAGE_TYPE)
    end

    it 'should publish the right message_bus message for a group message' do
      messages = MessageBus.track_publish do
        described_class.publish_new(group_message)
      end

      expect(messages.map(&:channel)).to contain_exactly(
        "#{described_class::CHANNEL_PREFIX}/#{user.id}",
        "#{described_class::CHANNEL_PREFIX}/#{user_2.id}"
      )

      data = messages.first.data

      expect(data['message_type']).to eq(described_class::NEW_MESSAGE_TYPE)
      expect(data['topic_id']).to eq(group_message.id)
      expect(data['payload']['last_read_post_number']).to eq(nil)
      expect(data['payload']['highest_post_number']).to eq(1)
      expect(data['payload']['group_ids']).to eq([group.id])
    end
  end

  describe '.publish_unread' do
    it 'should publish the right message_bus message' do
      messages = MessageBus.track_publish do
        described_class.publish_unread(private_message.first_post)
      end

      expect(messages.map(&:channel)).to contain_exactly(
        "#{described_class::CHANNEL_PREFIX}/#{user.id}",
        "#{described_class::CHANNEL_PREFIX}/#{user_2.id}"
      )

      data = messages.first.data

      expect(data['message_type']).to eq(described_class::UNREAD_MESSAGE_TYPE)
      expect(data['topic_id']).to eq(private_message.id)
      expect(data['payload']['last_read_post_number']).to eq(1)
      expect(data['payload']['highest_post_number']).to eq(1)
      expect(data['payload']['notification_level'])
        .to eq(NotificationLevels.all[:watching])
      expect(data['payload']['group_ids']).to eq([])
    end
  end
end
