# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateInvite < PageObjects::Pages::Base
      GRANTABLE_BADGES_DROPDOWN = ".select-kit"

      def modal
        find(".create-invite-modal")
      end

      def edit_options_link
        within(modal) { find(".edit-link-options") }
      end

      def save_button
        within(modal) { find(".save-invite") }
      end

      def cancel_button
        within(modal) { find(".cancel-button") }
      end

      def copy_button
        within(modal) { find(".copy-button") }
      end

      def invite_link_input
        within(modal) { find("input.invite-link") }
      end

      def link_limits_info_paragraph
        within(modal) { find("p.link-limits-info") }
      end

      def form
        PageObjects::Components::FormKit.new(".create-invite-modal .form-kit")
      end
    end
  end
end
