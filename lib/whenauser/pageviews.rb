# With inspiration from
#   https://github.com/smartinez87/exception_notification
#   http://sharagoz.com/posts/1-rolling-your-own-exception-handler-in-rails-3

require 'action_dispatch'

module WhenAUser
  class Pageviews
    include WhenAUser::Helpers

    def initialize(app, options={})
      @app, @options = app, options
      @options[:ignore_crawlers]      ||= WhenAUser.default_ignored_crawlers
      @options[:ignore_if]            ||= lambda { |env| false }
      @options[:ignore_if_controller] ||= ''
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
      WhenAUser.send_event event(env, status, after - before) unless should_be_ignored(env)
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
      event = {
        :_domain => (status.to_i >= 400) ? 'pageerror' : 'pageview',
        :status => status,
        :duration => "%.2f" % (duration * 1000)
      }
      if exception = env['whenauser.exception']
        event.merge!(:error => actor_for_exception(exception))
        event.merge!(:message => exception.to_s)
      end
      event.merge!(@options[:custom_data].call(env))
      event
    end

  end
end