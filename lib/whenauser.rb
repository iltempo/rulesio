require 'whenauser/version'
require 'whenauser/helpers'
require 'whenauser/exceptions'
require 'whenauser/users'
require 'whenauser/girl_friday_queue'
require 'whenauser/memory_queue'
require 'net/http'
require 'uri'
require 'logger'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/indifferent_access'

module WhenAUser
  mattr_accessor :filter_parameters, :buffer, :token, :webhook_url, :queue, :queue_options, :controller_data, :logger

  def self.default_ignored_crawlers
    %w(Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg Yandex Jyxobot Huaweisymantecspider ApptusBot NewRelicPinger)
  end

  def self.send_event(event)
    buffer << event
  end

  def self.flush(env={})
    return if (events = WhenAUser.buffer).empty?
    WhenAUser.buffer = []
    WhenAUser.queue.push(:payload => events.map {|event| WhenAUser.prepare_event(event, env)})
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
      controller.instance_variable_get('@current_user') || controller.instance_eval('current_user')
    end
  rescue
    nil
  end
  
  def self.actor_for_user(user)
    [:to_param, :id].each do |method|
      return user.send(method) if user && user.respond_to?(method)
    end
    nil
  end

  private
  def self.page_event_name(request, params)
    if params && params['controller']
      "#{params['controller']}##{params['action']}"
    else
      request.path.gsub('/', '-')[1..-1]
    end
  end

  def self.prepare_event(event, env)
    event = event.with_indifferent_access

    if controller = env['action_controller.instance']
      data = controller.instance_eval(WhenAUser.controller_data)
      event.merge!(data)
    end

    current_user = current_user(env)
    actor = actor_for_user(current_user)

    event[:_actor] = actor || 'anonymous' unless event[:_actor].present?
    event[:_timestamp] ||= Time.now.to_f
    event[:rails_env] = Rails.env if defined?(Rails)

    unless env.empty?
      env['rack.input'].rewind
      request = defined?(Rails) ? ActionDispatch::Request.new(env) : ::Rack::Request.new(env)
      params = request.params
      action = page_event_name(request, params)
      
      event[:_name] ||= action
      event[:_from] ||= current_user.email if current_user && current_user.respond_to?(:email) && current_user.email != event[:_actor]
      event[:action] = action
      event[:request_url] = env['rulesio.request_url']
      event[:request_method] = request.request_method
      event[:user_agent] = request.user_agent
      event[:referer_url] = request.referer
      event[:params] = params.except(*WhenAUser.filter_parameters)
      event[:session] = request.session
    end

    event.reject! {|k, v| v.to_s.blank?}
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
      WhenAUser.controller_data = options[:controller_data] || '{}'
    end

    def call(env)
      WhenAUser.buffer = []
      env['rulesio.request_url'] = ::Rack::Request.new(env).url
      @app.call(env)
    ensure
      WhenAUser.flush(env)
    end
  end
end

require 'whenauser/railtie' if defined?(Rails)
