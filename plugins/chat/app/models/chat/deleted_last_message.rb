# frozen_string_literal: true

module Chat
  class DeletedLastMessage < Chat::Message
    def user
      nil
    end

    def excerpt(max_length: nil)
      nil
    end

    def id
      nil
    end

    def created_at
      Time.now # a proper NullTime object would be better, but this is good enough for now
    end
  end
end
