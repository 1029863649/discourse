# frozen_string_literal: true

require 'rails_helper'

describe DirectoryItemsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:evil_trout) { Fabricate(:evil_trout) }
  fab!(:walter_white) { Fabricate(:walter_white) }
  fab!(:stage_user) { Fabricate(:staged, username: 'stage_user') }
  fab!(:group) { Fabricate(:group, users: [evil_trout, stage_user]) }

  it "requires a `period` param" do
    get '/directory_items.json'
    expect(response.status).to eq(400)
  end

  it "requires a proper `period` param" do
    get '/directory_items.json', params: { period: 'eviltrout' }
    expect(response).not_to be_successful
  end

  context "without data" do

    context "and a logged in user" do
      before { sign_in(user) }

      it "succeeds" do
        get '/directory_items.json', params: { period: 'all' }
        expect(response.status).to eq(200)
      end
    end

  end

  context "with data" do
    before do
      DirectoryItem.refresh!
    end

    it "succeeds with a valid value" do
      get '/directory_items.json', params: { period: 'all' }
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json).to be_present
      expect(json['directory_items']).to be_present
      expect(json['meta']['total_rows_directory_items']).to be_present
      expect(json['meta']['load_more_directory_items']).to be_present
      expect(json['meta']['last_updated_at']).to be_present

      expect(json['directory_items'].length).to eq(4)
      expect(json['meta']['total_rows_directory_items']).to eq(4)
      expect(json['meta']['load_more_directory_items']).to include('.json')
    end

    it "respects more_params in load_more_directory_items" do
      get '/directory_items.json', params: { period: 'all', order: "likes_given", group: group.name, user_field_ids: "1|2" }
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json['meta']['load_more_directory_items']).to include("group=#{group.name}")
      expect(json['meta']['load_more_directory_items']).to include("user_field_ids=#{CGI.escape('1|2')}")
      expect(json['meta']['load_more_directory_items']).to include("order=likes_given")
      expect(json['meta']['load_more_directory_items']).to include("period=all")
    end

    it "fails when the directory is disabled" do
      SiteSetting.enable_user_directory = false

      get '/directory_items.json', params: { period: 'all' }
      expect(response).not_to be_successful
    end

    it "sort username with asc as a parameter" do
      get '/directory_items.json', params: { asc: true, order: 'username', period: 'all' }
      expect(response.status).to eq(200)
      json = response.parsed_body

      names = json['directory_items'].map { |item| item['user']['username'] }
      expect(names).to eq(names.sort)
    end

    it "sort username without asc as a parameter" do
      get '/directory_items.json', params: { order: 'username', period: 'all' }
      expect(response.status).to eq(200)
      json = response.parsed_body

      names = json['directory_items'].map { |item| item['user']['username'] }

      expect(names).to eq(names.sort.reverse)
    end

    it "finds user by name" do
      get '/directory_items.json', params: { period: 'all', name: 'eviltrout' }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(1)
      expect(json['meta']['total_rows_directory_items']).to eq(1)
      expect(json['directory_items'][0]['user']['username']).to eq('eviltrout')
    end

    it "finds staged user by name" do
      get '/directory_items.json', params: { period: 'all', name: 'stage_user' }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(1)
      expect(json['meta']['total_rows_directory_items']).to eq(1)
      expect(json['directory_items'][0]['user']['username']).to eq('stage_user')
    end

    it "excludes users by username" do
      get '/directory_items.json', params: { period: 'all', exclude_usernames: "stage_user,eviltrout" }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(2)
      expect(json['meta']['total_rows_directory_items']).to eq(2)
      expect(json['directory_items'][0]['user']['username']).to eq(walter_white.username) | eq(user.username)
      expect(json['directory_items'][1]['user']['username']).to eq(walter_white.username) | eq(user.username)
    end

    it "filters users by group" do
      get '/directory_items.json', params: { period: 'all', group: group.name }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(2)
      expect(json['meta']['total_rows_directory_items']).to eq(2)
      expect(json['directory_items'][0]['user']['username']).to eq(evil_trout.username) | eq(stage_user.username)
      expect(json['directory_items'][1]['user']['username']).to eq(evil_trout.username) | eq(stage_user.username)
    end

    it "orders users by user fields" do
      group.add(walter_white)
      field = Fabricate(:user_field, searchable: true)

      UserCustomField.create!(
        user_id: walter_white.id,
        name: "user_field_#{field.id}",
        value: "Yellow"
      )
      UserCustomField.create!(
        user_id: stage_user.id,
        name: "user_field_#{field.id}",
        value: "Apple"
      )
      UserCustomField.create!(
        user_id: evil_trout.id,
        name: "custom_field",
        value: "Moon"
      )

      get '/directory_items.json', params: { period: 'all', group: group.name, order: field.name, user_field_ids: field.id.to_s, asc: true }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(3)
      expect(json['meta']['total_rows_directory_items']).to eq(3)
      expect(json['directory_items'][0]['user']['username']).to eq(stage_user.username)
      expect(json['directory_items'][1]['user']['username']).to eq(walter_white.username)
      expect(json['directory_items'][2]['user']['username']).to eq(evil_trout.username)
    end

    it "checks group permissions" do
      group.update!(visibility_level: Group.visibility_levels[:members])

      sign_in(evil_trout)
      get '/directory_items.json', params: { period: 'all', group: group.name }
      expect(response.status).to eq(200)

      get '/directory_items.json', params: { period: 'all', group: 'not a group' }
      expect(response.status).to eq(400)

      sign_in(user)
      get '/directory_items.json', params: { period: 'all', group: group.name }
      expect(response.status).to eq(403)
    end

    it "does not force-include self in group-filtered results" do
      me = Fabricate(:user)
      DirectoryItem.refresh!
      sign_in(me)

      get '/directory_items.json', params: { period: 'all', group: group.name }
      expect(response.parsed_body['directory_items'].length).to eq(2)
    end
  end
end
