# frozen_string_literal: true
require 'swagger_helper'

describe 'users' do

  let(:'Api-Key') { Fabricate(:api_key).key }
  let(:'Api-Username') { 'system' }
  let(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.tagging_enabled = true
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/users.json' do

    post 'Creates a user' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :user_body, in: :body, schema: {
        type: :object,
        properties: {
          "name": { type: :string },
          "email": { type: :string },
          "password": { type: :string },
          "username": { type: :string },
          "active": { type: :boolean },
          "approved": { type: :boolean },
          "user_fields[1]": { type: :string },
        },
        required: ['name', 'email', 'password', 'username']
      }

      produces 'application/json'
      response '200', 'user created' do
        schema type: :object, properties: {
          success: { type: :boolean },
          active: { type: :boolean },
          message: { type: :string },
          user_id: { type: :integer },
        }

        let(:user_body) { {
          name: 'user',
          username: 'user1',
          email: 'user1@example.com',
          password: '13498428e9597cab689b468ebc0a5d33',
          active: true
        } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to eq(true)
          expect(data['active']).to eq(true)
        end
      end
    end

  end

  path '/u/{username}.json' do

    get 'Get a single user by username' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :username, in: :path, type: :string, required: true

      produces 'application/json'
      response '200', 'user response' do
        schema '$ref' => '#/components/schemas/user_response'

        let(:username) { 'system' }
        run_test!
      end
    end
  end

  path '/u/by-external/{external_id}.json' do

    get 'Get a user by external_id' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :external_id, in: :path, type: :string, required: true

      produces 'application/json'
      response '200', 'user response' do
        schema '$ref' => '#/components/schemas/user_response'

        let(:user) { Fabricate(:user) }
        let(:external_id) { '1' }

        before do
          SiteSetting.sso_url = 'http://someurl.com'
          SiteSetting.enable_sso = true
          user.create_single_sign_on_record(external_id: '1', last_payload: '')
        end

        run_test!
      end
    end
  end

  path '/u/by-external/{provider}/{external_id}.json' do

    get 'Get a user by identity provider external ID' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :provider,
                in: :path,
                type: :string,
                required: true,
                description: "Authentication provider name. Can be found in the provider callback URL: `/auth/{provider}/callback`"
      parameter name: :external_id, in: :path, type: :string, required: true

      produces 'application/json'
      response '200', 'user response' do
        schema '$ref' => '#/components/schemas/user_response'

        let(:user) { Fabricate(:user) }
        let(:provider) { 'google_oauth2' }
        let(:external_id) { 'myuid' }

        before do
          SiteSetting.enable_google_oauth2_logins = true
          UserAssociatedAccount.create!(user: user, provider_uid: 'myuid', provider_name: 'google_oauth2')
        end

        run_test!
      end
    end
  end

  path '/u/{username}/preferences/avatar/pick.json' do

    put 'Update avatar' do
      tags 'Users'
      consumes 'application/json'
      expected_request_schema = load_spec_schema('user_update_avatar_request')

      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces 'application/json'
      response '200', 'avatar updated' do
        expected_response_schema = load_spec_schema('success_ok_response')

        let(:user) { Fabricate(:user) }
        let(:username) { user.username }
        let(:upload) { Fabricate(:upload, user: user) }
        let(:params) { { 'upload_id' => upload.id, 'type' => 'uploaded' } }

        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

  end

  path '/u/{username}/preferences/email.json' do

    put 'Update email' do
      tags 'Users'
      consumes 'application/json'
      expected_request_schema = load_spec_schema('user_update_email_request')

      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :params, in: :body, schema: expected_request_schema

      produces 'application/json'
      response '200', 'email updated' do

        let(:user) { Fabricate(:user) }
        let(:username) { user.username }
        let(:params) { { 'email' => "test@example.com" } }

        expected_response_schema = nil

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

  end

  path '/directory_items.json' do

    get 'Get a public list of users' do
      tags 'Users'
      consumes 'application/json'
      expected_request_schema = nil

      parameter name: :period,
                in: :query,
                type: :string,
                required: true,
                description: 'enum: "daily", "weekly", "monthly", "quarterly", "yearly", "all"'

      produces 'application/json'
      response '200', 'directory items response' do

        let(:period) { 'weekly' }

        expected_response_schema = load_spec_schema('users_public_list_response')
        schema(expected_response_schema)

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

  end

end
