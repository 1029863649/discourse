# frozen_string_literal: true

module SidebarGuardian
  def can_create_public_sidebar_section?
    @user.staff?
  end

  def can_edit_sidebar_section?(sidebar_section)
    return @user.staff? if sidebar_section.public?
    return @user.staff? if sidebar_section.section_type
    is_my_own?(sidebar_section)
  end

  def can_delete_sidebar_section?(sidebar_section)
    return false if sidebar_section.section_type.present?
    return @user.staff? if sidebar_section.public?
    is_my_own?(sidebar_section)
  end
end
