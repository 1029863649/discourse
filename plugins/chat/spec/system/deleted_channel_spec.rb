# frozen_string_literal: true

RSpec.describe "Deleted channel", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.destroy!
    sign_in(Fabricate(:user))
  end

  context "when visiting deleted channel" do
    it "redirects to homepage" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_current_path("/latest")
    end
  end
end
