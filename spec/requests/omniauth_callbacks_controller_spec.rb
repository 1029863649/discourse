require 'rails_helper'

RSpec.describe Users::OmniauthCallbacksController do
  let(:user) { Fabricate(:user) }

  before { OmniAuth.config.test_mode = true }

  after do
    Rails.application.env_config['omniauth.auth'] =
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  describe '.find_authenticator' do
    it 'fails if a provider is disabled' do
      SiteSetting.enable_twitter_logins = false

      expect do
        Users::OmniauthCallbacksController.find_authenticator('twitter')
      end.to raise_error(Discourse::InvalidAccess)
    end

    it 'fails for unknown' do
      expect do
        Users::OmniauthCallbacksController.find_authenticator('twitter1')
      end.to raise_error(Discourse::InvalidAccess)
    end

    it 'finds an authenticator when enabled' do
      SiteSetting.enable_twitter_logins = true

      expect(
        Users::OmniauthCallbacksController.find_authenticator('twitter')
      ).not_to eq(nil)
    end

    context 'with a plugin-contributed auth provider' do
      let :provider do
        provider = Auth::AuthProvider.new
        provider.authenticator =
          Class.new(Auth::Authenticator) do
            def name
              'ubuntu'
            end

            def enabled?
              SiteSetting.ubuntu_login_enabled
            end
          end
            .new

        provider.enabled_setting = 'ubuntu_login_enabled'
        provider
      end

      before { DiscoursePluginRegistry.register_auth_provider(provider) }

      after { DiscoursePluginRegistry.reset! }

      it 'finds an authenticator when enabled' do
        SiteSetting.stubs(:ubuntu_login_enabled).returns(true)

        expect(
          Users::OmniauthCallbacksController.find_authenticator('ubuntu')
        ).to be(provider.authenticator)
      end

      it 'fails if an authenticator is disabled' do
        SiteSetting.stubs(:ubuntu_login_enabled).returns(false)

        expect do
          Users::OmniauthCallbacksController.find_authenticator('ubuntu')
        end.to raise_error(Discourse::InvalidAccess)
      end
    end
  end

  context 'Google Oauth2' do
    before { SiteSetting.enable_google_oauth2_logins = true }

    context 'without an `omniauth.auth` env' do
      it 'should return a 404' do
        get '/auth/eviltrout/callback'
        expect(response.code).to eq('404')
      end
    end

    describe 'when user not found' do
      let(:email) { 'somename@gmail.com' }
      before do
        OmniAuth.config.mock_auth[:google_oauth2] =
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: '123545',
            info:
              OmniAuth::AuthHash::InfoHash.new(
                email: email,
                name: 'Some name',
                first_name: 'Some',
                last_name: 'name'
              ),
            extra: {
              raw_info:
                OmniAuth::AuthHash.new(
                  email_verified: true,
                  email: email,
                  family_name: 'Huh',
                  given_name: 'Some name',
                  gender: 'male',
                  name: 'Some name Huh'
                )
            }
          )

        Rails.application.env_config['omniauth.auth'] =
          OmniAuth.config.mock_auth[:google_oauth2]
      end

      it 'should return the right response' do
        destination_url = 'http://thisisasite.com/somepath'
        Rails.application.env_config['omniauth.origin'] = destination_url

        get '/auth/google_oauth2/callback.json'

        expect(response.status).to eq(200)

        response_body = JSON.parse(response.body)

        expect(response_body['email']).to eq(email)
        expect(response_body['username']).to eq('Some_name')
        expect(response_body['auth_provider']).to eq('google_oauth2')
        expect(response_body['email_valid']).to eq(true)
        expect(response_body['omit_username']).to eq(false)
        expect(response_body['name']).to eq('Some Name')
        expect(response_body['destination_url']).to eq(destination_url)
      end

      it 'should include destination url in response' do
        destination_url = 'http://thisisasite.com/somepath'
        cookies[:destination_url] = destination_url

        get '/auth/google_oauth2/callback.json'

        response_body = JSON.parse(response.body)
        expect(response_body['destination_url']).to eq(destination_url)
      end
    end

    describe 'when user has been verified' do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] =
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: '123545',
            info:
              OmniAuth::AuthHash::InfoHash.new(
                email: user.email, name: 'Some name'
              ),
            extra: {
              raw_info:
                OmniAuth::AuthHash.new(
                  email_verified: true,
                  email: user.email,
                  family_name: 'Huh',
                  given_name: user.name,
                  gender: 'male',
                  name: "#{user.name} Huh"
                )
            }
          )

        Rails.application.env_config['omniauth.auth'] =
          OmniAuth.config.mock_auth[:google_oauth2]
      end

      it 'should return the right response' do
        expect(user.email_confirmed?).to eq(false)

        events =
          DiscourseEvent.track_events do
            get '/auth/google_oauth2/callback.json'
          end

        expect(events.map { |event| event[:event_name] }).to include(
              :user_logged_in,
              :user_first_logged_in
            )

        expect(response.status).to eq(200)

        response_body = JSON.parse(response.body)

        expect(response_body['authenticated']).to eq(true)
        expect(response_body['awaiting_activation']).to eq(false)
        expect(response_body['awaiting_approval']).to eq(false)
        expect(response_body['not_allowed_from_ip_address']).to eq(false)
        expect(response_body['admin_not_allowed_from_ip_address']).to eq(false)

        user.reload
        expect(user.email_confirmed?).to eq(true)
      end

      it 'should confirm email even when the tokens are expired' do
        user.email_tokens.update_all(confirmed: false, expired: true)

        user.reload
        expect(user.email_confirmed?).to eq(false)

        events =
          DiscourseEvent.track_events do
            get '/auth/google_oauth2/callback.json'
          end

        expect(events.map { |event| event[:event_name] }).to include(
              :user_logged_in,
              :user_first_logged_in
            )

        expect(response.status).to eq(200)

        user.reload
        expect(user.email_confirmed?).to eq(true)
      end

      it 'should activate/unstage staged user' do
        user.update!(staged: true, registration_ip_address: nil)

        user.reload
        expect(user.staged).to eq(true)
        expect(user.registration_ip_address).to eq(nil)

        events =
          DiscourseEvent.track_events do
            get '/auth/google_oauth2/callback.json'
          end

        expect(events.map { |event| event[:event_name] }).to include(
              :user_logged_in,
              :user_first_logged_in
            )

        expect(response.status).to eq(200)

        user.reload
        expect(user.staged).to eq(false)
        expect(user.registration_ip_address).to be_present
      end

      context 'when user has second factor enabled' do
        before { user.create_totp(enabled: true) }

        it 'should return the right response' do
          get '/auth/google_oauth2/callback.json'

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(response_body['email']).to eq(user.email)
          expect(response_body['omniauth_disallow_totp']).to eq(true)

          user.update!(email: 'different@user.email')
          get '/auth/google_oauth2/callback.json'

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['email']).to eq(user.email)
        end
      end

      context 'when sso_payload cookie exist' do
        before do
          SiteSetting.enable_sso_provider = true
          SiteSetting.sso_secret = 'topsecret'

          @sso = SingleSignOn.new
          @sso.nonce = 'mynonce'
          @sso.sso_secret = SiteSetting.sso_secret
          @sso.return_sso_url = 'http://somewhere.over.rainbow/sso'
          cookies[:sso_payload] = @sso.payload

          UserAssociatedAccount.create!(
            provider_name: 'google_oauth2', provider_uid: '12345', user: user
          )

          OmniAuth.config.mock_auth[:google_oauth2] =
            OmniAuth::AuthHash.new(
              provider: 'google_oauth2',
              uid: '12345',
              info:
                OmniAuth::AuthHash::InfoHash.new(
                  email: 'someother_email@test.com', name: 'Some name'
                ),
              extra: {
                raw_info:
                  OmniAuth::AuthHash.new(
                    email_verified: true,
                    email: 'someother_email@test.com',
                    family_name: 'Huh',
                    given_name: user.name,
                    gender: 'male',
                    name: "#{user.name} Huh"
                  )
              }
            )

          Rails.application.env_config['omniauth.auth'] =
            OmniAuth.config.mock_auth[:google_oauth2]
        end

        it 'should return the right response' do
          get '/auth/google_oauth2/callback.json'

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(response_body['destination_url']).to match(
                %r{\/session\/sso_provider\?sso\=.*\&sig\=.*}
              )
        end
      end

      context 'when user has not verified his email' do
        before do
          UserAssociatedAccount.create!(
            provider_name: 'google_oauth2', provider_uid: '12345', user: user
          )
          user.update!(active: false)

          OmniAuth.config.mock_auth[:google_oauth2] =
            OmniAuth::AuthHash.new(
              provider: 'google_oauth2',
              uid: '12345',
              info:
                OmniAuth::AuthHash::InfoHash.new(
                  email: 'someother_email@test.com', name: 'Some name'
                ),
              extra: {
                raw_info:
                  OmniAuth::AuthHash.new(
                    email_verified: true,
                    email: 'someother_email@test.com',
                    family_name: 'Huh',
                    given_name: user.name,
                    gender: 'male',
                    name: "#{user.name} Huh"
                  )
              }
            )

          Rails.application.env_config['omniauth.auth'] =
            OmniAuth.config.mock_auth[:google_oauth2]
        end

        it 'should return the right response' do
          get '/auth/google_oauth2/callback.json'

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(user.reload.active).to eq(false)
          expect(response_body['authenticated']).to eq(false)
          expect(response_body['awaiting_activation']).to eq(true)
        end
      end

      context 'with full screen login' do
        before { cookies['fsl'] = true }

        it "doesn't attempt redirect to external origin" do
          get '/auth/google_oauth2?origin=https://example.com/external'
          get '/auth/google_oauth2/callback'

          expect(response.status).to eq 302
          expect(response.location).to eq 'http://test.localhost/'
        end

        it 'redirects to internal origin' do
          get '/auth/google_oauth2?origin=http://test.localhost/t/123'
          get '/auth/google_oauth2/callback'

          expect(response.status).to eq 302
          expect(response.location).to eq 'http://test.localhost/t/123'
        end

        it 'redirects to relative origin' do
          get '/auth/google_oauth2?origin=/t/123'
          get '/auth/google_oauth2/callback'

          expect(response.status).to eq 302
          expect(response.location).to eq 'http://test.localhost/t/123'
        end

        it 'redirects with query' do
          get '/auth/google_oauth2?origin=/t/123?foo=bar'
          get '/auth/google_oauth2/callback'

          expect(response.status).to eq 302
          expect(response.location).to eq 'http://test.localhost/t/123?foo=bar'
        end

        it 'removes authentication_data cookie on logout' do
          get '/auth/google_oauth2?origin=https://example.com/external'
          get '/auth/google_oauth2/callback'

          provider = log_in_user(Fabricate(:user))

          expect(cookies['authentication_data']).to be

          log_out_user(provider)

          expect(cookies['authentication_data']).to be_nil
        end

        after { cookies.delete('fsl') }
      end
    end

    context 'when attempting reconnect' do
      let(:user2) { Fabricate(:user) }
      before do
        UserAssociatedAccount.create!(
          provider_name: 'google_oauth2', provider_uid: '12345', user: user
        )
        UserAssociatedAccount.create!(
          provider_name: 'google_oauth2', provider_uid: '123456', user: user2
        )

        OmniAuth.config.mock_auth[:google_oauth2] =
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: '12345',
            info:
              OmniAuth::AuthHash::InfoHash.new(
                email: 'someother_email@test.com', name: 'Some name'
              ),
            extra: {
              raw_info:
                OmniAuth::AuthHash.new(
                  email_verified: true,
                  email: 'someother_email@test.com',
                  family_name: 'Huh',
                  given_name: user.name,
                  gender: 'male',
                  name: "#{user.name} Huh"
                )
            }
          )

        Rails.application.env_config['omniauth.auth'] =
          OmniAuth.config.mock_auth[:google_oauth2]
      end

      it 'should not reconnect normally' do
        # Log in normally
        get '/auth/google_oauth2'
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(false)

        get '/auth/google_oauth2/callback.json'
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to eq(user.id)

        # Log into another user
        OmniAuth.config.mock_auth[:google_oauth2].uid = '123456'
        get '/auth/google_oauth2'
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(false)

        get '/auth/google_oauth2/callback.json'
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to eq(user2.id)
        expect(UserAssociatedAccount.count).to eq(2)
      end

      it 'should reconnect if parameter supplied' do
        # Log in normally
        get '/auth/google_oauth2?reconnect=true'
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(true)

        get '/auth/google_oauth2/callback.json'
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to eq(user.id)

        # Clear cookie after login
        expect(session[:auth_reconnect]).to eq(nil)

        # Disconnect
        UserAssociatedAccount.find_by(user_id: user.id).destroy

        # Reconnect flow:
        get '/auth/google_oauth2?reconnect=true'
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(true)

        OmniAuth.config.mock_auth[:google_oauth2].uid = '123456'
        get '/auth/google_oauth2/callback.json'
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['authenticated']).to eq(true)
        expect(session[:current_user_id]).to eq(user.id)
        expect(UserAssociatedAccount.count).to eq(1)
      end
    end

    context 'after changing email' do
      require_dependency 'email_updater'

      def login(identity)
        OmniAuth.config.mock_auth[:google_oauth2] =
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: "123545#{identity[:username]}",
            info:
              OmniAuth::AuthHash::InfoHash.new(
                email: identity[:email], name: 'Some name'
              ),
            extra: {
              raw_info:
                OmniAuth::AuthHash.new(
                  email_verified: true,
                  email: identity[:email],
                  family_name: 'Huh',
                  given_name: identity[:name],
                  gender: 'male',
                  name: "#{identity[:name]} Huh"
                )
            }
          )

        Rails.application.env_config['omniauth.auth'] =
          OmniAuth.config.mock_auth[:google_oauth2]

        get '/auth/google_oauth2/callback.json'
        expect(response.status).to eq(200)
        JSON.parse(response.body)
      end

      it 'activates the correct email' do
        old_email = 'old@email.com'
        old_identity = { name: 'Bob', username: 'bob', email: old_email }
        user = Fabricate(:user, email: old_email)
        new_email = 'new@email.com'
        new_identity = { name: 'Bob', username: 'boguslaw', email: new_email }

        updater = EmailUpdater.new(user.guardian, user)
        updater.change_to(new_email)

        user.reload
        expect(user.email).to eq(old_email)

        response = login(old_identity)
        expect(response['authenticated']).to eq(true)

        user.reload
        expect(user.email).to eq(old_email)

        delete "/session/#{user.username}" # log out

        response = login(new_identity)
        expect(response['authenticated']).to eq(nil)
        expect(response['email']).to eq(new_email)
      end
    end
  end
end
