# frozen_string_literal: true

module PageObjects
  module Components
    class TopicListHeader < PageObjects::Components::Base
      TOPIC_LIST_HEADER_SELECTOR = ".topic-list .topic-list-header"
      TOPIC_LIST_DATA_SELECTOR = "#{TOPIC_LIST_HEADER_SELECTOR} .topic-list-data"

      def topic_list_header
        TOPIC_LIST_HEADER_SELECTOR
      end

      def has_bulk_select_button?
        page.has_css?("#{TOPIC_LIST_HEADER_SELECTOR} button.bulk-select")
      end

      def click_bulk_select_button
        find("#{TOPIC_LIST_HEADER_SELECTOR} button.bulk-select").click
      end

      def has_bulk_select_topics_dropdown?
        page.has_css?(
          "#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics div.bulk-select-topics-dropdown",
        )
      end

      def click_bulk_select_topics_dropdown
        find(
          "#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics div.bulk-select-topics-dropdown",
        ).click
      end

      def click_bulk_button(name)
        find(bulk_select_dropdown_item(name)).click
      end

      private

      def bulk_select_dropdown_item(name)
        "#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics div.bulk-select-topics-dropdown li[data-value='#{name}']"
      end
    end
  end
end
