require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module WhenAUser
  class RequestLogSubscriber < ActiveSupport::LogSubscriber
    def process_action(data)
      return unless WhenAUser.pageview_events_enabled?
      payload = data.payload
      return if (status = payload[:status] || 500).to_i == 302
      now = Time.now
      wau = {
        :_actor => 'anonymous',
        :_domain => 'pageview',
        :_name => "#{payload[:params]['controller']}##{payload[:params]['action']}",
        :_timestamp => now.to_i,
        :nsecs => now.nsec,
        :duration => "%.2f" % data.duration,
        :method => payload[:method],
        :path => payload[:path],
        :format => payload[:format],
        :status => status,
        :params => payload[:params].except(*WhenAUser.filter_parameters)
      }
      if payload[:exception]
        exception, message = payload[:exception]
        wau = wau.merge(:exception => exception, :error_message => message)
      else
        wau = wau.merge(:view => "%.2f" % payload[:view_runtime], :db => "%.2f" % payload[:db_runtime])
      end
      wau = wau.merge(custom_data)
      WhenAUser.send_event(wau)
    end

    def custom_data
      WhenAUser.data[Thread.current] || {}
    end
  end
end
