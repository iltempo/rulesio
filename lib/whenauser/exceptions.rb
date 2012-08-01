# With inspiration from
#   https://github.com/smartinez87/exception_notification
#   http://sharagoz.com/posts/1-rolling-your-own-exception-handler-in-rails-3

require 'action_dispatch'

module WhenAUser
  class Exceptions
    include WhenAUser::Helpers

    def self.default_ignored_exceptions
      [].tap do |exceptions|
        exceptions << 'ActiveRecord::RecordNotFound'
        exceptions << 'AbstractController::ActionNotFound'
        exceptions << 'ActionController::RoutingError'
      end
    end

    def initialize(app, options={})
      @app, @options = app, options
      @options[:ignore_exceptions] ||= self.class.default_ignored_exceptions
      @options[:ignore_crawlers]   ||= WhenAUser.default_ignored_crawlers
      @options[:ignore_if]         ||= lambda { |env, e| false }
      @options[:token]             ||= WhenAUser.token
      @options[:custom_data]       ||= lambda { |env| {} }
    end

    def call(env)
      begin
        @app.call(env)
      rescue Exception => exception
        send_event_now event(env, exception), @options[:token] unless should_be_ignored(env, exception)
        raise exception
      end
    end

  private
    def send_event_now(event, token)
      WhenAUser.post_payload_to_token WhenAUser.prepare_event(event), token
    end

    def should_be_ignored(env, exception)
      ignored_exception(@options[:ignore_exceptions], exception)       ||
      from_crawler(@options[:ignore_crawlers], env['HTTP_USER_AGENT']) ||
      conditionally_ignored(@options[:ignore_if], env, exception)
    end

    def ignored_exception(ignore_array, exception)
      Array.wrap(ignore_array).map(&:to_s).include?(exception.class.name)
    end

    def conditionally_ignored(ignore_proc, env, exception)
      ignore_proc.call(env, exception)
    rescue Exception => ex
      false
    end

    def clean_backtrace(exception)
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
        exception.backtrace
      end
    end

    def event(env, exception)
      request = ActionDispatch::Request.new(env)
      backtrace = clean_backtrace(exception)
      actor = backtrace.first.match(/^(.*:.*):/)[1] rescue @app.to_s
      event = {
        :_actor => actor,
        :_domain => 'exception',
        :_name => exception.class.to_s,
        :message => exception.to_s,
        :backtrace => backtrace.join("; "),
        :request_url => request.url,
        :request_method => request.request_method,
        :params => request.params.except(*WhenAUser.filter_parameters),
        :user_agent => request.user_agent
      }
      user = current_user(env)
      event.merge!(:current_user => user) if user
      event.merge!(:referer_url => request.referer) if request.referer
      event.merge!(@options[:custom_data].call(env))
      event
    end

  end
end