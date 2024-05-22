# frozen_string_literal: true

describe "glimmer topic list", type: :system do
  fab!(:user)

  before do
    SiteSetting.experimental_glimmer_topic_list_groups = "1"
    sign_in(user)
  end

  describe "/latest" do
    let(:topic_list) { PageObjects::Components::TopicList.new }

    it "shows the list" do
      Fabricate.times(5, :topic)
      visit("/latest")

      expect(topic_list).to have_topics(count: 5)
    end
  end

  describe "categories-with-featured-topics page" do
    let(:category_list) { PageObjects::Components::CategoryList.new }

    it "shows the list" do
      SiteSetting.desktop_category_page_style = "categories_with_featured_topics"
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      topic2 = Fabricate(:topic)
      CategoryFeaturedTopic.feature_topics

      visit("/categories")

      expect(category_list).to have_topic(topic)
      expect(category_list).to have_topic(topic2)
    end
  end

  describe "suggested topics" do
    let(:topic_page) { PageObjects::Pages::Topic.new }

    it "shows the list" do
      topic = Fabricate(:post).topic
      topic2 = Fabricate(:post).topic
      visit(topic.relative_url)

      expect(topic_page).to have_suggested_topic(topic2)
    end
  end
end
