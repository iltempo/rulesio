# With inspiration from
#   https://github.com/smartinez87/exception_notification
#   http://sharagoz.com/posts/1-rolling-your-own-exception-handler-in-rails-3

require 'action_dispatch'
require 'rulesio/users'

module RulesIO
  class Exceptions < RulesIO::Users
    include RulesIO::Helpers

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
      @options[:ignore_crawlers]   ||= default_ignored_crawlers
      @options[:ignore_if]         ||= lambda { |env, e| false }
      @options[:token]             ||= RulesIO.token
      @options[:custom_data]       ||= lambda { |env| {} }
    end

    def call(env)
      begin
        @app.call(env)
      rescue Exception => exception
        env['rulesio.exception'] = exception
        send_event event(env, exception), env unless should_be_ignored(env, exception)
        raise exception
      end
    end
    
    def send_event(event, env)
      prep = prepare_event(event, env)
      RulesIO.post_payload_to_token prep, @options[:token]
    end


  private
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

    def event(env, exception)
      backtrace = clean_backtrace(exception)
      event = {
        :_actor => actor_for_exception(exception),
        :_from => '',
        :_domain => exception.class.to_s,
        :_name => fileline(exception),
        :_message => exception.to_s,
        :exception => exception.class.to_s,
        :file => fileline(exception),
        :backtrace => backtrace.join("\n")
      }.with_indifferent_access
      useractor = current_actor(env)
      event[:_xactor] = useractor if useractor
      event.merge!(@options[:custom_data].call(env))
      event
    end

  end
end