# frozen_string_literal: true

RSpec.describe Chat::CreateMessageInteraction do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(message_id: nil, action_id: nil) }

    it { is_expected.to validate_presence_of :message_id }
    it { is_expected.to validate_presence_of :action_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:message) do
      Fabricate(
        :chat_message,
        user: Discourse.system_user,
        blocks: [
          {
            type: "actions",
            elements: [
              {
                action_id: "xxx",
                value: "foo",
                type: "button",
                text: {
                  type: "plain_text",
                  text: "Click Me",
                },
              },
            ],
          },
        ],
      )
    end

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { message_id: message.id } }
    let(:dependencies) { { guardian: } }

    before { params[:action_id] = message.blocks[0]["elements"][0]["action_id"] }

    context "when all steps pass" do
      before { message.chat_channel.add(current_user) }

      it { is_expected.to run_successfully }

      it "creates the interaction" do
        expect(result.interaction).to have_attributes(
          user: current_user,
          message: message,
          action: message.blocks[0]["elements"][0],
        )
      end

      it "triggers an event" do
        events = DiscourseEvent.track_events { result }

        expect(events).to include(
          event_name: :chat_message_interaction,
          params: [result.interaction],
        )
      end
    end

    context "when user doesn't have access to the channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }

      before { message.update!(chat_channel: channel) }

      it { is_expected.to fail_a_policy(:can_interact_with_message) }
    end

    context "when the action doesn’t exist" do
      before { params[:action_id] = "yyy" }

      it { is_expected.to fail_to_find_a_model(:action) }
    end
  end
end
