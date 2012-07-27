require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module Whenauser
  class RailsConfigurator
    attr_accessor :token, :webhook_url, :middlewares
    def initialize
      @webhook_url = 'http://whenauser.com/events/'
      @middlewares = {}
    end

    def token(token)
      @token = token
    end

    def webhook_url(webhook_url)
      @webhook_url = webhook_url
    end

    def middleware(middleware, &block)
      @middlewares[middleware] = MiddlewareConfigurator.apply(&block)
    end
  end

  class MiddlewareConfigurator
    attr_accessor :configuration

    def self.apply(&block)
      x = new
      x.configure(&block)
      x
    end

    def initialize
      @configuration = {}
    end

    def configure(&block)
      instance_eval &block
    end

    def method_missing(mid, *args, &block)
      mname = mid.id2name
      if block_given?
        @configuration[mname.to_sym] = *block
      else
        if args.size == 1
          @configuration[mname.to_sym] = args.first
        else
          @configuration[mname.to_sym] = args
        end
      end
    end
  end

  class Railtie < Rails::Railtie
    initializer :whenauser do |app|
      filename = Rails.root.join('config/whenauser.rb')
      if File.exists?(filename)
        Whenauser::RailsConfigurator.new.instance_eval do
          eval IO.read(filename), binding, filename.to_s, 1
          if defined?(::Rails.configuration) && ::Rails.configuration.respond_to?(:middleware)
            ::Rails.configuration.middleware.insert_after 'Rack::Lock', 'WhenAUser::Rack',
                :webhook_url => @webhook_url,
                :token => @token
            ::Rails.configuration.middleware.use('WhenAUser::Exceptions', @middlewares[:exceptions].configuration) if @middlewares.has_key?(:exceptions)
            puts "configuration with: #{@middlewares[:pageviews].configuration}"
            ::Rails.configuration.middleware.insert_after('WhenAUser::Rack', 'WhenAUser::Pageviews', @middlewares[:pageviews].configuration) if @middlewares.has_key?(:pageviews)
          end
        end
      end
    end
  end
end