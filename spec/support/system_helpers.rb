# frozen_string_literal: true

module SystemHelpers
  def sign_in(user)
    visit "/session/#{user.encoded_username}/become"
  end

  def setup_system_test
    SiteSetting.login_required = false
    SiteSetting.content_security_policy = false
    SiteSetting.force_hostname = "#{Capybara.server_host}:#{Capybara.server_port}"
    SiteSetting.external_system_avatars_enabled = false
  end

  def try_until_success(timeout: 2, frequency: 0.01)
    start ||= Time.zone.now
    backoff ||= frequency
    yield
  rescue RSpec::Expectations::ExpectationNotMetError
    raise if Time.zone.now >= start + timeout.seconds
    sleep backoff
    backoff += frequency
    retry
  end

  def visit_topic(topic)
    visit "/t/#{topic.id}"
    PageObjects::Pages::Topic.new
  end

  def visit_topic_and_open_composer(topic)
    topic_page = visit_topic(topic)
    topic_page.click_reply_button
    expect(topic_page).to have_expanded_composer
    topic_page
  end
end
