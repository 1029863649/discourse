# frozen_string_literal: true

describe MaxUsernameLengthValidator do
  it "checks for minimum range" do
    User.update_all('username = username || username')
    SiteSetting.min_username_length = 9

    validator = described_class.new
    expect(validator.valid_value?(8)).to eq(false)
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.max_username_length_range"))
  end

  it "checks for users with short usernames" do
    user = Fabricate(:user, username: 'jackjackjack')

    validator = described_class.new
    expect(validator.valid_value?(12)).to eq(true)

    validator = described_class.new
    expect(validator.valid_value?(11)).to eq(false)

    expect(validator.error_message).to eq(I18n.t(
      "site_settings.errors.max_username_length_exists",
      username: 'jackjackjack'
    ))
  end
end
