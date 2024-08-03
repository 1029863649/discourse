# frozen_string_literal: true

describe "Admin Flags Page", type: :system do
  fab!(:admin)
  fab!(:post)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:admin_flags_page) { PageObjects::Pages::AdminFlags.new }
  let(:admin_flag_form_page) { PageObjects::Pages::AdminFlagForm.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }

  before { sign_in(admin) }

  it "allows admin to disable, change order, create, update and delete flags" do
    # disable
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    admin_flags_page.visit.toggle("spam")
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices("It's Inappropriate", "It's Illegal", "Something Else")

    Flag.system.where(name: "spam").update!(enabled: true)

    # change order
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    admin_flags_page.visit.move_down("spam")
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Illegal",
      "It's Spam",
      "Something Else",
    )

    admin_flags_page.visit.move_up("spam")
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    # create
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    admin_flags_page.visit.click_add_flag
    admin_flag_form_page
      .fill_in_name("Vulgar")
      .fill_in_description("New flag description")
      .select_applies_to("Topic")
      .select_applies_to("Post")
      .click_save

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Illegal",
      "Something Else",
      "Vulgar",
    )

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
      "Vulgar",
    )

    # update
    admin_flags_page.visit.click_edit_flag("vulgar")
    admin_flag_form_page.fill_in_name("Tasteless").click_save

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Illegal",
      "Something Else",
      "Tasteless",
    )

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
      "Tasteless",
    )

    # delete
    admin_flags_page.visit.click_delete_flag("tasteless").confirm_delete

    expect(admin_flags_page).to have_saved_flag("tasteless")

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )
  end

  it "does not allow to move notify user flag" do
    admin_flags_page.visit
    expect(page).not_to have_css(".notify_user .flag-menu-trigger")
  end

  it "does not allow bottom flag to move down" do
    admin_flags_page.visit.open_flag_menu("notify_moderators")
    expect(page).not_to have_css(".dropdown-menu__item .move-down")
  end

  it "does not allow to system flag to be edited" do
    admin_flags_page.visit
    expect(page).to have_css(".off_topic .admin-flag-item__edit[disabled]")
  end

  it "does not allow to system flag to be deleted" do
    admin_flags_page.visit.open_flag_menu("notify_moderators")
    expect(page).to have_css(".admin-flag-item__delete[disabled]")
  end

  it "does not allow top flag to move up" do
    admin_flags_page.visit.open_flag_menu("off_topic")
    expect(page).not_to have_css(".dropdown-menu__item .move-up")
  end
end
