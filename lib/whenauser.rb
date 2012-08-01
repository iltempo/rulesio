require 'whenauser/version'
require 'whenauser/helpers'
require 'whenauser/exceptions'
require 'whenauser/pageviews'
require 'whenauser/girl_friday_queue'
require 'whenauser/memory_queue'
require 'net/http'
require 'uri'
require 'active_support/core_ext/module/attribute_accessors'

module WhenAUser
  mattr_accessor :endpoint, :filter_parameters, :buffer, :token, :webhook_url, :queue, :queue_options

  def self.default_ignored_crawlers
    %w(Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg Yandex Jyxobot Huaweisymantecspider ApptusBot)
  end

  def self.send_event(event)
    WhenAUser.buffer << WhenAUser.prepare_event(event)
  end

  def self.flush
    return if (events = WhenAUser.buffer).empty?
    WhenAUser.buffer = []
    WhenAUser.queue.push(:payload => events)
    # WhenAUser.post_payload_to_token events.to_json, WhenAUser.token
  end
  
  def self.post_payload_to_token(payload, token)
    uri = URI(WhenAUser.webhook_url + token)
    req = Net::HTTP::Post.new(uri.path)
    req.body = payload.to_json
    req.content_type = 'application/json'
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.request(req)
    end
  end
  
  def self.prepare_event(event)
    event[:_timestamp] = Time.now.to_f unless event[:_timestamp] || event['_timestamp']
    event[:rails_env] = Rails.env if defined?(Rails)
    event
  end

  class Rack
    def initialize(app, options={})
      @app = app
      WhenAUser.webhook_url = options[:webhook_url] || 'http://www.whenauser.com/events/'
      WhenAUser.buffer = []
      WhenAUser.filter_parameters = defined?(Rails) ? Rails.application.config.filter_parameters : []
      WhenAUser.token = options[:token]
      WhenAUser.queue = options[:queue] || WhenAUser::MemoryQueue
      WhenAUser.queue_options = options[:queue_options] || {}
    end

    def call(env)
      WhenAUser.buffer = []
      @app.call(env)
    ensure
      WhenAUser.flush
    end
  end
end

require 'whenauser/railtie' if defined?(Rails)
