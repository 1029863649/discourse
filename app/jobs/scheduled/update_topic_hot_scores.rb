# frozen_string_literal: true

module Jobs
  class UpdateTopicHotScores < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      TopicHotScore.update_scores if SiteSetting.top_menu_map.include? "hot"
    end
  end
end
