require 'rails/railtie'
require 'active_record'

module Whenauser
  class RailsConfigurator
    attr_accessor :token, :webhook_url, :middlewares, :queue, :queue_options
    def initialize
      @webhook_url = 'http://www.whenauser.com/events/'
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
    
    def queue(queue, options)
      @queue = queue
      @queue_options = options
    end

    def girl_friday_options(options)
      @girl_friday_options = options
    end
  end

  class MiddlewareConfigurator
    attr_accessor :configuration

    def self.apply(&block)
      x = new
      x.configure(&block) if block_given?
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
            ::Rails.configuration.middleware.insert_after 'ActionDispatch::Static', 'WhenAUser::Rack',
                :webhook_url => @webhook_url,
                :token => @token,
                :queue => @queue,
                :queue_options => @queue_options
            ::Rails.configuration.middleware.use('WhenAUser::Exceptions', @middlewares[:exceptions].configuration) if @middlewares.has_key?(:exceptions)
            # puts "configuration with: #{@middlewares[:pageviews].configuration}"
            ::Rails.configuration.middleware.insert_after('WhenAUser::Rack', 'WhenAUser::Pageviews', @middlewares[:pageviews].configuration) if @middlewares.has_key?(:pageviews)
          end
        end
      end
    end

    config.after_initialize do
      ActiveSupport.on_load(:active_record) do
        require 'whenauser/active_record_extension'
        include ActiveRecord::WhenAUserExtension
      end
    end
  end
end