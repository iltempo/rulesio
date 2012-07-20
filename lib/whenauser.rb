require 'whenauser/version'
require 'whenauser/helpers'
require 'whenauser/exceptions'
require 'whenauser/pageviews'
require 'faraday'
require 'faraday_middleware'
require 'active_support/core_ext/module/attribute_accessors'

module WhenAUser
  mattr_accessor :endpoint, :filter_parameters, :queue, :token

  def self.default_ignored_crawlers
    %w(Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg Yandex Jyxobot Huaweisymantecspider ApptusBot)
  end

  def self.send_event(event)
    event[:_timestamp] = Time.now.to_f unless event[:_timestamp] || event['_timestamp']
    WhenAUser.queue << event
  end

  def self.flush
    return if (events = WhenAUser.queue).empty?
    WhenAUser.queue = []
    endpoint.post WhenAUser.token, events.to_json
  end

  class Rack
    def initialize(app, options={})
      options[:webhook_url] ||= 'http://whenauser.com/events/'
      @app = app
      WhenAUser.queue = []
      WhenAUser.filter_parameters = defined?(Rails) ? Rails.application.config.filter_parameters : []
      WhenAUser.token = options[:token]
      WhenAUser.endpoint = Faraday::Connection.new options[:webhook_url] do |builder|
        builder.request :json
        builder.adapter Faraday.default_adapter
      end
    end

    def call(env)
      WhenAUser.queue = []
      status, headers, response = @app.call(env)
      WhenAUser.flush
      [status, headers, response]
    end
  end
end
