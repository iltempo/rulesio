module RulesIO
  class Rack < Base
    attr_accessor :filter_parameters, :controller_data, :config_options
    
    #cattr_accessor :config_options
    @@config_options = {}
    
    def self.config_options
      @@config_options
    end
    
    def self.config_options=(opts)
      @@config_options = opts
    end
    
    def default_ignored_crawlers
      %w(Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg Yandex Jyxobot Huaweisymantecspider ApptusBot NewRelicPinger CopperEgg Pingdom UptimeRobot)
    end
    
    def initialize(app, options={})
      self.class.config_options = @config_options = (options || {})
      RulesIO.instance = self
      @app = app
      @buffer = []
      @filter_parameters ||= defined?(Rails) ? Rails.application.config.filter_parameters : []
      @token = options[:token]
      @controller_data = options[:controller_data] || '{}'
    end

    def call(env)
      @buffer = []
      request = ::Rack::Request.new(env)
      env['rulesio.request_url'] = request.url
      env['rulesio.request_method'] = request.request_method
      @app.call(env)
    ensure
      flush(env)
    end
    
    def send_event(event)
      @buffer << event
    end
    
    def flush(env={})
      return if (events = @buffer).empty?
      @buffer = []
      RulesIO.queue.push(:token => @token, :payload => events.map {|event| prepare_event(event, env)})
    end
  
  private
    def prepare_event(event, env)
      event = event.with_indifferent_access

      current_user = current_user(env) rescue nil
      actor = current_actor(env) rescue nil

      if controller = env['action_controller.instance']
        begin
          data = if RulesIO.controller_data.is_a?(String)
            controller.instance_eval(RulesIO.controller_data)
          elsif RulesIO.controller_data.is_a?(Proc) && !RulesIO.controller_data.lambda?
            controller.instance_eval(&RulesIO.controller_data)
          else
            {}
          end
          event = data.with_indifferent_access.merge(event)
        rescue Exception => e
          RulesIO.logger.warn "RulesIO having trouble with controller_data: #{e}"
        end
      end

      event[:_actor] = actor || 'anonymous' unless event[:_actor].present?
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
        event[:session] = request.session
        parameter_filter = ::ActionDispatch::Http::ParameterFilter.new(filter_parameters)
        event[:params] = parameter_filter.filter(params)
      end

      event.reject! {|k, v| v.to_s.blank?}
      event
    end

    def current_user(env)
      if controller = env['action_controller.instance']
        controller.instance_variable_get('@current_user') || controller.instance_eval('current_user')
      end
    rescue
      nil
    end

    def page_event_name(request, params)
      if params && params['controller']
        "#{params['controller']}##{params['action']}"
      else
        request.path.gsub('/', '-')[1..-1]
      end
    end
  end
end