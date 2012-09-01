require 'rulesio/version'
require 'rulesio/helpers'
require 'rulesio/exceptions'
require 'rulesio/users'
require 'rulesio/girl_friday_queue'
require 'rulesio/memory_queue'
require 'net/http'
require 'uri'
require 'logger'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/indifferent_access'

module RulesIO
  mattr_accessor :filter_parameters, :buffer, :token, :webhook_url, :queue, :queue_options, :controller_data, :logger, :disable_sending_events

  def self.default_ignored_crawlers
    %w(Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg Yandex Jyxobot Huaweisymantecspider ApptusBot NewRelicPinger)
  end

  def self.send_event(event)
    buffer << event
  end

  def self.flush(env={})
    return if (events = RulesIO.buffer).empty?
    RulesIO.buffer = []
    RulesIO.queue.push(:payload => events.map {|event| RulesIO.prepare_event(event, env)})
    # RulesIO.post_payload_to_token events.to_json, RulesIO.token
  end
  
  def self.post_payload_to_token(payload, token)
    return if RulesIO.disable_sending_events
    uri = URI(RulesIO.webhook_url + token)
    req = Net::HTTP::Post.new(uri.path)
    req.body = payload.to_json
    req.content_type = 'application/json'
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if RulesIO.webhook_url =~ /^https:/
    http.start do |http|
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
  
  def self.current_actor(env)
    if controller = env['action_controller.instance']
      begin
        data = controller.instance_eval(RulesIO.controller_data)
        data = data.with_indifferent_access
        return data[:_actor] if data[:_actor]
      rescue
      end

      user = controller.instance_variable_get('@current_user') || controller.instance_eval('current_user')
      [:to_param, :id].each do |method|
        return user.send(method) if user && user.respond_to?(method)
      end
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
      begin
        data = controller.instance_eval(RulesIO.controller_data).with_indifferent_access
        event = data.merge(event)
      rescue
      end
    end

    current_user = current_user(env)
    actor = current_actor(env)

    event[:_actor] = actor || 'anonymous' unless event[:_actor].present?
    event[:_timestamp] ||= Time.now.to_f
    event[:rails_env] = Rails.env if defined?(Rails)

    unless env.empty?
      env['rack.input'].rewind
      request = defined?(Rails) ? ActionDispatch::Request.new(env) : ::Rack::Request.new(env)
      params = request.params
      action = page_event_name(request, params)
      
      event[:_domain] = 'JSON' if event[:_domain] == 'pageview' && params['format'] == 'json'
      event[:_domain] = 'XML' if event[:_domain] == 'pageview' && params['format'] == 'xml'
      event[:_name] ||= action
      event[:_from] ||= current_user.email if current_user && current_user.respond_to?(:email) && current_user.email != event[:_actor]
      event[:action] = action
      event[:request_url] = env['rulesio.request_url']
      event[:request_method] = env['rulesio.request_method']
      event[:user_agent] = request.user_agent
      event[:referer_url] = request.referer
      event[:params] = params.except(*RulesIO.filter_parameters)
      event[:session] = request.session
    end

    event.reject! {|k, v| v.to_s.blank?}
    event
  end

  class Rack
    def initialize(app, options={})
      @app = app
      RulesIO.logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
      RulesIO.webhook_url = options[:webhook_url] || 'https://www.rules.io/events/'
      RulesIO.buffer = []
      RulesIO.filter_parameters = defined?(Rails) ? Rails.application.config.filter_parameters : []
      RulesIO.token = options[:token]
      RulesIO.queue = options[:queue] || RulesIO::MemoryQueue
      RulesIO.queue_options = options[:queue_options] || {}
      RulesIO.controller_data = options[:controller_data] || '{}'
      RulesIO.disable_sending_events = options[:disable_sending_events] || false
    end

    def call(env)
      RulesIO.buffer = []
      request = ::Rack::Request.new(env)
      env['rulesio.request_url'] = request.url
      env['rulesio.request_method'] = request.request_method
      @app.call(env)
    ensure
      RulesIO.flush(env)
    end
  end
end

require 'rulesio/railtie' if defined?(Rails)
