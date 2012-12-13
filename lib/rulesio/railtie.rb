require 'rails/railtie'
require 'active_record'

module RulesIO
  class RailsConfigurator
    attr_accessor :token, :webhook_url, :middlewares, :queue, :controller_data, :queue_options, :disable
    def initialize
      @webhook_url = 'https://www.rules.io/events/'
      @middlewares = {}
      @disable = false
    end

    def token(token)
      @token = token
    end

    def webhook_url(webhook_url)
      @webhook_url = webhook_url
    end

    def middleware(middleware, &block)
      @middlewares[middleware] = MiddlewareConfigurator.apply(self, &block)
    end
    
    def queue(queue, options)
      @queue = queue
      @queue_options = options
    end
    
    def disable_sending_events
      @disable = true
    end

    def controller_data(data)
      @controller_data = data
    end

    def girl_friday_options(options)
      @girl_friday_options = options
    end
    
    def configuration
      {
        :webhook_url => @webhook_url,
        :disable_sending_events => @disable,
        :token => @token,
        :queue => @queue,
        :queue_options => @queue_options,
        :controller_data => @controller_data
      }
    end
  end

  class MiddlewareConfigurator
    attr_accessor :configuration, :root

    def self.apply(root, &block)
      x = new
      x.root = root
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
    initializer :rulesio do |app|
      filename = Rails.root.join('config/rulesio.rb')
      if File.exists?(filename)
        RulesIO::RailsConfigurator.new.instance_eval do
          eval IO.read(filename), binding, filename.to_s, 1
          RulesIO.logger = Rails.logger
          RulesIO.webhook_url = @webhook_url || 'https://www.rules.io/events/'
          RulesIO.queue = @queue || RulesIO::MemoryQueue
          RulesIO.queue_options = @queue_options || {}
          RulesIO.disable_sending_events = @disable_sending_events || false
          if defined?(::Rails.configuration) && ::Rails.configuration.respond_to?(:middleware)
            ::Rails.configuration.middleware.insert 0, 'RulesIO::Rack', configuration
            ::Rails.configuration.middleware.use('RulesIO::Users', configuration.merge(@middlewares[:users].configuration)) if @middlewares.has_key?(:users)
            ::Rails.configuration.middleware.use('RulesIO::Users', configuration.merge(@middlewares[:pageviews].configuration)) if @middlewares.has_key?(:pageviews)
            ::Rails.configuration.middleware.use('RulesIO::Exceptions', configuration.merge(@middlewares[:exceptions].configuration)) if @middlewares.has_key?(:exceptions)
          end
        end
      else
        puts 'Warning: rulesio configuration file not found in config/rulesio.rb'
      end
    end

    config.after_initialize do
      ActiveSupport.on_load(:active_record) do
        require 'rulesio/active_record_extension'
        include ActiveRecord::RulesIOExtension
      end
    end
  end
end