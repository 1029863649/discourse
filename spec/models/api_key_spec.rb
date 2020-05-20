# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

describe ApiKey do
  fab!(:user) { Fabricate(:user) }

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :created_by }

  it 'generates a key when saving' do
    api_key = ApiKey.new
    api_key.save!
    initial_key = api_key.key
    expect(initial_key.length).to eq(64)

    # Does not overwrite key when saving again
    api_key.description = "My description here"
    api_key.save!
    expect(api_key.reload.key).to eq(initial_key)
  end

  it 'does not have the key when loading later from the database' do
    api_key = ApiKey.create!
    expect(api_key.key_available?).to eq(true)
    expect(api_key.key.length).to eq(64)

    api_key = ApiKey.find(api_key.id)
    expect(api_key.key_available?).to eq(false)
    expect { api_key.key }.to raise_error(ApiKey::KeyAccessError)
  end

  it "can lookup keys based on their hash" do
    key = ApiKey.create!.key
    expect(ApiKey.with_key(key).length).to eq(1)
  end

  it "can calculate the epoch correctly" do
    expect(ApiKey.last_used_epoch.to_datetime).to be_a(DateTime)

    SiteSetting.api_key_last_used_epoch = ""
    expect(ApiKey.last_used_epoch).to eq(nil)
  end

  it "can automatically revoke keys" do
    now = Time.now

    SiteSetting.api_key_last_used_epoch = now - 2.years
    SiteSetting.revoke_api_keys_days = 180 # 6 months

    freeze_time now - 1.year
    never_used = Fabricate(:api_key)
    used_previously = Fabricate(:api_key)
    used_previously.update(last_used_at: Time.zone.now)
    used_recently = Fabricate(:api_key)

    freeze_time now - 3.months
    used_recently.update(last_used_at: Time.zone.now)

    freeze_time now
    ApiKey.revoke_unused_keys!

    [never_used, used_previously, used_recently].each(&:reload)
    expect(never_used.revoked_at).to_not eq(nil)
    expect(used_previously.revoked_at).to_not eq(nil)
    expect(used_recently.revoked_at).to eq(nil)

    # Restore them
    [never_used, used_previously, used_recently].each { |a| a.update(revoked_at: nil) }

    # Move the epoch to 1 month ago
    SiteSetting.api_key_last_used_epoch = now - 1.month
    ApiKey.revoke_unused_keys!

    [never_used, used_previously, used_recently].each(&:reload)
    expect(never_used.revoked_at).to eq(nil)
    expect(used_previously.revoked_at).to eq(nil)
    expect(used_recently.revoked_at).to eq(nil)
  end

  describe 'API Key scope mappings' do
    it 'maps api_key permissions' do
      api_key_mappings = ApiKey::SCOPE_MAPPINGS[:topics]

      assert_responds_to(api_key_mappings.dig(:write, :action))
      assert_responds_to(api_key_mappings.dig(:read, :action))
      assert_responds_to(api_key_mappings.dig(:feed, :action))
    end

    def assert_responds_to(mapping)
      controller, method = mapping.split('#')
      controller_name = "#{controller.capitalize}Controller"
      expect(controller_name.constantize.method_defined?(method)).to eq(true)
    end
  end

  describe "#request_allowed?" do
    let(:request_mock) { OpenStruct.new(ip: '133.45.67.99') }
    let(:route_path) { { 'controller' => 'topics', 'action' => 'show', 'topic_id' => '3' } }
    let(:scope) do
      ApiKeyScope.new(resource: 'topics', action: 'read', allowed_parameters: { topic_id: '3' })
    end
    let(:key) { ApiKey.new(api_key_scopes: [scope]) }

    it 'allows the request if there are no allowed IPs' do
      key.allowed_ips = nil
      key.api_key_scopes = []

      expect(key.request_allowed?(request_mock, route_path)).to eq(true)
    end

    it 'rejects the request if the IP is not allowed' do
      key.allowed_ips = %w[115.65.76.87]

      expect(key.request_allowed?(request_mock, route_path)).to eq(false)
    end

    it 'allow the request if there are not allowed params' do
      scope.allowed_parameters = nil

      expect(key.request_allowed?(request_mock, route_path)).to eq(true)
    end

    it 'rejects the request when params are different' do
      route_path['topic_id'] = '4'

      expect(key.request_allowed?(request_mock, route_path)).to eq(false)
    end

    it 'allow the request when the scope has an alias' do
      route_path = { 'controller' => 'topics', 'action' => 'show', 'id' => '3' }

      expect(key.request_allowed?(request_mock, route_path)).to eq(true)
    end
  end
end
