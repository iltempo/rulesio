# With inspiration from
#   https://github.com/smartinez87/exception_notification
#   http://sharagoz.com/posts/1-rolling-your-own-exception-handler-in-rails-3

require 'action_dispatch'

module WhenAUser
  class Pageviews
    include WhenAUser::Helpers

    def initialize(app, options={})
      @app, @options = app, options
      @options[:ignore_crawlers]   ||= WhenAUser.default_ignored_crawlers
      @options[:ignore_if]         ||= lambda { |env| false }
      @options[:custom_data]       ||= lambda { |env| {} }
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      before = Time.now
      status, headers, response = @app.call(env)
      [status, headers, response]
    rescue Exception => e
      status = 500
      raise e
    ensure
      after = Time.now
      WhenAUser.send_event event(env, request, status, after - before) unless should_be_ignored(env, request)
    end

  private
    def rails_asset_request?(env, request)
      defined?(Rails) && env['action_controller.instance'].nil?
    end

    def should_be_ignored(env, request)
      rails_asset_request?(env, request) ||
      from_crawler(@options[:ignore_crawlers], env['HTTP_USER_AGENT']) ||
      conditionally_ignored(@options[:ignore_if], env)
    end

    def conditionally_ignored(ignore_proc, env)
      ignore_proc.call(env)
    rescue Exception => ex
      false
    end

    def page_event_name(request)
      if (params = request.params)['controller']
        "#{params['controller']}##{params['action']}"
      else
        request.path.gsub('/', '-')
      end
    end

    def event(env, request, status, duration)
      actor = current_user(env) || 'anonymous'
      event = {
        :_actor => actor,
        :_domain => (status >= 400) ? 'pageerror' : 'pageview',
        :_name => page_event_name(request),
        :request_url => request.url,
        :request_method => request.request_method,
        :params => request.params.except(*WhenAUser.filter_parameters),
        :user_agent => request.user_agent,
        :status => status,
        :duration => "%.2f" % (duration * 1000)
      }
      if exception = env['whenauser.exception']
        event.merge!(:error => actor_for_exception(exception))
        event.merge!(:message => exception.to_s)
      end
      event.merge!(:referer_url => request.referer) if request.referer
      event.merge!(:rails_env => Rails.env) if defined?(Rails)
      event.merge!(@options[:custom_data].call(env))
      event
    end

  end
end