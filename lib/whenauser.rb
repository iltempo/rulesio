require 'whenauser/version'
require 'whenauser/helpers'
require 'whenauser/exceptions'
require 'whenauser/pageviews'
require 'whenauser/girl_friday_queue'
require 'whenauser/memory_queue'
require 'net/http'
require 'uri'
require 'logger'
require 'active_support/core_ext/module/attribute_accessors'

module WhenAUser
  mattr_accessor :filter_parameters, :buffer, :token, :webhook_url, :queue, :queue_options, :custom_data, :logger

  def self.default_ignored_crawlers
    %w(Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg Yandex Jyxobot Huaweisymantecspider ApptusBot)
  end

  def self.send_event(event)
    logger.debug "============= #{event.inspect} ============="
    buffer << event
  end

  def self.flush(env={})
    return if (events = WhenAUser.buffer).empty?
    WhenAUser.buffer = []
    events.each {|event| WhenAUser.prepare_event(event, env)}
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

  def self.current_user(env)
    if controller = env['action_controller.instance']
      if current_user = controller.instance_variable_get('@current_user') || controller.instance_eval('current_user')
        [:login, :username, :email, :id].each do |field|
          return current_user.send(field) if current_user.respond_to?(field)
        end
      end
    end
    nil
  rescue
    nil
  end

  private
  def self.prepare_event(event, env)
    event[:_actor] ||= current_user(env) || 'anonymous'
    event[:_timestamp] = Time.now.to_f unless (event[:_timestamp] || event['_timestamp'])
    event[:rails_env] = Rails.env if defined?(Rails)
    unless env.empty?
      event[:request_url] = env['whenauser.request_url']
      event[:request_method] = env['whenauser.request_method']
      event[:user_agent] = env['whenauser.user_agent']
      event[:referer_url] = env['whenauser.referer_url'] if env['whenauser.referer_url']
    end
    request = ActionDispatch::Request.new(env)
    event[:params] = request.params.except(*WhenAUser.filter_parameters)
    event.merge!(WhenAUser.custom_data.call(env))
    event
  end

  class Rack
    def initialize(app, options={})
      @app = app
      WhenAUser.logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
      WhenAUser.webhook_url = options[:webhook_url] || 'http://www.whenauser.com/events/'
      WhenAUser.buffer = []
      WhenAUser.filter_parameters = defined?(Rails) ? Rails.application.config.filter_parameters : []
      WhenAUser.token = options[:token]
      WhenAUser.queue = options[:queue] || WhenAUser::MemoryQueue
      WhenAUser.queue_options = options[:queue_options] || {}
      WhenAUser.custom_data = options[:custom_data] || lambda { |env| {} }
    end

    def call(env)
      WhenAUser.buffer = []
      request = ActionDispatch::Request.new(env)
      env['whenauser.request_url'] = request.url
      env['whenauser.request_method'] = request.request_method
      env['whenauser.user_agent'] = request.user_agent
      env['whenauser.referer_url'] = request.referer
      @app.call(env)
    ensure
      WhenAUser.flush(env)
    end
  end
end

require 'whenauser/railtie' if defined?(Rails)
