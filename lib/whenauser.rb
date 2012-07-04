require 'whenauser/version'
require 'whenauser/log_subscriber'
require 'active_support/core_ext/module/attribute_accessors'
require 'faraday'
require 'faraday_middleware'

class ActionController::Base
  def self.inherited(subclass)
    super
    subclass.prepend_before_filter :whenauser_disable_pageview_events
    subclass.before_filter :whenauser_pageview_events
  end

  def whenauser_disable_pageview_events
    WhenAUser.disable_pageview_events!
    true
  end
  
  def whenauser_pageview_events
    WhenAUser.enable_pageview_events!
    true
  end
end

module WhenAUser
  mattr_accessor :webhook_url
  mattr_accessor :token
  mattr_accessor :endpoint
  mattr_accessor :filter_parameters
  mattr_accessor :data
  mattr_accessor :state

  def self.setup(app)
    WhenAUser::RequestLogSubscriber.attach_to :action_controller
    self.webhook_url = app.config.whenauser.webhook_url
    self.token = app.config.whenauser.token
    self.filter_parameters = app.config.filter_parameters || []
    self.endpoint = Faraday::Connection.new webhook_url do |builder|
      builder.request :json
      builder.adapter Faraday.default_adapter
    end
    self.data = {}
    self.state = {}
  end
  
  def self.custom_data=(hash)
    data[Thread.current] = hash
  end
  
  def self.send_event(event)
    endpoint.post token, event.to_json
  end
  
  def self.disable_pageview_events!
    state[Thread.current] = :disabled
  end

  def self.enable_pageview_events!
    state[Thread.current] = :enabled
  end
  
  def self.pageview_events_enabled?
    state[Thread.current] == :enabled
  end
end

require 'whenauser/railtie' if defined?(Rails)
