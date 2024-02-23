# frozen_string_literal: true

module Chat
  class UserMention < Mention
    belongs_to :user, foreign_key: :target_id

    def identifier
      nil
    end

    def is_mass_mention?
      false
    end

    def translation_suffix
      "direct"
    end
  end
end
