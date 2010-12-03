require 'uri'
require 'faraday'

module Tinder
  class Connection
    HOST = "campfirenow.com"

    attr_reader :subdomain, :uri, :options

    def self.connection
      @connection ||= Faraday::Connection.new do |conn|
        conn.use      Faraday::Request::ActiveSupportJson
        conn.adapter  Faraday.default_adapter
        conn.use      Tinder::FaradayResponse::RaiseOnAuthenticationFailure
        conn.use      Faraday::Response::ActiveSupportJson
        conn.use      Tinder::FaradayResponse::WithIndifferentAccess

        conn.headers['Content-Type'] = 'application/json'
      end
    end

    def self.raw_connection
      @raw_connection ||= Faraday::Connection.new do |conn|
        conn.adapter  Faraday.default_adapter
        conn.use      Tinder::FaradayResponse::RaiseOnAuthenticationFailure
        conn.use      Faraday::Response::ActiveSupportJson
        conn.use      Tinder::FaradayResponse::WithIndifferentAccess
      end
    end

    def initialize(subdomain, options = {})
      @subdomain = subdomain
      @options = { :ssl => true, :ssl_verify => true, :proxy => ENV['HTTP_PROXY'] }.merge(options)
      @uri = URI.parse("#{@options[:ssl] ? 'https' : 'http' }://#{subdomain}.#{HOST}")
      @token = options[:token]

      connection.basic_auth token, 'X'
      raw_connection.basic_auth token, 'X'
    end

    def basic_auth_settings
      { :username => token, :password => 'X' }
    end

    def connection
      @connection ||= begin
        conn = self.class.connection.dup
        conn.url_prefix = @uri.to_s
        conn.proxy options[:proxy]
        if options[:ssl_verify] == false
          conn.ssl[:verify] = false
        end
        conn
      end
    end

    def raw_connection
      @raw_connection ||= begin
        conn = self.class.raw_connection.dup
        conn.url_prefix = @uri.to_s
        conn.proxy options[:proxy]
        if options[:ssl_verify] == false
          conn.ssl[:verify] = false
        end
        conn
      end
    end

    def token
      @token ||= begin
        connection.basic_auth(options[:username], options[:password])
        get('/users/me.json')['user']['api_auth_token']
      end
    end

    def get(url, *args)
      response = connection.get(url, *args)
      response.body
    end

    def post(url, body = nil, *args)
      response = connection.post(url, body, *args)
      response.body
    end

    def raw_post(url, body = nil, *args)
      response = raw_connection.post(url, body, *args)
    end

    def put(url, body = nil, *args)
      response = connection.put(url, body, *args)
      response.body
    end

    # Is the connection to campfire using ssl?
    def ssl?
      uri.scheme == 'https'
    end
  end
end
