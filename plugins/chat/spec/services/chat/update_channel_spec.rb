# frozen_string_literal: true

RSpec.describe Chat::UpdateChannel do
  subject(:result) { described_class.call(guardian: guardian, channel_id: channel.id, **params) }

  fab!(:channel) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:admin) }

  let(:guardian) { Guardian.new(current_user) }
  let(:params) do
    {
      name: "cool channel",
      description: "a channel description",
      slug: "snail",
      allow_channel_wide_mentions: true,
      auto_join_users: false,
    }
  end

  context "when the user cannot edit the channel" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:check_channel_permission) }
  end

  context "when the user tries to edit a DM channel" do
    fab!(:channel) { Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)]) }

    it { is_expected.to fail_a_policy(:no_direct_message_channel) }
  end

  context "when channel is a category one" do
    context "when a valid user provides valid params" do
      let(:message) do
        MessageBus
          .track_publish(Chat::Publisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL) { result }
          .first
      end

      it "sets the service result as successful" do
        expect(result).to be_a_success
      end

      it "updates the channel accordingly" do
        result
        expect(channel.reload).to have_attributes(
          name: "cool channel",
          slug: "snail",
          description: "a channel description",
          allow_channel_wide_mentions: true,
          auto_join_users: false,
        )
      end

      it "publishes a MessageBus message" do
        expect(message.data).to eq(
          {
            chat_channel_id: channel.id,
            name: "cool channel",
            description: "a channel description",
            slug: "snail",
          },
        )
      end

      describe "name" do
        context "when blank" do
          before { params[:name] = "" }

          it "nils out the name" do
            result
            expect(channel.reload.name).to be_nil
          end
        end
      end

      describe "description" do
        context "when blank" do
          before do
            channel.update!(description: "something")
            params[:description] = ""
          end

          it "nils out the description" do
            result
            expect(channel.reload.description).to be_nil
          end
        end
      end

      describe "#auto_join_users" do
        context "when set to 'true'" do
          before do
            channel.update!(auto_join_users: false)
            params[:auto_join_users] = true
          end

          it "updates the model accordingly" do
            result
            expect(channel.reload).to have_attributes(auto_join_users: true)
          end

          it "auto joins users" do
            expect_enqueued_with(
              job: Jobs::Chat::AutoJoinChannelMemberships,
              args: {
                chat_channel_id: channel.id,
              },
            ) { result }
          end
        end
      end

      describe "threading_enabled" do
        context "when true" do
          it "changes the value to true" do
            channel.update!(threading_enabled: false)
            params[:threading_enabled] = true
            expect(result.channel.threading_enabled).to eq(true)
          end
        end

        context "when false" do
          it "changes the value to true" do
            channel.update!(threading_enabled: true)
            params[:threading_enabled] = false
            expect(result.channel.threading_enabled).to eq(false)
          end
        end
      end
    end
  end
end
