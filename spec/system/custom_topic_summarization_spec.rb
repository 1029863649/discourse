# frozen_string_literal: true

RSpec.describe "Topic custom summarization", type: :system, js: true do
  fab!(:user) { Fabricate(:admin) }

  # has_summary to force topic map to be present.
  fab!(:topic) { Fabricate(:topic, has_summary: true) }
  fab!(:post_1) { Fabricate(:post, topic: topic) }
  fab!(:post_2) { Fabricate(:post, topic: topic) }

  let(:plugin) { Plugin::Instance.new }

  before do
    sign_in(user)
    plugin.register_summarization_strategy(DummyCustomSummarization)
    SiteSetting.summarization_strategy = DummyCustomSummarization.name
  end

  it "returns a summary using the selected timeframe" do
    visit("/t/-/#{topic.id}")

    find(".custom-summarization").click

    expect(page.has_css?(".topic-custom-summary-modal", wait: 5)).to eq(true)

    expect(find(".summary-area").text).to eq(DummyCustomSummarization::RESPONSE)
  end
end
