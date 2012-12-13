require 'rulesio/version'
require 'rulesio/helpers'
require 'rulesio/base'
require 'rulesio/rack'
require 'rulesio/users'
require 'rulesio/exceptions'
require 'rulesio/girl_friday_queue'
require 'rulesio/memory_queue'
require 'net/http'
require 'uri'
require 'logger'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/indifferent_access'
require 'action_dispatch/http/parameter_filter'

module RulesIO
  mattr_accessor :webhook_url, :queue, :queue_options, :logger, :disable_sending_events, :instance

  @logger = Logger.new(STDOUT)
  
  def self.send_event(*args)
    instance.send_event(*args)
  end
  
  def self.flush
    instance.flush
  end
  
  def self.post_payload_to_token(payload, token)
    return if RulesIO.disable_sending_events
    uri = URI(RulesIO.webhook_url + token)
    req = Net::HTTP::Post.new(uri.path)
    req.body = payload.to_json
    req.content_type = 'application/json'
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if RulesIO.webhook_url =~ /^https:/
    http.start do |http|
      http.request(req)
    end
  end
end

require 'rulesio/railtie' if defined?(Rails)
