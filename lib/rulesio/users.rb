require 'action_dispatch'

module RulesIO
  class Users
    include RulesIO::Helpers

    def initialize(app, options={})
      @app, @options = app, options
      @options[:ignore_crawlers]      ||= RulesIO.default_ignored_crawlers
      @options[:ignore_if]            ||= lambda { |env| false }
      @options[:ignore_if_controller] ||= 'false'
      @options[:custom_data]          ||= lambda { |env| {} }
    end

    def call(env)
      before = Time.now
      status, headers, response = @app.call(env)
      [status, headers, response]
    rescue Exception => e
      status = 500
      raise e
    ensure
      after = Time.now
      RulesIO.send_event event(env, status, after - before) unless should_be_ignored(env)
    end

  private
    def rails_asset_request?(env)
      defined?(Rails) && env['action_controller.instance'].nil?
    end

    def should_be_ignored(env)
      rails_asset_request?(env) ||
      from_crawler(@options[:ignore_crawlers], env['HTTP_USER_AGENT']) ||
      conditionally_ignored(@options[:ignore_if], env) ||
      conditionally_ignored_controller(@options[:ignore_if_controller], env)
    end

    def conditionally_ignored_controller(condition, env)
      controller = env['action_controller.instance']
      controller.instance_eval condition
    end

    def conditionally_ignored(ignore_proc, env)
      ignore_proc.call(env)
    end

    def event(env, status, duration)
      domain = if (status.to_i >= 400)
        'pageerror'
      else
        (env['rulesio.request_method'] == 'GET') ? 'pageview' : 'formpost'
      end
      event = {
        :_domain => domain,
        :status => status,
        :duration => "%.2f" % (duration * 1000)
      }
      if exception = env['rulesio.exception']
        event[:_xactor] = actor_for_exception(exception)
        event[:_message] = exception.to_s
      end
      event.merge!(@options[:custom_data].call(env))
      event
    end

  end
end