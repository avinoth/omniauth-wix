require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class Wix < OmniAuth::Strategies::OAuth2
      SITE_INFO_URL = 'https://www.wixapis.com/apps/v1/instance'
      option :name, 'wix'

      option :client_options, {
        :authorize_url => 'https://www.wix.com/installer/install',
        :token_url => 'https://www.wixapis.com/oauth/access.json'
      }

      option :provider_ignores_state, true

      uid { raw_info['site']['site_id'] }

      credentials do
        hash = {"token" => access_token.token}
        hash["refresh_token"] = access_token.refresh_token if access_token.refresh_token
        hash["expires_at"] = access_token.expires_at if access_token.expires?
        hash["expires"] = access_token.expires?
        hash
      end

      info do
        prune!({
          'id' => raw_info['site']['site_id'],
          'name' => raw_info['site']['site_display_name'],
          'url' => raw_info['site']['url'],
          'email'=> raw_info['site']['owner_email']
        })
      end

      extra do
        hash = {}
        hash['raw_info'] = raw_info unless skip_info?
        prune! hash
      end


      def client
        ::OAuth2::Client.new(options.client_id, options.client_secret, deep_symbolize(options.client_options)) do |b|
          b.request :json
          b.adapter Faraday.default_adapter
        end
      end

      def authorize_params
        super.tap do |params|
          params["redirectUrl"] = callback_url
          params["appId"] = options[:client_id]
          params["token"] = request.params["token"]
        end
      end

      def callback_url
        full_host + script_name + callback_path
      end

      def raw_info
        @raw_info ||= access_token.get(SITE_INFO_URL, headers: {"Authorization" => access_token.token}).parsed
      end

      def build_access_token
        verifier = request.params["code"]
        params = {
          redirect_uri: callback_url,
          grant_type: "authorization_code",
          client_id: options.client_id,
          client_secret: options.client_secret,
        }.merge(token_params.to_hash(:symbolize_keys => true).merge({ headers: { 'Content-Type' => 'application/json' } }))
        client.auth_code.get_token(verifier, params, deep_symbolize(options.auth_token_params))
      end

      private

      def prune!(hash)
        hash.delete_if do |_, value|
          prune!(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
